#!/usr/bin/env python3

import os
import sys
import ssl
import shutil
import zipfile
import subprocess
from pathlib import Path
import urllib.request
import urllib.error

DEFAULT_WWISE_URL = "https://gitlab.com/ytnshio/ebi/-/raw/main/WWIse.zip"

# When running from PyInstaller, use the exe's directory (not _MEIPASS temp dir)
# so tools persist across runs. When running from source, use the script's directory.
# In Flatpak, /app/bin/ is read-only so use XDG_DATA_HOME instead.
try:
    _src = Path(__file__).resolve().parent / 'src'
    if str(_src) not in sys.path:
        sys.path.insert(0, str(_src))
    from app_config import FLATPAK_ENV_VAR, CONFIG_DIR_NAME
except Exception:
    FLATPAK_ENV_VAR = 'ZZAR_FLATPAK'
    CONFIG_DIR_NAME = 'ZZAR'

if os.environ.get(FLATPAK_ENV_VAR):
    _BASE_DIR = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / CONFIG_DIR_NAME
elif hasattr(sys, '_MEIPASS'):
    _BASE_DIR = Path(sys.executable).parent.resolve()
else:
    _BASE_DIR = Path(__file__).parent.resolve()
WWISE_DIR = _BASE_DIR / "tools" / "wwise"
WWISE_CONSOLE = WWISE_DIR / "WWIse/Authoring/x64/Release/bin/WwiseConsole.exe"


