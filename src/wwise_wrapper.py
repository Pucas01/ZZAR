

import subprocess
import shutil
import tempfile
import os
import sys
import platform
from pathlib import Path

_is_windows = platform.system() == "Windows"
_subprocess_kwargs = {"creationflags": subprocess.CREATE_NO_WINDOW} if _is_windows else {}

if os.environ.get('ZZAR_FLATPAK'):
    _BASE_DIR = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / 'ZZAR'
elif hasattr(sys, '_MEIPASS'):
    _BASE_DIR = Path(sys.executable).parent.resolve()
else:
    _BASE_DIR = Path(__file__).resolve().parent.parent

# Resources: the bundled template lives inside _MEIPASS (read-only in PyInstaller).
# For writable operations (mkdir, cache), copy to a persistent writable location.
_BUNDLED_RESOURCE_DIR = Path(__file__).resolve().parent / "resources"

if os.environ.get('ZZAR_FLATPAK') or hasattr(sys, '_MEIPASS'):
    _RESOURCE_DIR = _BASE_DIR / "resources"
    _wproj = _RESOURCE_DIR / "WAVtoWEM" / "WAVtoWEM.wproj"
    if not _wproj.exists() and (_BUNDLED_RESOURCE_DIR / "WAVtoWEM" / "WAVtoWEM.wproj").exists():
        shutil.copytree(
            str(_BUNDLED_RESOURCE_DIR / "WAVtoWEM"),
            str(_RESOURCE_DIR / "WAVtoWEM"),
            dirs_exist_ok=True,
        )
else:
    _RESOURCE_DIR = _BUNDLED_RESOURCE_DIR

