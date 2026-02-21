@echo off
REM ZZAR - Zenless Zone Zero Audio Replacer - GUI Launcher (Windows)

echo ================================
echo ZZAR - GUI Launcher
echo ================================
echo.

REM Check Python
where python >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X Python not found. Please install Python 3 from python.org
    pause
    exit /b 1
)
echo + Python found

REM Check PyQt5
python -c "import PyQt5" >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo X PyQt5 not found
    echo.
    echo Installing PyQt5...
    python -m pip install PyQt5
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo Failed to install PyQt5
        echo Please run: pip install PyQt5
        pause
        exit /b 1
    )
)
echo + PyQt5 found

REM Check PyQt5.QtQml
python -c "from PyQt5.QtQml import QQmlApplicationEngine" >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ! PyQt5.QtQml not found
    echo.
    echo The QML UI requires PyQt5 with QML support.
    echo Installing full PyQt5 package...
    python -m pip install --upgrade PyQt5
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo Failed to install PyQt5
        pause
        exit /b 1
    )
)
echo + PyQt5.QtQml found

echo.
echo Starting ZZAR GUI...
echo.

REM Run the GUI (pushd handles UNC paths properly)
pushd "%~dp0"
python ZZAR.py
set EXIT_CODE=%ERRORLEVEL%
popd

echo.
if %EXIT_CODE% NEQ 0 (
    echo.
    echo ========================================
    echo ERROR: Application exited with code %EXIT_CODE%
    echo ========================================
    echo.
    echo Press any key to close...
    pause >nul
    exit /b %EXIT_CODE%
)

echo GUI closed.
pause
