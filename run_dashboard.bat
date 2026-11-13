@echo off
setlocal
cd /d "%~dp0"

set "VENV_PYTHON=.venv\Scripts\python.exe"
if exist "%VENV_PYTHON%" goto CheckDependencies

set "PYTHON_COMMAND=py"
set "PYTHON_ARGS=-3.12"
py -3.12 -V >nul 2>nul
if errorlevel 1 (
    set "PYTHON_COMMAND=python"
    set "PYTHON_ARGS="
    python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)" >nul 2>nul
    if errorlevel 1 (
        set "PYTHON_COMMAND=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
    )
)

"%PYTHON_COMMAND%" %PYTHON_ARGS% -V >nul 2>nul
if errorlevel 1 (
    echo Python 3.11 or newer was not found. Install Python and try again.
    pause
    exit /b 1
)

"%PYTHON_COMMAND%" %PYTHON_ARGS% -m venv .venv
if errorlevel 1 (
    echo Could not create the Python environment.
    pause
    exit /b 1
)

:CheckDependencies
"%VENV_PYTHON%" -c "import flask, supabase, dotenv" >nul 2>nul
if errorlevel 1 (
    echo Installing the pinned dashboard dependencies...
    "%VENV_PYTHON%" -m pip install -r requirements.txt
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

"%VENV_PYTHON%" app.py
pause