class WwiseConsole:


    def __init__(self, wwise_dir=None, project_path=None):

        if wwise_dir is None:
            wwise_dir = _BASE_DIR / "tools" / "wwise"
        else:
            wwise_dir = Path(wwise_dir)

        self.wwise_dir = wwise_dir.resolve()

        self.wwise_console = _BASE_DIR / "tools/wwise/WWIse/Authoring/x64/Release/bin/WwiseConsole.exe"
        self.is_windows = platform.system() == "Windows"
        if self.is_windows:
            self.wine_cmd = None
        elif os.environ.get('ZZAR_FLATPAK'):
            # In Flatpak, call the host system's Wine via flatpak-spawn
            self.wine_cmd = self._detect_host_wine()
        else:
            wine = shutil.which('wine64') or shutil.which('wine')
            self.wine_cmd = [wine] if wine else None

        if project_path is None:
            self.project_path = _RESOURCE_DIR / "WAVtoWEM" / "WAVtoWEM.wproj"
        else:
            self.project_path = Path(project_path)

        self.project_path = self.project_path.resolve()

        self._ensure_project_structure()

    @staticmethod
    def _detect_host_wine():
        for name in ('wine64', 'wine'):
            try:
                result = subprocess.run(
                    ['flatpak-spawn', '--host', name, '--version'],
                    capture_output=True, timeout=5,
                )
                if result.returncode == 0:
                    return ['flatpak-spawn', '--host', name]
            except Exception:
                continue
        return None

    def is_installed(self):

        if self.is_windows:
            return self.wwise_console.exists()
        else:
            return self.wwise_console.exists() and self.wine_cmd is not None

    def _ensure_project_structure(self):

        if not self.project_path.exists():
            return

        project_root = self.project_path.parent
        required_dirs = [
            "GeneratedSoundBanks", 
            "Originals", 
            "Attenuations", 
            "Conversion Settings", 
            "Actor-Mixer Hierarchy"
        ]

        for d in required_dirs:
            folder = project_root / d
            if not folder.exists():
                folder.mkdir(parents=True, exist_ok=True)

    def _migrate_project(self):

        print("Running one-time project migration...")
        try:
            if self.is_windows:
                cmd = [str(self.wwise_console), "migrate", str(self.project_path)]
            else:
                cmd = self.wine_cmd + [str(self.wwise_console), "migrate", str(self.project_path)]

            subprocess.run(cmd, capture_output=True, check=False, **_subprocess_kwargs)
        except Exception as e:
            print(f"Migration warning: {e}")

    def _cleanup_wwise_artifacts(self, output_dir):
        output_dir = Path(output_dir)
        wsources = output_dir / "list.wsources"
        if wsources.exists():
            wsources.unlink()
        windows_dir = output_dir / "Windows"
        if windows_dir.exists() and windows_dir.is_dir():
            shutil.rmtree(windows_dir)

    def _create_wsources_file(self, wav_files, wav_dir, output_path):

        import xml.etree.ElementTree as ET

        wav_dir_path = Path(wav_dir).resolve()

        if self.is_windows:
            root_path = str(wav_dir_path)
        else:
            root_path = "Z:" + str(wav_dir_path).replace('/', '\\')

        root = ET.Element("ExternalSourcesList", {
            "SchemaVersion": "1",
            "Root": root_path
        })

        for wav_file in wav_files:
            wav_path = Path(wav_file).resolve()

            filename = wav_path.name
            ET.SubElement(root, "Source", {
                "Path": filename,
                "Conversion": "Vorbis Quality High"
            })

        tree = ET.ElementTree(root)
        wsources_path = output_path / "list.wsources"
        tree.write(wsources_path, encoding="utf-8", xml_declaration=True)
        return wsources_path

    def convert_to_wem(self, wav_file, output_dir=None):

        wav_file = Path(wav_file).resolve()

        if output_dir is None:
            output_dir = wav_file.parent
        output_dir = Path(output_dir).resolve()
        output_dir.mkdir(exist_ok=True)

        wav_dir = wav_file.parent

        wsources_path = self._create_wsources_file([wav_file], wav_dir, output_dir)

        if self.is_windows:
            cmd = [
                str(self.wwise_console),
                "convert-external-source",
                str(self.project_path),
                "--source-file",
                str(wsources_path),
                "--output",
                str(output_dir)
            ]
        else:

            wsources_wine_path = "Z:" + str(wsources_path).replace('/', '\\')
            output_wine_path = "Z:" + str(output_dir).replace('/', '\\')
            cmd = self.wine_cmd + [
                str(self.wwise_console),
                "convert-external-source",
                str(self.project_path),
                "--source-file",
                wsources_wine_path,
                "--output",
                output_wine_path
            ]

        print(f"[WwiseConsole] Running: {' '.join(cmd)}")
        process = subprocess.run(cmd, capture_output=True, text=True, **_subprocess_kwargs)

        if process.returncode != 0:
            error_detail = (process.stdout + process.stderr).strip()
            if not error_detail:
                error_detail = f"Wine/WwiseConsole exited with code {process.returncode}"
            raise RuntimeError(error_detail)

        if process.stdout:
            print("WwiseConsole output:", process.stdout)
        if process.stderr:
            print("WwiseConsole errors:", process.stderr)

        wem_file = output_dir / wav_file.with_suffix(".wem").name

        if not wem_file.exists():

            project_cache = self.project_path.parent / ".cache"
            if project_cache.exists():
                for p in project_cache.rglob("*.wem"):
                    print(f"Found WEM in cache: {p}")
                    shutil.copy(p, wem_file)
                    break

            for p in output_dir.rglob("*.wem"):
                if p.name == wem_file.name:
                    print(f"Found WEM in subdirectory: {p}")
                    shutil.copy(p, wem_file)
                    break

        if not wem_file.exists():
            raise RuntimeError(f"WEM file not created: {wem_file}")

        self._cleanup_wwise_artifacts(output_dir)

        return wem_file

    def batch_convert_to_wem(self, wav_files, output_dir):

        output_dir = Path(output_dir)
        output_dir.mkdir(exist_ok=True)

        converted = []
        failed = []

        print(f"\nProcessing {len(wav_files)} files...")

        wav_files_paths = [Path(f).resolve() for f in wav_files]
        wav_dir = wav_files_paths[0].parent

        if not all(f.parent == wav_dir for f in wav_files_paths):
            print("⚠️  Warning: WAV files are in different directories. Converting individually...")
            for wav in wav_files:
                try:
                    out = self.convert_to_wem(wav, output_dir)
                    converted.append(out)
                except Exception as e:
                    print(f"❌ Failed {Path(wav).name}: {e}")
                    failed.append(wav)
            return converted

        wsources_path = self._create_wsources_file(wav_files_paths, wav_dir, output_dir)

        if self.is_windows:
            cmd = [
                str(self.wwise_console),
                "convert-external-source",
                str(self.project_path),
                "--source-file",
                str(wsources_path),
                "--output",
                str(output_dir)
            ]
        else:

            wsources_wine_path = "Z:" + str(wsources_path).replace('/', '\\')
            output_wine_path = "Z:" + str(output_dir).replace('/', '\\')
            cmd = self.wine_cmd + [
                str(self.wwise_console),
                "convert-external-source",
                str(self.project_path),
                "--source-file",
                wsources_wine_path,
                "--output",
                output_wine_path
            ]

        process = subprocess.run(cmd, capture_output=True, text=True, **_subprocess_kwargs)

        if process.returncode != 0:
            print(f"❌ Batch conversion failed: {process.stdout + process.stderr}")

            for wav in wav_files:
                try:
                    out = self.convert_to_wem(wav, output_dir)
                    converted.append(out)
                except Exception as e:
                    print(f"❌ Failed {Path(wav).name}: {e}")
                    failed.append(wav)
        else:

            for wav in wav_files:
                wem_file = output_dir / Path(wav).with_suffix(".wem").name
                if wem_file.exists():
                    converted.append(wem_file)
                else:
                    failed.append(wav)

        self._cleanup_wwise_artifacts(output_dir)

        return converted

def main():
    if len(sys.argv) < 2:
        print("Usage: python wwise_wrapper.py <input.wav or folder> [output_folder]")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else None

    wwise = WwiseConsole()

    if input_path.is_file():
        wwise.convert_to_wem(input_path, output_path)
    elif input_path.is_dir():
        wavs = list(input_path.glob("*.wav"))
        if not output_path:
            output_path = input_path / "wem"
        wwise.batch_convert_to_wem(wavs, output_path)

if __name__ == "__main__":
    main()