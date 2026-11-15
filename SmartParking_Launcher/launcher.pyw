from __future__ import annotations

import hashlib
import http.client
import os
import queue
import shutil
import socket
import subprocess
import sys
import threading
import time
import webbrowser
from pathlib import Path
import tkinter as tk


APP_TITLE = "Parkline Control Center"
DASHBOARD_URL = "http://127.0.0.1:5000"
STARTUP_TIMEOUT_SECONDS = 20.0
STARTUP_PROBE_TIMEOUT_SECONDS = 0.6
STARTUP_POLL_INTERVAL_SECONDS = 0.25
LOG_ROTATE_BYTES = 1_000_000
BG = "#F3F6F5"
INK = "#102D2B"
TEAL = "#147D73"
TEAL_DARK = "#0D655D"
MINT = "#DDF3ED"
MUTED = "#667774"
WHITE = "#FFFFFF"
RED = "#B54752"
AMBER = "#9A641A"
GREEN = "#2D805A"


class ParkingLauncher:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry("700x540")
        self.root.minsize(640, 500)
        self.root.configure(bg=BG)
        self.root.protocol("WM_DELETE_WINDOW", self._close)

        self.launcher_dir = Path(__file__).resolve().parent
        self.project_root = self.launcher_dir.parent
        self.logs_dir = self.launcher_dir / "logs"
        self.logs_dir.mkdir(parents=True, exist_ok=True)
        self.venv_python = self.project_root / ".venv" / "Scripts" / "python.exe"
        self.events: queue.Queue[tuple[str, object | None]] = queue.Queue()
        self.process: subprocess.Popen | None = None
        self.log_handle = None
        self.owned = False
        self.running = False
        self.busy = False
        self.close_after_work = False
        self.last_probe_error: str | None = None

        self.status_text = tk.StringVar(value="Ready to start")
        self.detail_text = tk.StringVar(value=self._configuration_hint())
        self._build_ui()
        self._refresh_buttons()
        self.root.after(250, self._drain_events)
        self.root.after(900, self._monitor_process)
        # Double-clicking the launcher should start Flask and open the page without
        # requiring a second click in the control-center window.
        self.root.after(400, self._primary_action)

    def _build_ui(self) -> None:
        header = tk.Frame(self.root, bg=INK, padx=30, pady=24)
        header.pack(fill="x")
        tk.Label(header, text="PARKLINE  /  SMART PARKING", bg=INK, fg="#A9DDD2", font=("Segoe UI", 9, "bold")).pack(anchor="w")
        tk.Label(header, text="Control Center", bg=INK, fg=WHITE, font=("Segoe UI", 25, "bold")).pack(anchor="w", pady=(8, 2))
        tk.Label(header, text="Start and manage your local parking dashboard.", bg=INK, fg="#C5D6D3", font=("Segoe UI", 10)).pack(anchor="w")

        body = tk.Frame(self.root, bg=BG, padx=30, pady=24)
        body.pack(fill="both", expand=True)
        tk.Label(body, text="Dashboard", bg=BG, fg=INK, font=("Segoe UI", 17, "bold")).pack(anchor="w")
        tk.Label(body, text="Flask · Supabase · local workspace", bg=BG, fg=MUTED, font=("Segoe UI", 9)).pack(anchor="w", pady=(2, 15))

        card = tk.Frame(body, bg=WHITE, highlightbackground="#DDE6E3", highlightthickness=1, padx=20, pady=18)
        card.pack(fill="x")
        row = tk.Frame(card, bg=WHITE)
        row.pack(fill="x")
        tk.Label(row, text="●", bg=WHITE, fg=TEAL, font=("Segoe UI", 16, "bold")).pack(side="left", padx=(0, 11))
        labels = tk.Frame(row, bg=WHITE)
        labels.pack(side="left", fill="x", expand=True)
        tk.Label(labels, text="Smart Parking Dashboard", bg=WHITE, fg=INK, font=("Segoe UI", 11, "bold")).pack(anchor="w")
        tk.Label(labels, text=DASHBOARD_URL, bg=WHITE, fg=MUTED, font=("Segoe UI", 9)).pack(anchor="w", pady=(3, 0))
        self.status_badge = tk.Label(row, textvariable=self.status_text, bg=MINT, fg=TEAL_DARK, padx=11, pady=7, font=("Segoe UI", 9, "bold"))
        self.status_badge.pack(side="right", padx=(8, 0))

        actions = tk.Frame(body, bg=BG)
        actions.pack(fill="x", pady=(17, 12))
        self.start_button = tk.Button(actions, text="Start dashboard", command=self._primary_action, bg=TEAL, fg=WHITE, activebackground=TEAL_DARK, activeforeground=WHITE, relief="flat", bd=0, cursor="hand2", font=("Segoe UI", 10, "bold"), padx=18, pady=11)
        self.start_button.pack(side="left")
        self.open_button = tk.Button(actions, text="Open dashboard", command=self._open_dashboard, bg=WHITE, fg=INK, activebackground="#E9F2EF", relief="flat", bd=0, cursor="hand2", font=("Segoe UI", 10, "bold"), padx=16, pady=11)
        self.open_button.pack(side="left", padx=(10, 0))

        note = tk.Frame(body, bg="#E8F2EF", padx=14, pady=12)
        note.pack(fill="x", pady=(3, 0))
        tk.Label(note, textvariable=self.detail_text, bg="#E8F2EF", fg="#385650", font=("Segoe UI", 9), wraplength=590, justify="left", anchor="w").pack(fill="x")

        footer = tk.Frame(body, bg=BG)
        footer.pack(fill="x", side="bottom", pady=(18, 0))
        tk.Label(footer, text="Dashboard and gate device use this computer’s private Wi-Fi network.", bg=BG, fg=MUTED, font=("Segoe UI", 8)).pack(side="left")
        tk.Label(footer, text="Logs are saved in SmartParking_Launcher/logs", bg=BG, fg=MUTED, font=("Segoe UI", 8)).pack(side="right")

    def _configuration_hint(self) -> str:
        env_file = self.project_root / ".env"
        if not env_file.is_file():
            return "Supabase is not configured yet. Copy .env.example to .env and add the server-side key. The dashboard can still open in setup mode."
        values: dict[str, str] = {}
        try:
            for line in env_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    name, value = line.split("=", 1)
                    values[name.strip()] = value.strip().strip('"').strip("'")
        except OSError:
            return "The local .env file could not be read. Check its file permissions."
        key = values.get("SUPABASE_SECRET_KEY") or values.get("SUPABASE_SERVICE_ROLE_KEY")
        if not key or key.lower().startswith(("replace-", "your-", "change-me")):
            return "The local .env file is missing a server-side Supabase key. Add it there; the launcher never displays the key."
        return "Supabase settings are present. The server-side key stays in the local .env file."

    @staticmethod
    def _console_python() -> Path | None:
        executable = Path(sys.executable)
        if executable.name.lower().startswith("pythonw"):
            executable = executable.with_name("python.exe")
        if executable.is_file():
            return executable
        located = shutil.which("python")
        if located:
            return Path(located)
        local_app = Path(os.environ.get("LOCALAPPDATA", ""))
        candidate = local_app / "Programs" / "Python" / "Python312" / "python.exe"
        return candidate if candidate.is_file() else None

    def _run_setup(self, command: list[str], log_path: Path, timeout: int) -> bool:
        try:
            with log_path.open("a", encoding="utf-8", errors="replace") as log:
                result = subprocess.run(command, cwd=self.project_root, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), timeout=timeout, check=False)
            return result.returncode == 0
        except (OSError, subprocess.SubprocessError) as exc:
            self.events.put(("error", f"Setup could not finish ({type(exc).__name__}). See the setup log."))
            return False

    def _prepare_environment(self) -> bool:
        requirements = self.project_root / "requirements.txt"
        if not requirements.is_file():
            self.events.put(("error", "requirements.txt is missing from the project folder."))
            return False
        if not self.venv_python.is_file():
            python = self._console_python()
            if python is None:
                self.events.put(("error", "Python 3.11 or newer was not found. Install Python, then reopen the launcher."))
                return False
            self.events.put(("status", "Preparing Python environment…"))
            if not self._run_setup([str(python), "-m", "venv", str(self.venv_python.parent.parent)], self.logs_dir / "setup.log", 240):
                self.events.put(("error", "Could not create .venv. See SmartParking_Launcher/logs/setup.log."))
                return False

        marker = self.venv_python.parent.parent / ".parkline-requirements-sha256"
        requirements_hash = hashlib.sha256(requirements.read_bytes()).hexdigest()
        try:
            installed_hash = marker.read_text(encoding="ascii").strip() if marker.is_file() else ""
        except OSError:
            installed_hash = ""
        if installed_hash != requirements_hash:
            self.events.put(("status", "Installing or updating dashboard packages…"))
            command = [str(self.venv_python), "-m", "pip", "install", "-r", str(requirements)]
            if not self._run_setup(command, self.logs_dir / "setup.log", 900):
                self.events.put(("error", "Package setup failed. Check your internet connection and setup.log."))
                return False
            try:
                marker.write_text(requirements_hash, encoding="ascii")
            except OSError:
                self.events.put(("error", "Packages installed, but the environment marker could not be saved."))
                return False
        return True

    @staticmethod
    def _port_open() -> bool:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.25)
            return sock.connect_ex(("127.0.0.1", 5000)) == 0

    def _dashboard_responds(self, timeout: float = STARTUP_PROBE_TIMEOUT_SECONDS) -> bool:
        connection = http.client.HTTPConnection("127.0.0.1", 5000, timeout=timeout)
        try:
            connection.request("GET", "/")
            response = connection.getresponse()
            with response:
                body = response.read(2048).decode("utf-8", errors="ignore")
                if response.status == 200 and "<html" in body.lower():
                    self.last_probe_error = None
                    return True
                self.last_probe_error = f"HTTP {response.status} from the dashboard"
                return False
        except (OSError, http.client.HTTPException, TimeoutError) as exc:
            self.last_probe_error = f"{type(exc).__name__}: {exc}"
            return False
        finally:
            connection.close()

    @staticmethod
    def _find_brave() -> Path | None:
        located = shutil.which("brave") or shutil.which("brave.exe")
        local_app = Path(os.environ.get("LOCALAPPDATA", ""))
        candidates = [
            Path(located) if located else None,
            Path(r"C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"),
            Path(r"C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe"),
            local_app / "BraveSoftware" / "Brave-Browser" / "Application" / "brave.exe",
        ]
        return next((candidate for candidate in candidates if candidate and candidate.is_file()), None)

    def _open_browser(self) -> None:
        brave = self._find_brave()
        try:
            if brave:
                subprocess.Popen([str(brave), DASHBOARD_URL], cwd=self.project_root, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0), close_fds=True)
            else:
                webbrowser.open_new(DASHBOARD_URL)
        except OSError as exc:
            self.events.put(("error", f"The dashboard is running, but the browser could not open ({type(exc).__name__}). Use {DASHBOARD_URL}."))

    def _open_dashboard(self) -> None:
        if not self._dashboard_responds():
            self.running = True
            self.status_text.set("Checking access")
            self.status_badge.configure(bg="#FFF1D6", fg=AMBER)
            self.detail_text.set("Opening the dashboard to check access. Flask is still running; check the dashboard log if the page stays unavailable.")
            self._refresh_buttons()
            self._open_browser()
            return
        self.running = True
        self.status_text.set("Running")
        self.status_badge.configure(bg=MINT, fg=TEAL_DARK)
        self._refresh_buttons()
        self._open_browser()

    def _primary_action(self) -> None:
        if self.busy:
            return
        if self.owned and self.process and self.process.poll() is None:
            self.busy = True
            self.status_text.set("Stopping…")
            threading.Thread(target=self._stop_owned_process, daemon=True).start()
        elif self.running:
            self._open_browser()
        else:
            self.busy = True
            self.status_text.set("Starting…")
            self._refresh_buttons()
            threading.Thread(target=self._start_worker, daemon=True).start()

    def _start_worker(self) -> None:
        if self._dashboard_responds():
            self.events.put(("external", None))
            self._open_browser()
            return
        if self._port_open():
            # A previous launcher may still be bringing Flask up. Give it a
            # moment to answer HTTP before treating the occupied port as an error.
            deadline = time.monotonic() + 3.0
            while time.monotonic() < deadline and self._port_open():
                if self._dashboard_responds(timeout=STARTUP_PROBE_TIMEOUT_SECONDS):
                    self.events.put(("external", None))
                    self._open_browser()
                    return
                time.sleep(STARTUP_POLL_INTERVAL_SECONDS)
            if self._port_open():
                self.events.put(("error", "Port 5000 is in use, but it is not answering as the Smart Parking dashboard. Close that app and try again."))
                return
        if not self._prepare_environment():
            return
        if self._dashboard_responds():
            self.events.put(("external", None))
            self._open_browser()
            return

        environment = os.environ.copy()
        environment["PARKLINE_OPEN_BROWSER"] = "0"
        environment["PYTHONUNBUFFERED"] = "1"
        log_path = self.logs_dir / "dashboard.log"
        try:
            if log_path.is_file() and log_path.stat().st_size >= LOG_ROTATE_BYTES:
                log_path.replace(self.logs_dir / "dashboard.previous.log")
        except OSError:
            pass
        try:
            self.log_handle = log_path.open("a", encoding="utf-8", errors="replace")
            process = subprocess.Popen(
                [str(self.venv_python), str(self.project_root / "app.py")],
                cwd=self.project_root,
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=self.log_handle,
                stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                close_fds=True,
            )
        except OSError as exc:
            self._close_log()
            self.events.put(("error", f"Flask could not start ({type(exc).__name__}). See dashboard.log."))
            return

        self.events.put(("started", process))
        deadline = time.monotonic() + STARTUP_TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            if process.poll() is not None:
                self.events.put(("start_failed", "Flask stopped during startup. Check SmartParking_Launcher/logs/dashboard.log."))
                return
            if self._dashboard_responds(timeout=STARTUP_PROBE_TIMEOUT_SECONDS):
                self.events.put(("ready", None))
                self._open_browser()
                return
            time.sleep(min(STARTUP_POLL_INTERVAL_SECONDS, max(0.0, deadline - time.monotonic())))
        if process.poll() is None:
            detail = self.last_probe_error or "no HTTP response"
            self.events.put(("probe_timeout", detail))
            self._open_browser()
            return
        self.events.put(("start_failed", "Flask stopped during startup. Check SmartParking_Launcher/logs/dashboard.log."))

    def _stop_owned_process(self) -> None:
        process = self.process
        if process and process.poll() is None:
            try:
                process.terminate()
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
            except OSError:
                pass
        self.events.put(("stopped", None))

    def _refresh_buttons(self) -> None:
        self.open_button.configure(state="normal" if self.running else "disabled")
        if self.busy:
            self.start_button.configure(state="disabled", text="Please wait…")
        elif self.owned and self.process and self.process.poll() is None:
            self.start_button.configure(state="normal", text="Stop dashboard", bg=RED, activebackground="#963843")
        elif self.running:
            self.start_button.configure(state="normal", text="Open dashboard", bg=TEAL, activebackground=TEAL_DARK)
        else:
            self.start_button.configure(state="normal", text="Start dashboard", bg=TEAL, activebackground=TEAL_DARK)

    def _drain_events(self) -> None:
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "status":
                    self.status_text.set(str(payload))
                elif kind == "started":
                    self.process = payload if isinstance(payload, subprocess.Popen) else None
                    self.owned = self.process is not None
                elif kind == "ready":
                    self.running = True
                    self.status_text.set("Running")
                    self.status_badge.configure(bg=MINT, fg=TEAL_DARK)
                    self.detail_text.set("Dashboard is ready. Flask is using the local Supabase configuration.")
                    self.busy = False
                elif kind == "listening":
                    self.running = True
                    self.status_text.set("Listening")
                    self.status_badge.configure(bg=MINT, fg=TEAL_DARK)
                    self.detail_text.set("Flask is listening on port 5000. The page check did not finish, so the dashboard was opened for inspection.")
                    self.busy = False
                elif kind == "probe_timeout":
                    self.running = True
                    self.status_text.set("Check access")
                    self.status_badge.configure(bg="#FFF1D6", fg=AMBER)
                    self.detail_text.set(f"Flask started but the local page check timed out ({payload}). The server is being kept running so the browser and ESP32 can retry. Check SmartParking_Launcher/logs/dashboard.log if it stays unavailable.")
                    self.busy = False
                elif kind == "external":
                    self.running = True
                    self.owned = False
                    self.process = None
                    self.status_text.set("Already running")
                    self.status_badge.configure(bg=MINT, fg=TEAL_DARK)
                    self.busy = False
                elif kind == "stopped":
                    self.running = False
                    self.owned = False
                    self.process = None
                    self.status_text.set("Stopped")
                    self.status_badge.configure(bg="#EEF1F0", fg=MUTED)
                    self.busy = False
                    self._close_log()
                elif kind == "error":
                    self.status_text.set("Needs attention")
                    self.status_badge.configure(bg="#FCE9E9", fg=RED)
                    self.detail_text.set(str(payload))
                    self.busy = False
                elif kind == "start_failed":
                    self.running = False
                    self.owned = False
                    self.process = None
                    self.status_text.set("Needs attention")
                    self.status_badge.configure(bg="#FCE9E9", fg=RED)
                    self.detail_text.set(str(payload))
                    self.busy = False
                    self._close_log()
                self._refresh_buttons()
        except queue.Empty:
            pass
        if self.close_after_work and not self.busy:
            self.close_after_work = False
            self._close()
            return
        self.root.after(250, self._drain_events)

    def _monitor_process(self) -> None:
        if self.owned and self.process and self.process.poll() is not None:
            self.running = False
            self.owned = False
            self.process = None
            self.status_text.set("Stopped · check log")
            self.detail_text.set("Flask exited unexpectedly. Open SmartParking_Launcher/logs/dashboard.log for details.")
            self._close_log()
            self._refresh_buttons()
        self.root.after(900, self._monitor_process)

    def _close_log(self) -> None:
        if self.log_handle:
            try:
                self.log_handle.close()
            except OSError:
                pass
            self.log_handle = None

    def _close(self) -> None:
        if self.busy:
            self.close_after_work = True
            self.detail_text.set("Finishing current setup before closing…")
            return
        if self.owned and self.process and self.process.poll() is None:
            try:
                self.process.terminate()
                self.process.wait(timeout=4)
            except (OSError, subprocess.TimeoutExpired):
                try:
                    self.process.kill()
                except OSError:
                    pass
        self._close_log()
        self.root.destroy()


def main() -> None:
    root = tk.Tk()
    ParkingLauncher(root)
    root.mainloop()


if __name__ == "__main__":
    main()