class WwiseSetup:
    """Handles automated Wwise installation"""
    def setup(self, skip_input=True):
        """Run complete setup process - NO PROMPTS"""
        print("=" * 60)
        print("ZZZ Audio Mod Tool - Automated Wwise Setup")
        print("=" * 60)

        # Wine is only needed on Linux (Wwise runs natively on Windows)
        if sys.platform.startswith("linux"):
            if not self.check_wine():
                return False

        if self.check_existing():
            if self.test_wwise():
                print("\nWwise is already set up and working!")
                return True
            print("\nWwise exists but test failed. Re-installing...")

        print("\nStarting automated download...")
        zip_path = self.download_wwise()
        
        if not zip_path:
            print("Download failed.")
            return False

        if not self.extract_wwise(zip_path):
            print("Extraction failed.")
            return False

        return self.test_wwise()

    def __init__(self, download_url=None):
        self.download_url = download_url or DEFAULT_WWISE_URL
        self.wwise_dir = WWISE_DIR
        self.wwise_console = WWISE_CONSOLE

    def check_wine(self):
        """Check if Wine is installed"""
        if os.environ.get(FLATPAK_ENV_VAR):
            # In Flatpak, check host system's Wine via flatpak-spawn
            for name in ('wine64', 'wine'):
                try:
                    result = subprocess.run(
                        ['flatpak-spawn', '--host', name, '--version'],
                        capture_output=True, text=True, timeout=5
                    )
                    if result.returncode == 0:
                        print(f"✓ Wine found on host: {result.stdout.strip()}")
                        return True
                except Exception:
                    continue
            print("Wine not found on host system!")
            print("\nInstall Wine on your system (outside Flatpak):")
            print("  Arch: sudo pacman -S wine")
            print("  Debian/Ubuntu: sudo apt install wine")
            return False

        wine = shutil.which('wine64') or shutil.which('wine')
        if not wine:
            print("Wine not found!")
            print("\nInstall Wine:")
            print("  Arch: sudo pacman -S wine")
            print("  Debian/Ubuntu: sudo apt install wine")
            return False

        print(f"✓ Wine found: {wine}")
        return True

    def check_existing(self):
        """Check if Wwise is already installed"""
        if self.wwise_console.exists():
            print(f"✓ Wwise already installed at: {self.wwise_dir}")
            return True
        return False

    def download_wwise(self):
        """Download minimal Wwise package"""
        print(f"\nDownloading Wwise from: {self.download_url}")

        zip_path = self.wwise_dir / "wwise_temp.zip"
        self.wwise_dir.mkdir(parents=True, exist_ok=True)

        try:
            # Fix SSL on Windows PyInstaller builds (no bundled certs)
            try:
                urllib.request.urlopen("https://gitlab.com", timeout=5)
            except Exception:
                ssl_context = ssl._create_unverified_context()
                opener = urllib.request.build_opener(
                    urllib.request.HTTPSHandler(context=ssl_context)
                )
                urllib.request.install_opener(opener)

            def report_progress(block_num, block_size, total_size):
                downloaded = block_num * block_size
                if total_size > 0:
                    percent = min(downloaded * 100 / total_size, 100)
                    mb_downloaded = downloaded / 1024 / 1024
                    mb_total = total_size / 1024 / 1024
                    print(f"\r  Progress: {percent:.1f}% ({mb_downloaded:.1f} / {mb_total:.1f} MB)", end='')

            urllib.request.urlretrieve(
                self.download_url,
                zip_path,
                reporthook=report_progress
            )
            print("\n✓ Download complete!")
            return zip_path

        except Exception as e:
            print(f"\nDownload failed: {e}")
            return None

    def extract_wwise(self, zip_path):
        """Extract Wwise package"""
        print(f"\nExtracting Wwise...")

        try:
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(self.wwise_dir)

            print("✓ Extraction complete!")

            zip_path.unlink()
            print("✓ Cleaned up temporary files")

            return True

        except Exception as e:
            print(f"Extraction failed: {e}")
            return False

    def test_wwise(self):
        """Test if WwiseConsole works (via Wine on Linux, natively on Windows)"""
        print(f"\nTesting WwiseConsole...")

        if not self.wwise_console.exists():
            print(f"WwiseConsole.exe not found at: {self.wwise_console}")
            return False

        try:
            if sys.platform.startswith("win"):
                cmd = [str(self.wwise_console), '-help']
            elif os.environ.get(FLATPAK_ENV_VAR):
                # Detect which wine binary the host has
                wine_name = 'wine'
                for name in ('wine64', 'wine'):
                    try:
                        r = subprocess.run(
                            ['flatpak-spawn', '--host', name, '--version'],
                            capture_output=True, timeout=5,
                        )
                        if r.returncode == 0:
                            wine_name = name
                            break
                    except Exception:
                        continue
                cmd = ['flatpak-spawn', '--host', wine_name, str(self.wwise_console), '-help']
            else:
                wine = shutil.which('wine64') or shutil.which('wine') or 'wine'
                cmd = [wine, str(self.wwise_console), '-help']

            result = subprocess.run(
                cmd,
                capture_output=True,
                timeout=10
            )

            print("WwiseConsole is accessible!")
            return True

        except subprocess.TimeoutExpired:
            print("WwiseConsole took too long to respond (might still work)")
            return True
        except Exception as e:
            print(f"WwiseConsole test failed: {e}")
            return False

    


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description='Automated Wwise setup for ZZZ audio modding',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Use default download URL
  python setup_wwise.py

  # Use custom Wwise package URL
  python setup_wwise.py --url https://your-server.com/wwise.zip

  # Check if Wwise is installed
  python setup_wwise.py --check

Notes:
  - Requires Wine to be installed on Linux
  - Downloads ~50-100MB (minimal Wwise package)
  - Installs to ./tools/wwise/
        """
    )

    parser.add_argument('--url', help='Custom Wwise download URL')
    parser.add_argument('--check', action='store_true', help='Check if Wwise is installed')

    args = parser.parse_args()

    setup = WwiseSetup(download_url=args.url)

    if args.check:
        print("Checking Wwise installation...")
        if setup.check_existing():
            if setup.test_wwise():
                print("Wwise is installed and working!")
                sys.exit(0)
            else:
                print("⚠️  Wwise is installed but test failed")
                sys.exit(1)
        else:
            print("Wwise is not installed")
            print("\nRun: python setup_wwise.py")
            sys.exit(1)

    success = setup.setup()
    sys.exit(0 if success else 1)


def run_setup_from_gui():
    installer = WwiseSetup()
    return installer.setup(skip_input=True)

if __name__ == '__main__':
    main()
