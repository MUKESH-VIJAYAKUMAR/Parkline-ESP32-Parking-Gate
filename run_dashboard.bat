@echo off
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if errorlevel 1 (
    echo Python launcher ^(py^) was not found. Install Python 3.11 or newer and try again.
    pause
    exit /b 1
)

py -3.12 -V >nul 2>nul
if errorlevel 1 (
    echo Python 3.12 was not found. Install Python 3.12 and try again.
    pause
    exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
    py -3.12 -m venv .venv
    if errorlevel 1 (
        echo Could not create the Python environment.
        pause
        exit /b 1
    )
)

".venv\Scripts\python.exe" -c "import flask, supabase, dotenv" >nul 2>nul
if errorlevel 1 (
    echo Installing the pinned dashboard dependencies...
    ".venv\Scripts\python.exe" -m pip install -r requirements.txt
    if errorlevel 1 (
        echo Dependency installation failed. Check your internet connection and try again.
        pause
        exit /b 1
    )
)

if not exist ".env" (
    echo Supabase is not configured yet. Copy .env.example to .env and add your secret key.
    echo The dashboard will still open and show setup instructions.
)

".venv\Scripts\python.exe" app.py
pause
