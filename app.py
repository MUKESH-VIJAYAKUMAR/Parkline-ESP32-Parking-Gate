from __future__ import annotations

import logging
import os
import re
import secrets
import threading
import webbrowser
from datetime import datetime, time, timezone
from functools import lru_cache
from pathlib import Path
from time import monotonic
from zoneinfo import ZoneInfo

from dotenv import load_dotenv
from flask import Flask, abort, jsonify, render_template, request
from supabase import Client, create_client


BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

PARKING_TIMEZONE = ZoneInfo("Asia/Kolkata")
DEFAULT_PROJECT_URL = "https://wiyjgmwktmopddvoudsm.supabase.co"
PAGE_SIZE_DEFAULT = 25
PAGE_SIZE_MAX = 100
SEARCH_CHARS = re.compile(r"[^A-Za-z0-9 _.-]")
RFID_SEPARATORS = re.compile(r"[\s:-]")
DEVICE_STATUS_LOCK = threading.Lock()
DEVICE_STATUS = {
    "last_seen": None,
    "gate_open": False,
    "ir_entry_detected": False,
    "ir_exit_detected": False,
    "wifi_rssi": None,
    "_last_seen_monotonic": 0.0,
}

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("parking_dashboard")


class SupabaseNotConfigured(RuntimeError):
    pass


