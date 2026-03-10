

import sys
import os
import json
import shutil
import ssl
import tarfile
import zipfile
import urllib.request
import urllib.error
from pathlib import Path

from PyQt5.QtCore import QObject, pyqtSlot, pyqtSignal, QThread

from src.config_manager import get_cache_dir, get_settings_file
from src.app_config import APP_NAME

GITHUB_API_URL = f"https://api.github.com/repos/Pucas01/{APP_NAME}/releases/latest"


def _get_ssl_context():
    # pyinstaller doesn't bundle certs, so fall back to unverified if needed
    try:
        return ssl.create_default_context()
    except Exception:
        return ssl._create_unverified_context()


def _urlopen(req, timeout=10):
    try:
        return urllib.request.urlopen(req, timeout=timeout)
    except urllib.error.URLError as e:
        if "CERTIFICATE_VERIFY_FAILED" in str(e):
            ctx = ssl._create_unverified_context()
            return urllib.request.urlopen(req, timeout=timeout, context=ctx)
        raise


def parse_version(version_str):
    cleaned = version_str.lstrip("v").strip()
    parts = cleaned.split(".")
    return tuple(int(p) for p in parts)


class UpdateCheckWorker(QThread):
    updateAvailable = pyqtSignal(str, str, str)  # version, download_url, release_notes
    noUpdateAvailable = pyqtSignal()
    errorOccurred = pyqtSignal(str)

    def __init__(self, current_version, github_token=""):
        super().__init__()
        self.current_version = current_version
        self.github_token = github_token

    def run(self):
        try:
            req = urllib.request.Request(GITHUB_API_URL)
            req.add_header("Accept", "application/vnd.github.v3+json")
            req.add_header("User-Agent", "ZZAR-Updater")

            if self.github_token:
                req.add_header("Authorization", f"token {self.github_token}")

            with _urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode())

            tag = data.get("tag_name", "")
            if not tag:
                self.errorOccurred.emit("No tag found in latest release")
                return

            latest_version = parse_version(tag)
            current_version = parse_version(self.current_version)

            if latest_version <= current_version:
                self.noUpdateAvailable.emit()
                return

            if sys.platform.startswith("win"):
                asset_name = "ZZAR-windows-x64.zip"
            else:
                asset_name = "ZZAR-linux-x64.flatpak"

            download_url = ""
            for asset in data.get("assets", []):
                if asset["name"] == asset_name:
                    # api url needs token auth, browser url works without
                    if self.github_token:
                        download_url = asset["url"]
                    else:
                        download_url = asset["browser_download_url"]
                    break

            if not download_url:
                self.errorOccurred.emit(f"No {asset_name} found in release assets")
                return

            version_str = tag.lstrip("v")
            release_notes = data.get("body", "") or ""
            self.updateAvailable.emit(version_str, download_url, release_notes)

        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.errorOccurred.emit("No releases found (repo may be private - set a GitHub token in Settings)")
            elif e.code == 401 or e.code == 403:
                self.errorOccurred.emit("GitHub API authentication failed - check your token")
            else:
                self.errorOccurred.emit(f"GitHub API error: {e.code} {e.reason}")
        except urllib.error.URLError as e:
            self.errorOccurred.emit(f"Network error: {e.reason}")
        except Exception as e:
            self.errorOccurred.emit(f"Update check failed: {e}")


class UpdateDownloadWorker(QThread):
    downloadProgress = pyqtSignal(int)  # percent
    downloadFinished = pyqtSignal(str)  # extracted binary path
    errorOccurred = pyqtSignal(str)

    def __init__(self, download_url, github_token=""):
        super().__init__()
        self.download_url = download_url
        self.github_token = github_token

    def run(self):
        try:
            update_dir = get_cache_dir() / "updates"
            update_dir.mkdir(parents=True, exist_ok=True)

            if sys.platform.startswith("win"):
                archive_name = "ZZAR-windows-x64.zip"
            else:
                archive_name = "ZZAR-linux-x64.flatpak"

            archive_path = update_dir / archive_name

            req = urllib.request.Request(self.download_url)
            req.add_header("User-Agent", "ZZAR-Updater")
            req.add_header("Accept", "application/octet-stream")
            if self.github_token:
                req.add_header("Authorization", f"token {self.github_token}")

            with _urlopen(req, timeout=300) as response:
                total_size = int(response.headers.get("Content-Length", 0))
                block_size = 8192
                downloaded = 0

                with open(archive_path, "wb") as f:
                    while True:
                        chunk = response.read(block_size)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        if total_size > 0:
                            percent = min(int(downloaded * 100 / total_size), 100)
                            self.downloadProgress.emit(percent)

            if sys.platform.startswith("win"):
                with zipfile.ZipFile(archive_path, "r") as zf:
                    zf.extractall(update_dir)
                binary_path = update_dir / f"{APP_NAME}.exe"
            else:
                with tarfile.open(archive_path, "r:gz") as tf:
                    tf.extractall(update_dir)
                binary_path = update_dir / APP_NAME

            archive_path.unlink(missing_ok=True)

            if not binary_path.exists():
                self.errorOccurred.emit("Extracted binary not found")
                return

            self.downloadFinished.emit(str(binary_path))

        except Exception as e:
            self.errorOccurred.emit(f"Download failed: {e}")


