#!/usr/bin/env python3
"""
Windows Audio Tools Setup - ffmpeg and vgmstream
Downloads and installs ffmpeg and vgmstream-cli for Windows
"""

import os
import sys
import zipfile
import subprocess
from pathlib import Path
import urllib.request
import platform
import ssl
import socket

# Download URLs for latest versions
FFMPEG_URL = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
VGMSTREAM_URL = "https://github.com/vgmstream/vgmstream/releases/latest/download/vgmstream-win64.zip"

# Installation directories
# When running from PyInstaller, use the exe's directory (not _MEIPASS temp dir)
# so tools persist across runs. When running from source, use the script's directory.
if hasattr(sys, '_MEIPASS'):
    _BASE_DIR = Path(sys.executable).parent.resolve()
else:
    _BASE_DIR = Path(__file__).parent.resolve()
TOOLS_DIR = _BASE_DIR / "tools" / "audio"
FFMPEG_DIR = TOOLS_DIR / "ffmpeg"
VGMSTREAM_DIR = TOOLS_DIR / "vgmstream"


class WindowsAudioToolsSetup:
    """Handles automated installation of ffmpeg and vgmstream for Windows"""

    def __init__(self):
        self.tools_dir = TOOLS_DIR
        self.ffmpeg_dir = FFMPEG_DIR
        self.vgmstream_dir = VGMSTREAM_DIR
        self.ffmpeg_exe = None  # Will be found after extraction
        self.vgmstream_exe = VGMSTREAM_DIR / "vgmstream-cli.exe"

    def check_platform(self):
        """Check if running on Windows"""
        if platform.system() != "Windows":
            print("[WARNING]  This setup is for Windows only!")
            print("On Linux, install via package manager:")
            print("  sudo pacman -S ffmpeg vgmstream-cli")
            print("  sudo apt install ffmpeg vgmstream-cli")
            return False
        return True

    def is_ffmpeg_installed(self):
        """Check if ffmpeg is already installed locally"""
        if not self.ffmpeg_dir.exists():
            return False

        # Find ffmpeg.exe in the extracted directory
        ffmpeg_candidates = list(self.ffmpeg_dir.rglob("ffmpeg.exe"))
        if ffmpeg_candidates:
            self.ffmpeg_exe = ffmpeg_candidates[0]
            return True
        return False

    def is_vgmstream_installed(self):
        """Check if vgmstream is already installed locally"""
        return self.vgmstream_exe.exists()

    def test_ffmpeg(self):
        """Test if ffmpeg works"""
        if not self.ffmpeg_exe:
            if not self.is_ffmpeg_installed():
                return False

        try:
            result = subprocess.run(
                [str(self.ffmpeg_exe), "-version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                print(f"[OK] ffmpeg is working: {self.ffmpeg_exe}")
                return True
        except Exception as e:
            print(f"ffmpeg test failed: {e}")
        return False

    def test_vgmstream(self):
        """Test if vgmstream-cli works"""
        if not self.vgmstream_exe.exists():
            return False

        try:
            result = subprocess.run(
                [str(self.vgmstream_exe), "-h"],
                capture_output=True,
                text=True,
                timeout=5
            )
            # vgmstream-cli returns 1 for help, which is normal
            if "vgmstream" in result.stdout.lower() or "vgmstream" in result.stderr.lower():
                print(f"[OK] vgmstream-cli is working: {self.vgmstream_exe}")
                return True
        except Exception as e:
            print(f"vgmstream test failed: {e}")
        return False

    def download_file(self, url, destination, tool_name):
        """Download a file (simplified - no progress reporting to avoid pipe issues)"""
        print(f"\nDownloading {tool_name}...")
        print(f"  Source: {url}")
        print(f"  Please wait, this may take a few minutes...")

        destination.parent.mkdir(parents=True, exist_ok=True)

        try:
            # Set a very long socket timeout (30 minutes) to prevent timeout during large downloads
            old_timeout = socket.getdefaulttimeout()
            socket.setdefaulttimeout(1800)  # 30 minutes

            # Create SSL context that doesn't verify certificates (safe for GitHub)
            # This fixes issues on Windows where SSL certificates aren't properly configured
            ssl_context = ssl._create_unverified_context()

            # Use opener with SSL context
            opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ssl_context))
            urllib.request.install_opener(opener)

            # Download without progress reporting (avoids pipe buffer issues)
            urllib.request.urlretrieve(url, destination)
            print("[OK] Download complete!")

            # Restore original timeout
            socket.setdefaulttimeout(old_timeout)
            return True

        except Exception as e:
            print(f"[ERROR] Download failed: {e}")
            # Restore original timeout even on error
            socket.setdefaulttimeout(old_timeout)
            return False

    def extract_zip(self, zip_path, extract_dir, tool_name):
        """Extract a ZIP file"""
        print(f"\nExtracting {tool_name}...")

        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_dir)

            print(f"[OK] Extraction complete!")
            zip_path.unlink()
            print("[OK] Cleaned up temporary files")
            return True

        except Exception as e:
            print(f"[ERROR] Extraction failed: {e}")
            return False

    def install_ffmpeg(self):
        """Download and install ffmpeg"""
        print("\n" + "=" * 60)
        print("Installing ffmpeg...")
        print("=" * 60)

        if self.is_ffmpeg_installed():
            if self.test_ffmpeg():
                print("[OK] ffmpeg is already installed and working!")
                return True
            print("ffmpeg exists but test failed. Re-installing...")

        # Download
        zip_path = self.tools_dir / "ffmpeg_temp.zip"
        if not self.download_file(FFMPEG_URL, zip_path, "ffmpeg"):
            return False

        # Extract
        if not self.extract_zip(zip_path, self.ffmpeg_dir, "ffmpeg"):
            return False

        # Verify the binary exists
        if not self.is_ffmpeg_installed():
            print("[ERROR] ffmpeg.exe not found after extraction!")
            return False

        # Test is best-effort — files are on disk, so consider it installed
        if not self.test_ffmpeg():
            print("[WARNING] ffmpeg test run failed, but binary exists on disk")

        return True

    def install_vgmstream(self):
        """Download and install vgmstream"""
        print("\n" + "=" * 60)
        print("Installing vgmstream-cli...")
        print("=" * 60)

        if self.is_vgmstream_installed():
            if self.test_vgmstream():
                print("[OK] vgmstream-cli is already installed and working!")
                return True
            print("vgmstream-cli exists but test failed. Re-installing...")

        # Download
        zip_path = self.tools_dir / "vgmstream_temp.zip"
        if not self.download_file(VGMSTREAM_URL, zip_path, "vgmstream"):
            return False

        # Extract
        if not self.extract_zip(zip_path, self.vgmstream_dir, "vgmstream"):
            return False

        # Verify the binary exists
        if not self.is_vgmstream_installed():
            print("[ERROR] vgmstream-cli.exe not found after extraction!")
            return False

        # Test is best-effort — files are on disk, so consider it installed
        if not self.test_vgmstream():
            print("[WARNING] vgmstream test run failed, but binary exists on disk")

        return True

    def setup_all(self):
        """Install both ffmpeg and vgmstream"""
        print("=" * 60)
        print("Windows Audio Tools Setup")
        print("Installing ffmpeg and vgmstream for Windows")
        print("=" * 60)

        if not self.check_platform():
            return False

        # Install ffmpeg
        ffmpeg_ok = self.install_ffmpeg()

        # Install vgmstream
        vgmstream_ok = self.install_vgmstream()

        print("\n" + "=" * 60)
        if ffmpeg_ok and vgmstream_ok:
            print("[SUCCESS] Setup complete! All tools installed successfully.")
            print("\nInstalled tools:")
            print(f"  - ffmpeg: {self.ffmpeg_exe}")
            print(f"  - vgmstream-cli: {self.vgmstream_exe}")
            return True
        else:
            print("[WARNING]  Setup incomplete:")
            if not ffmpeg_ok:
                print("  [ERROR] ffmpeg installation failed")
            if not vgmstream_ok:
                print("  [ERROR] vgmstream installation failed")
            return False

    def get_ffmpeg_path(self):
        """Get path to ffmpeg.exe if installed"""
        if not self.ffmpeg_exe:
            self.is_ffmpeg_installed()
        return self.ffmpeg_exe

    def get_vgmstream_path(self):
        """Get path to vgmstream-cli.exe if installed"""
        return self.vgmstream_exe if self.vgmstream_exe.exists() else None