@lru_cache(maxsize=1)
def get_supabase() -> Client:
    url = (os.getenv("SUPABASE_URL") or DEFAULT_PROJECT_URL).strip()
    key = (os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    if not key:
        raise SupabaseNotConfigured
    return create_client(url, key)


def users_table():
    return get_supabase().table("parking_users")


def events_table():
    return get_supabase().table("parking_events")


def page_args() -> tuple[int, int]:
    try:
        page = max(1, int(request.args.get("page", "1")))
        limit = min(PAGE_SIZE_MAX, max(1, int(request.args.get("limit", str(PAGE_SIZE_DEFAULT)))))
    except ValueError:
        return 1, PAGE_SIZE_DEFAULT
    return page, limit


def safe_search(raw: str | None) -> str:
    return SEARCH_CHARS.sub("", (raw or "").strip())[:64]


def read_count(query) -> int:
    response = query.execute()
    return int(response.count or 0)


def log_database_error(label: str) -> None:
    logger.exception("Supabase request failed while loading %s", label)


EVENT_COLUMNS = (
    "id,parking_user_id,user_name,vehicle_plate,card_uid,direction,access_status,card_tapped_at,vehicle_passed_at,"
    "parking_user:parking_users(full_name,vehicle_plate)"
)


def create_app() -> Flask:
    app = Flask(__name__)
    app.config["SECRET_KEY"] = os.getenv("FLASK_SECRET_KEY") or secrets.token_urlsafe(32)

    @app.before_request
    def keep_dashboard_local():
        # The ESP32 can reach only the authenticated POST endpoints over Wi-Fi.
        # Browser pages, static files, and admin APIs remain on this computer.
        if request.path.startswith("/api/device/") and request.method == "POST":
            return None
        if request.remote_addr not in {"127.0.0.1", "::1"}:
            abort(403)

    def require_device_key():
        expected = (os.getenv("ESP32_API_KEY") or "").strip()
        provided = request.headers.get("X-Device-Key", "").strip()
        if not expected:
            return jsonify({"error": "ESP32_API_KEY is not configured on the dashboard server."}), 503
        if not provided or not secrets.compare_digest(provided, expected):
            return jsonify({"error": "Unauthorized device."}), 401
        return None

    @app.get("/")
    def index():
        return render_template("index.html")

    @app.get("/api/dashboard")
    def dashboard_data():
        try:
            today_start = datetime.combine(datetime.now(PARKING_TIMEZONE).date(), time.min, PARKING_TIMEZONE)
            total_users = read_count(users_table().select("id", count="exact").limit(1))
            vehicles_inside = read_count(
                users_table().select("id", count="exact").eq("current_status", "INSIDE").limit(1)
            )
            entries_today = read_count(
                events_table().select("id", count="exact").eq("direction", "ENTRY")
                .eq("access_status", "GRANTED").gte("card_tapped_at", today_start.isoformat())
                .not_.is_("vehicle_passed_at", "null").limit(1)
            )
            exits_today = read_count(
                events_table().select("id", count="exact").eq("direction", "EXIT")
                .eq("access_status", "GRANTED").gte("card_tapped_at", today_start.isoformat())
                .not_.is_("vehicle_passed_at", "null").limit(1)
            )
            return jsonify({
                "configured": True,
                "stats": {
                    "registered_users": total_users,
                    "vehicles_inside": vehicles_inside,
                    "entries_today": entries_today,
                    "exits_today": exits_today,
                },
            })
        except SupabaseNotConfigured:
            return jsonify({"configured": False, "setup_required": True, "stats": {}})
        except Exception:
            log_database_error("dashboard data")
            return jsonify({"configured": True, "error": "connection", "stats": {}}), 503

    @app.get("/api/dashboard/recent")
    def dashboard_recent_events():
        try:
            response = events_table().select(EVENT_COLUMNS).order("card_tapped_at", desc=True).limit(8).execute()
            return jsonify({"items": response.data or []})
        except SupabaseNotConfigured:
            return jsonify({"items": [], "setup_required": True})
        except Exception:
            log_database_error("recent parking access")
            return jsonify({"error": "connection", "items": []}), 503

    @app.get("/api/users")
    def list_users():
        page, limit = page_args()
        try:
            query = users_table().select(
                "id,full_name,email,phone,vehicle_plate,rfid_uid,is_active,current_status,created_at",
                count="exact",
            )
            search = safe_search(request.args.get("q"))
            if search:
                pattern = f"%{search}%"
                query = query.or_(
                    f"full_name.ilike.{pattern},vehicle_plate.ilike.{pattern},rfid_uid.ilike.{pattern}"
                )
            response = query.order("created_at", desc=True).range((page - 1) * limit, page * limit - 1).execute()
            return jsonify({"items": response.data or [], "total": int(response.count or 0), "page": page, "limit": limit})
        except SupabaseNotConfigured:
            return jsonify({"items": [], "total": 0, "page": page, "limit": limit, "setup_required": True})
        except Exception:
            log_database_error("parking users")
            return jsonify({"error": "connection", "items": [], "total": 0}), 503

    @app.post("/api/users")
    def add_user():
        payload = request.get_json(silent=True) or {}
        full_name = str(payload.get("full_name", "")).strip()
        vehicle_plate = re.sub(r"\s+", " ", str(payload.get("vehicle_plate", "")).strip()).upper()
        rfid_uid = RFID_SEPARATORS.sub("", str(payload.get("rfid_uid", "")).strip()).upper()
        email = str(payload.get("email", "")).strip() or None
        phone = str(payload.get("phone", "")).strip() or None

        if not 2 <= len(full_name) <= 120:
            return jsonify({"error": "Enter a name between 2 and 120 characters."}), 400
        if not 2 <= len(vehicle_plate) <= 24:
            return jsonify({"error": "Enter a valid vehicle plate number."}), 400
        if not 4 <= len(rfid_uid) <= 40 or not re.fullmatch(r"[A-Z0-9]+", rfid_uid):
            return jsonify({"error": "Enter an RFID UID between 4 and 40 letters or numbers."}), 400
        if email and (len(email) > 254 or not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email)):
            return jsonify({"error": "Enter a valid email address."}), 400
        if phone and len(phone) > 32:
            return jsonify({"error": "Phone number is too long."}), 400

        record = {
            "full_name": full_name,
            "email": email,
            "phone": phone,
            "vehicle_plate": vehicle_plate,
            "rfid_uid": rfid_uid,
            "is_active": True,
            "current_status": "OUTSIDE",
        }
        try:
            response = users_table().insert(record).execute()
            inserted = (response.data or [None])[0]
            if not inserted:
                return jsonify({"error": "The user could not be saved."}), 502
            return jsonify({"item": inserted}), 201
        except SupabaseNotConfigured:
            return jsonify({"error": "Add the Smart Parking Supabase secret key to .env first."}), 503
        except Exception as error:
            log_database_error("new parking user")
            if "23505" in str(error) or "duplicate key" in str(error).lower() or "unique constraint" in str(error).lower():
                return jsonify({"error": "That RFID card is already registered."}), 409
            return jsonify({"error": "Could not save this user. Check the Supabase table setup and try again."}), 503

    @app.get("/api/events")
    def list_events():
        page, limit = page_args()
        try:
            query = events_table().select(EVENT_COLUMNS, count="exact")
            direction = request.args.get("direction", "").upper()
            if direction in {"ENTRY", "EXIT"}:
                query = query.eq("direction", direction)
            search = safe_search(request.args.get("q"))
            if search:
                query = query.ilike("card_uid", f"%{search}%")
            response = query.order("card_tapped_at", desc=True).range((page - 1) * limit, page * limit - 1).execute()
            return jsonify({"items": response.data or [], "total": int(response.count or 0), "page": page, "limit": limit})
        except SupabaseNotConfigured:
            return jsonify({"items": [], "total": 0, "page": page, "limit": limit, "setup_required": True})
        except Exception:
            log_database_error("access events")
            return jsonify({"error": "connection", "items": [], "total": 0}), 503

    @app.post("/api/device/card-tap")
    def device_card_tap():
        auth_error = require_device_key()
        if auth_error:
            return auth_error

        payload = request.get_json(silent=True) or {}
        card_uid = RFID_SEPARATORS.sub("", str(payload.get("card_uid", ""))).upper()
        if not 4 <= len(card_uid) <= 40 or not re.fullmatch(r"[A-Z0-9]+", card_uid):
            return jsonify({"error": "A valid RFID UID is required."}), 400

        try:
            result = users_table().select(
                "id,full_name,vehicle_plate,rfid_uid,is_active,current_status"
            ).eq("rfid_uid", card_uid).limit(1).execute()
            user = (result.data or [None])[0]
            direction = "EXIT" if user and user.get("current_status") == "INSIDE" else "ENTRY"
            authorized = bool(user and user.get("is_active", True))
            record = {
                "parking_user_id": user.get("id") if user else None,
                "user_name": user.get("full_name") if user else None,
                "vehicle_plate": user.get("vehicle_plate") if user else None,
                "card_uid": card_uid,
                "direction": direction,
                "access_status": "GRANTED" if authorized else "DENIED",
            }
            inserted = events_table().insert(record).execute()
            event = (inserted.data or [None])[0]
            if not event:
                return jsonify({"error": "The card event could not be saved."}), 502
            return jsonify({
                "event_id": event["id"],
                "authorized": authorized,
                "direction": direction,
                "user_name": record["user_name"],
                "vehicle_plate": record["vehicle_plate"],
                "message": "Access granted." if authorized else "Card is not registered or is inactive.",
            })
        except SupabaseNotConfigured:
            return jsonify({"error": "The server-side Supabase secret is not configured."}), 503
        except Exception:
            log_database_error("ESP32 card tap")
            return jsonify({"error": "The card event could not be saved to Supabase."}), 503

    @app.post("/api/device/passage")
    def device_vehicle_passage():
        auth_error = require_device_key()
        if auth_error:
            return auth_error

        payload = request.get_json(silent=True) or {}
        event_id = str(payload.get("event_id", "")).strip()
        if not re.fullmatch(r"[0-9a-fA-F-]{36}", event_id):
            return jsonify({"error": "A valid event ID is required."}), 400

        try:
            existing = events_table().select("id,access_status,vehicle_passed_at").eq("id", event_id).limit(1).execute()
            event = (existing.data or [None])[0]
            if not event:
                return jsonify({"error": "The access event was not found."}), 404
            if event["access_status"] != "GRANTED":
                return jsonify({"error": "A denied card tap cannot be confirmed as a passage."}), 409
            if event.get("vehicle_passed_at"):
                return jsonify({"confirmed": True, "already_confirmed": True})

            updated = events_table().update({
                "vehicle_passed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", event_id).eq("access_status", "GRANTED").select("id,vehicle_passed_at").execute()
            if not updated.data:
                return jsonify({"error": "The vehicle passage could not be confirmed."}), 409
            return jsonify({"confirmed": True, "already_confirmed": False})
        except SupabaseNotConfigured:
            return jsonify({"error": "The server-side Supabase secret is not configured."}), 503
        except Exception:
            log_database_error("ESP32 vehicle passage")
            return jsonify({"error": "The vehicle passage could not be saved to Supabase."}), 503

    @app.post("/api/device/heartbeat")
    def device_heartbeat():
        auth_error = require_device_key()
        if auth_error:
            return auth_error

        payload = request.get_json(silent=True) or {}
        try:
            wifi_rssi = int(payload.get("wifi_rssi")) if payload.get("wifi_rssi") is not None else None
        except (TypeError, ValueError):
            wifi_rssi = None
        now = datetime.now(timezone.utc)
        with DEVICE_STATUS_LOCK:
            DEVICE_STATUS.update({
                "last_seen": now.isoformat(),
                "gate_open": payload.get("gate_open") is True,
                "ir_entry_detected": payload.get("ir_entry_detected") is True,
                "ir_exit_detected": payload.get("ir_exit_detected") is True,
                "wifi_rssi": wifi_rssi,
                "_last_seen_monotonic": monotonic(),
            })
        return jsonify({"received": True})

    @app.get("/api/device/status")
    def device_status():
        with DEVICE_STATUS_LOCK:
            status = dict(DEVICE_STATUS)
        last_seen_age = monotonic() - status.pop("_last_seen_monotonic")
        status["online"] = last_seen_age <= 25
        status["seconds_since_seen"] = round(last_seen_age) if status["last_seen"] else None
        return jsonify(status)

    return app


app = create_app()


if __name__ == "__main__":
    if os.getenv("PARKLINE_OPEN_BROWSER", "1") != "0":
        threading.Timer(1.2, lambda: webbrowser.open("http://127.0.0.1:5000")).start()
    print("Smart Parking Dashboard: http://127.0.0.1:5000")
    host = os.getenv("PARKING_HOST", "127.0.0.1").strip() or "127.0.0.1"
    print("The browser dashboard is restricted to this computer; the ESP32 API uses its device key.")
    app.run(host=host, port=5000, debug=False, threaded=True)
