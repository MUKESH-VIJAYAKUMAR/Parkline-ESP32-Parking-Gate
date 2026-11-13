# Smart Parking Project Index

Parkline is a Flask dashboard for registering RFID users and viewing parking entry and exit events.

## Main files

| Path | Purpose |
| --- | --- |
| [`README.md`](README.md) | Setup, Supabase status, and dashboard operation |
| [`run_dashboard.bat`](run_dashboard.bat) | Windows launcher for the Flask dashboard |
| [`app.py`](app.py) | Flask routes, validation, and server-side Supabase access |
| [`requirements.txt`](requirements.txt) | Pinned Python dependencies |
| [`.env.example`](.env.example) | Safe local configuration template |
| [`database/schema.sql`](database/schema.sql) | Parking tables, indexes, RLS, and status trigger |
| [`templates/index.html`](templates/index.html) | Dashboard page entry point |
| [`static/css/dashboard.css`](static/css/dashboard.css) | Dashboard styling and responsive layout |
| [`static/js/dashboard.js`](static/js/dashboard.js) | Search, pagination, refresh, and UI behavior |
| [`static/parkline.svg`](static/parkline.svg) | Browser icon |

## Directory layout

```text
database/       SQL schema
templates/      Flask HTML templates
static/css/     Dashboard styles
static/js/      Dashboard behavior
```

## Local-only files

- `.env` stores the local Supabase server key and is ignored by Git.
- `.venv/` stores the local Python environment and is ignored by Git.
- `.git/` stores repository history and remote configuration; keep it intact.

Start with `README.md` for setup instructions. The dashboard's web entry page is `templates/index.html`.