class UpdateManagerBridge(QObject):
    updateAvailable = pyqtSignal(str, str)  # latest_version, release_notes
    updateNotAvailable = pyqtSignal()
    updateDownloaded = pyqtSignal()
    updateProgress = pyqtSignal(int)      # percent
    updateError = pyqtSignal(str)         # message
    updateApplied = pyqtSignal()          # binary replaced successfully

    def __init__(self):
        super().__init__()
        self._check_worker = None
        self._download_worker = None
        self._download_url = ""
        self._downloaded_binary = ""
        self._current_version = ""
        self._github_token = ""

        self._load_token()

    def _load_token(self):
        try:
            settings_file = get_settings_file()
            if settings_file.exists():
                with open(settings_file, "r") as f:
                    settings = json.load(f)
                self._github_token = settings.get("github_token", "")
        except Exception:
            pass

    def setCurrentVersion(self, version):
        self._current_version = version

    def setGithubToken(self, token):
        self._github_token = token
        try:
            settings_file = get_settings_file()
            settings = {}
            if settings_file.exists():
                with open(settings_file, "r") as f:
                    settings = json.load(f)
            settings["github_token"] = token
            settings_file.parent.mkdir(parents=True, exist_ok=True)
            with open(settings_file, "w") as f:
                json.dump(settings, f, indent=2)
        except Exception as e:
            print(f"[Updater] Failed to save token: {e}")

    @pyqtSlot()
    def checkForUpdates(self):
        if self._check_worker and self._check_worker.isRunning():
            return

        print(f"[Updater] Checking for updates (current: {self._current_version})")

        self._check_worker = UpdateCheckWorker(self._current_version, self._github_token)
        self._check_worker.updateAvailable.connect(self._on_update_available)
        self._check_worker.noUpdateAvailable.connect(self._on_no_update)
        self._check_worker.errorOccurred.connect(self._on_check_error)
        self._check_worker.start()

    def _on_update_available(self, version, download_url, release_notes):
        print(f"[Updater] Update available: {version}")
        self._download_url = download_url
        self.updateAvailable.emit(version, release_notes)

    def _on_no_update(self):
        print("[Updater] Already up to date")
        self.updateNotAvailable.emit()

    def _on_check_error(self, message):
        print(f"[Updater] Check error: {message}")
        self.updateError.emit(message)

    @pyqtSlot()
    def downloadAndInstall(self):
        if not self._download_url:
            self.updateError.emit("No download URL available")
            return

        if self._download_worker and self._download_worker.isRunning():
            return

        print(f"[Updater] Starting download from: {self._download_url}")

        self._download_worker = UpdateDownloadWorker(self._download_url, self._github_token)
        self._download_worker.downloadProgress.connect(self._on_download_progress)
        self._download_worker.downloadFinished.connect(self._on_download_finished)
        self._download_worker.errorOccurred.connect(self._on_download_error)
        self._download_worker.start()

    def _on_download_progress(self, percent):
        self.updateProgress.emit(percent)

    def _on_download_finished(self, binary_path):
        print(f"[Updater] Download complete: {binary_path}")
        self._downloaded_binary = binary_path
        self.updateDownloaded.emit()

    def _on_download_error(self, message):
        print(f"[Updater] Download error: {message}")
        self.updateError.emit(message)

    @staticmethod
    def _get_real_exe_path():
        # pyinstaller onefile: sys.executable is inside the temp _MEI dir,
        # not the actual exe on disk
        if hasattr(sys, '_MEIPASS'):
            if sys.platform.startswith("win"):
                import ctypes
                buf = ctypes.create_unicode_buffer(260)
                ctypes.windll.kernel32.GetModuleFileNameW(None, buf, 260)
                real_path = buf.value
                if real_path and Path(real_path).exists():
                    return real_path
            # linux/macOS: sys.argv[0] is the real binary path
            resolved = str(Path(sys.argv[0]).resolve())
            if Path(resolved).exists():
                return resolved
        return sys.executable

    @pyqtSlot()
    def applyUpdate(self):
        if not self._downloaded_binary or not Path(self._downloaded_binary).exists():
            self.updateError.emit("Downloaded binary not found")
            return

        try:
            current_exe = self._get_real_exe_path()
            print(f"[Updater] Applying update...")
            print(f"[Updater] sys.executable: {sys.executable}")
            print(f"[Updater] Real exe path: {current_exe}")
            print(f"[Updater] New binary: {self._downloaded_binary}")

            if sys.platform.startswith("win"):
                self._apply_windows_update(current_exe)
            else:
                self._apply_linux_update(current_exe)

            print(f"[Updater] Update applied successfully!")
            self.updateApplied.emit()

        except Exception as e:
            print(f"[Updater] Failed to apply update: {e}")
            self.updateError.emit(f"Failed to apply update: {e}")

    def _apply_linux_update(self, current_exe):
        new_binary = Path(self._downloaded_binary)
        target = Path(current_exe)

        backup = target.with_suffix(".bak")
        if backup.exists():
            backup.unlink()

        # can't overwrite a running binary on linux (ETXTBSY), rename it first
        target.rename(backup)
        shutil.copy2(str(new_binary), str(target))
        os.chmod(str(target), 0o755)

        new_binary.unlink(missing_ok=True)

        print(f"[Updater] Binary replaced: {target}")
        print(f"[Updater] Backup at: {backup}")

    def _apply_windows_update(self, current_exe):
        new_binary = Path(self._downloaded_binary)
        target = Path(current_exe)
        target_dir = target.parent
        backup = target_dir / "ZZAR.exe.bak"
        log_file = get_cache_dir() / "updates" / "update.log"

        bat_path = get_cache_dir() / "updates" / "update.bat"
        # ping for delays since timeout crashes without a console window
        bat_content = f"""@echo off
echo [ZZAR Updater] Starting update... > "{log_file}"
echo [ZZAR Updater] Target: {target} >> "{log_file}"
echo [ZZAR Updater] Source: {new_binary} >> "{log_file}"
echo [ZZAR Updater] Waiting for ZZAR to exit... >> "{log_file}"
set RETRIES=0
:waitloop
ping -n 3 127.0.0.1 >nul
set /a RETRIES+=1
if %RETRIES% GEQ 30 (
    echo [ZZAR Updater] ERROR: Timed out after 60s >> "{log_file}"
    goto :eof
)
rem Try to rename the running exe - fails if still locked
if exist "{backup}" del /F "{backup}" >nul 2>&1
rename "{target}" "ZZAR.exe.bak" >nul 2>&1
if exist "{target}" (
    echo [ZZAR Updater] Still locked, attempt %RETRIES% >> "{log_file}"
    goto waitloop
)
echo [ZZAR Updater] Old binary renamed >> "{log_file}"
copy /Y /B "{new_binary}" "{target}" >nul 2>&1
if not exist "{target}" (
    echo [ZZAR Updater] Copy failed, restoring backup >> "{log_file}"
    rename "{backup}" "ZZAR.exe" >nul 2>&1
    goto :eof
)
echo [ZZAR Updater] Copy successful >> "{log_file}"
del /F "{backup}" >nul 2>&1
del /F "{new_binary}" >nul 2>&1
echo [ZZAR Updater] Launching updated ZZAR >> "{log_file}"
explorer.exe "{target}"
del "%~f0"
"""
        with open(bat_path, "w") as f:
            f.write(bat_content)

        print(f"[Updater] Batch script written to: {bat_path}")
        print(f"[Updater] Log file: {log_file}")
        print(f"[Updater] Target exe: {target}")
        print(f"[Updater] New binary: {new_binary}")

        import subprocess
        subprocess.Popen(
            ["cmd", "/c", str(bat_path)],
            creationflags=0x08000000,  # CREATE_NO_WINDOW
        )