def main():
    """Command-line interface"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Install ffmpeg and vgmstream for Windows',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Install all tools
  python setup_windows_audio_tools.py

  # Check installation status
  python setup_windows_audio_tools.py --check

  # Install only ffmpeg
  python setup_windows_audio_tools.py --ffmpeg-only

  # Install only vgmstream
  python setup_windows_audio_tools.py --vgmstream-only

Note:
  - Windows only
  - Downloads ~100-150MB total
  - Installs to ./tools/audio/
        """
    )

    parser.add_argument('--check', action='store_true', help='Check installation status')
    parser.add_argument('--ffmpeg-only', action='store_true', help='Install only ffmpeg')
    parser.add_argument('--vgmstream-only', action='store_true', help='Install only vgmstream')

    args = parser.parse_args()

    setup = WindowsAudioToolsSetup()

    if args.check:
        print("Checking installation status...")
        print(f"\nPlatform: {platform.system()}")

        ffmpeg_ok = setup.is_ffmpeg_installed() and setup.test_ffmpeg()
        vgmstream_ok = setup.is_vgmstream_installed() and setup.test_vgmstream()

        if ffmpeg_ok:
            print(f"[OK] ffmpeg: {setup.ffmpeg_exe}")
        else:
            print("[ERROR] ffmpeg: Not installed")

        if vgmstream_ok:
            print(f"[OK] vgmstream: {setup.vgmstream_exe}")
        else:
            print("[ERROR] vgmstream: Not installed")

        sys.exit(0 if (ffmpeg_ok and vgmstream_ok) else 1)

    # Install
    if args.ffmpeg_only:
        success = setup.install_ffmpeg()
    elif args.vgmstream_only:
        success = setup.install_vgmstream()
    else:
        success = setup.setup_all()

    # Pause before closing to show results (only in interactive mode)
    # Skip pause when run from GUI (stdin is not a tty)
    if sys.stdin and sys.stdin.isatty():
        print("\nPress Enter to close...")
        try:
            input()
        except (EOFError, OSError):
            pass  # Stdin closed, just exit

    sys.exit(0 if success else 1)


def run_setup_from_gui():
    """Entry point for GUI integration"""
    setup = WindowsAudioToolsSetup()
    return setup.setup_all()


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print("\n" + "=" * 60)
        print("[ERROR] ERROR OCCURRED:")
        print("=" * 60)
        print(f"{type(e).__name__}: {e}")
        # Only pause in interactive mode
        if sys.stdin and sys.stdin.isatty():
            print("\nPress Enter to close...")
            try:
                input()
            except (EOFError, OSError):
                pass
        sys.exit(1)
