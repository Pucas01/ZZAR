

from PyQt5.QtCore import QObject, pyqtSlot, pyqtSignal, pyqtProperty, QThread, QTimer
from PyQt5.QtQml import QQmlApplicationEngine
from pathlib import Path
import json
import os
import sys
import shutil
import subprocess

from src.mod_package_manager import ModPackageManager, InvalidModPackageError
from src.persistent_mod_manager import PersistentModManager
from src.config_manager import get_settings_file
from .native_dialogs import NativeDialogs

class WwiseSetupWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)

    def run(self):
        try:
            if hasattr(sys, '_MEIPASS'):

                import setup_wwise

                success = setup_wwise.run_setup_from_gui()

                if success:
                    self.finished.emit(True, "Wwise setup completed successfully!")
                else:
                    self.finished.emit(False, "Wwise setup failed or was cancelled.")
            else:

                cmd = [sys.executable, "setup_wwise.py"]
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    stdin=subprocess.PIPE,
                    cwd=str(Path.cwd()),
                )
                stdout, _ = process.communicate(input="y\n")

                if process.returncode == 0:
                    self.finished.emit(True, "Wwise setup completed successfully!")
                else:
                    self.finished.emit(False, f"Setup failed:\n{stdout}")

        except Exception as e:
            self.finished.emit(False, str(e))

class WindowsAudioToolsSetupWorker(QThread):

    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)

    def run(self):
        try:
            if hasattr(sys, '_MEIPASS'):

                import setup_windows_audio_tools
                success = setup_windows_audio_tools.run_setup_from_gui()

                if success:
                    self.finished.emit(True, "Windows audio tools setup completed successfully!")
                else:
                    self.finished.emit(False, "Audio tools setup failed.")
            else:

                cmd = [sys.executable, "setup_windows_audio_tools.py"]
                process = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    stdin=subprocess.DEVNULL,
                    text=True,
                    bufsize=1,
                    cwd=str(Path.cwd()),
                )

                output_lines = []
                try:
                    for line in iter(process.stdout.readline, ''):
                        if line:
                            line_stripped = line.rstrip()
                            output_lines.append(line_stripped)

                            print(f"[Audio Tools Setup] {line_stripped}")

                            self.progress.emit(line_stripped)

                    process.wait(timeout=600)
                except subprocess.TimeoutExpired:
                    process.kill()
                    print("[Audio Tools Setup] ERROR: Timed out after 10 minutes")
                    self.finished.emit(False, "Setup timed out after 10 minutes")
                    return

                if process.returncode == 0:
                    self.finished.emit(True, "Windows audio tools setup completed successfully!")
                else:

                    error_preview = '\n'.join(output_lines[-10:]) if len(output_lines) > 10 else '\n'.join(output_lines)
                    print(f"[Audio Tools Setup] ERROR: Process failed with code {process.returncode}")
                    print("[Audio Tools Setup] Full output:")
                    for line in output_lines:
                        print(f"  {line}")
                    self.finished.emit(False, f"Setup failed (see console for details):\n\n{error_preview}")

        except Exception as e:
            self.finished.emit(False, str(e))

class ModManagerBridge(QObject):


    modsLoaded = pyqtSignal(list, arguments=["modList"])
    modInstalled = pyqtSignal(str, arguments=["modUuid"])
    modRemoved = pyqtSignal(str, arguments=["modUuid"])
    progressUpdate = pyqtSignal(str, arguments=["message"])
    errorOccurred = pyqtSignal(str, str, arguments=["title", "message"])

    wwiseStatusChanged = pyqtSignal(bool, arguments=["installed"])
    modCreationModeChanged = pyqtSignal(bool, arguments=["enabled"])
    wwiseSetupSuccess = pyqtSignal(str, str, arguments=["title", "message"])
    wwiseSetupConfirmation = pyqtSignal(arguments=[])
    conflictsDetected = pyqtSignal(list, arguments=["conflicts"])
    modConflictsDetected = pyqtSignal(list, list, arguments=["modConflicts", "fileConflicts"])
    modInstallSuccess = pyqtSignal(str, str, str, arguments=["title", "message", "imagePath"])

    audioToolsStatusChanged = pyqtSignal(bool, arguments=["installed"])
    audioToolsSetupSuccess = pyqtSignal(str, str, arguments=["title", "message"])

    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings_file = get_settings_file()

        self.mod_creation_mode = False
        self.wwise_worker = None
        self.audio_tools_worker = None
        self.game_audio_dir = ""
        self.persistent_dir = ""
        self.conflict_preferences = {}

        self.persistent_mod_manager = PersistentModManager()
        self.mod_package_manager = ModPackageManager(
            persistent_mod_manager=self.persistent_mod_manager
        )

        self.load_settings()

    def load_settings(self):

        try:
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)
                    self.game_audio_dir = settings.get("game_audio_dir", "")
                    self.persistent_dir = settings.get("persistent_audio_dir", "")
                    self.mod_creation_mode = settings.get("mod_creation_mode", False)
                    self.conflict_preferences = settings.get("conflict_preferences", {})

                    custom_mods_dir = settings.get("custom_mod_library_dir", "")
                    from src.config_manager import set_mod_library_dir, get_mod_library_dir

                    old_mods_dir = self.mod_package_manager.mods_dir
                    set_mod_library_dir(custom_mods_dir if custom_mods_dir else None)
                    new_library = get_mod_library_dir()
                    new_mods_dir = new_library / 'mods'

                    if old_mods_dir != new_mods_dir and old_mods_dir.exists():
                        new_mods_dir.mkdir(parents=True, exist_ok=True)
                        for mod_dir in old_mods_dir.iterdir():
                            if mod_dir.is_dir():
                                dest = new_mods_dir / mod_dir.name
                                if not dest.exists():
                                    try:
                                        shutil.move(str(mod_dir), str(dest))
                                        print(f"[Mod Manager] Moved mod {mod_dir.name} to {dest}")
                                    except Exception as e:
                                        print(f"[Mod Manager] Warning: Failed to move {mod_dir.name}: {e}")

                    self.mod_package_manager = ModPackageManager(
                        mod_library_path=str(new_library),
                        persistent_mod_manager=self.persistent_mod_manager
                    )
                    print(f"[Mod Manager]   Mods dir: {new_library}")

                    if self.persistent_dir:
                        self.persistent_mod_manager.set_persistent_path(
                            self.persistent_dir
                        )

                    self.modCreationModeChanged.emit(self.mod_creation_mode)

                    if self.game_audio_dir or self.persistent_dir:
                        print(f"[Mod Manager] Loaded game directories from settings")
                        if self.game_audio_dir:
                            print(f"[Mod Manager]   Game audio: {self.game_audio_dir}")
                        if self.persistent_dir:
                            print(f"[Mod Manager]   Persistent: {self.persistent_dir}")
            else:
                print(
                    "[Mod Manager] No settings file found - please configure game directory in Settings"
                )
        except Exception as e:
            print(f"[Mod Manager] Warning: Failed to load settings: {e}")
            self.game_audio_dir = ""
            self.persistent_dir = ""

    @pyqtSlot(result=bool)
    def getModCreationMode(self):

        return self.mod_creation_mode

    @pyqtSlot(bool)
    def setModCreationMode(self, enabled):

        self.mod_creation_mode = enabled
        self.modCreationModeChanged.emit(enabled)

        try:
            settings = {}
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)

            settings["mod_creation_mode"] = enabled

            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)

            print(f"[Mod Manager] Mod creation mode set to: {enabled}")
        except Exception as e:
            print(f"Error saving mod creation mode: {e}")

    @pyqtSlot()
    def checkWwiseInstalled(self):

        if os.environ.get('ZZAR_FLATPAK'):
            base_dir = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / 'ZZAR'
        elif hasattr(sys, '_MEIPASS'):
            base_dir = Path(sys.executable).parent.resolve()
        else:
            base_dir = Path(".").resolve()
        wwise_console = base_dir / "tools" / "wwise" / "WWIse" / "Authoring" / "x64" / "Release" / "bin" / "WwiseConsole.exe"
        is_installed = wwise_console.exists()
        print(f"[Mod Manager] Wwise check path: {wwise_console}")
        print(f"[Mod Manager] Wwise installed: {is_installed}")
        self.wwiseStatusChanged.emit(is_installed)
        return is_installed

    @pyqtSlot()
    def runWwiseSetup(self):

        self.wwiseSetupConfirmation.emit()

    @pyqtSlot()
    def startWwiseSetup(self):

        if self.wwise_worker and self.wwise_worker.isRunning():
            return

        self.wwise_worker = WwiseSetupWorker()
        self.wwise_worker.progress.connect(lambda msg: self.progressUpdate.emit(msg))
        self.wwise_worker.finished.connect(self._on_wwise_setup_finished)
        self.wwise_worker.start()
        self.progressUpdate.emit("Starting Wwise setup...")

    def _on_wwise_setup_finished(self, success, message):

        if success:
            self.progressUpdate.emit("Wwise setup complete")
            self.checkWwiseInstalled()
            self.wwiseSetupSuccess.emit(
                "Wwise Setup Complete",
                "Wwise has been successfully downloaded and installed.\n\nYou can now use mod creation features."
            )
        else:
            self.errorOccurred.emit("Wwise Setup Failed", message)

    @pyqtSlot()
    def checkAudioToolsInstalled(self):

        import platform

        if platform.system() != "Windows":
            self.audioToolsStatusChanged.emit(False)
            return False

        if os.environ.get('ZZAR_FLATPAK'):
            base_dir = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / 'ZZAR'
        elif hasattr(sys, '_MEIPASS'):
            base_dir = Path(sys.executable).parent.resolve()
        else:
            base_dir = Path(__file__).parent.parent.parent.parent.resolve()
        ffmpeg_dir = base_dir / "tools" / "audio" / "ffmpeg"
        vgmstream_exe = base_dir / "tools" / "audio" / "vgmstream" / "vgmstream-cli.exe"

        print(f"[Mod Manager] Checking for tools in: {base_dir / 'tools' / 'audio'}")

        ffmpeg_found = False
        if ffmpeg_dir.exists():
            ffmpeg_candidates = list(ffmpeg_dir.rglob("ffmpeg.exe"))
            ffmpeg_found = len(ffmpeg_candidates) > 0
            if ffmpeg_found:
                print(f"[Mod Manager] Found ffmpeg at: {ffmpeg_candidates[0]}")

        vgmstream_found = vgmstream_exe.exists()
        if vgmstream_found:
            print(f"[Mod Manager] Found vgmstream at: {vgmstream_exe}")

        is_installed = ffmpeg_found and vgmstream_found
        print(f"[Mod Manager] Windows audio tools installed: {is_installed} (ffmpeg: {ffmpeg_found}, vgmstream: {vgmstream_found})")
        self.audioToolsStatusChanged.emit(is_installed)
        return is_installed

    @pyqtSlot()
    def runAudioToolsSetup(self):

        import platform

        if platform.system() != "Windows":
            self.errorOccurred.emit(
                "Platform Not Supported",
                "Automated audio tools installation is for Windows only.\n\n"
                "On Linux, install via package manager:\n"
                "  sudo pacman -S ffmpeg vgmstream-cli\n"
                "  sudo apt install ffmpeg vgmstream-cli"
            )
            return

        if self.audio_tools_worker and self.audio_tools_worker.isRunning():
            return

        self.audio_tools_worker = WindowsAudioToolsSetupWorker()
        self.audio_tools_worker.progress.connect(lambda msg: self.progressUpdate.emit(msg))
        self.audio_tools_worker.finished.connect(self._on_audio_tools_setup_finished)
        self.audio_tools_worker.start()
        self.progressUpdate.emit("Starting Windows audio tools setup...")

    def _on_audio_tools_setup_finished(self, success, message):

        print(f"[Mod Manager] Audio tools setup finished: success={success}")

        print("[Mod Manager] Emitting audioToolsStatusChanged to stop spinner")
        self.audioToolsStatusChanged.emit(False)

        QTimer.singleShot(500, self.checkAudioToolsInstalled)

        if success:
            self.progressUpdate.emit("Audio tools setup complete")
            self.audioToolsSetupSuccess.emit(
                "Audio Tools Setup Complete",
                "FFmpeg and vgmstream have been successfully downloaded and installed.\n\n"
                "You can now convert audio files for modding."
            )
        else:
            self.errorOccurred.emit("Audio Tools Setup Failed", message)

    @pyqtSlot(result=list)
    def getInstalledMods(self):

        try:
            mods = self.mod_package_manager.get_installed_mods()
            print(f"[Mod Manager] Found {len(mods)} installed mod(s)")

            qml_mods = []
            for mod in mods:
                metadata = mod["metadata"]
                qml_mod = {
                    "uuid": mod["uuid"],
                    "name": metadata.get("name", "Unknown"),
                    "version": metadata.get("version", "1.0.0"),
                    "author": metadata.get("author", "Unknown"),
                    "description": metadata.get("description", ""),
                    "enabled": mod["enabled"],
                    "priority": mod["priority"],
                    "thumbnailPath": Path(mod["thumbnail_path"]).as_uri()
                    if mod["thumbnail_path"]
                    else "",
                    "installDate": mod.get("install_date", ""),
                    "fromGameBanana": bool(metadata.get("gamebanana_id") or metadata.get("gamebanana_download_url")),
                }
                qml_mods.append(qml_mod)
                status = "ENABLED" if mod["enabled"] else "disabled"
                print(
                    f"[Mod Manager]   [{status}] {qml_mod['name']} v{qml_mod['version']} by {qml_mod['author']}"
                )

            return qml_mods
        except Exception as e:
            print(f"[Mod Manager] ERROR getting mods: {e}")
            return []

    @pyqtSlot(str, bool)
    def setModEnabled(self, mod_uuid, enabled):

        try:
            self.mod_package_manager.set_mod_enabled(mod_uuid, enabled)
            state = "enabled" if enabled else "disabled"
            print(f"[Mod Manager] Mod {state}: {mod_uuid}")
            self.progressUpdate.emit(f"Mod {state}")
        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to toggle mod: {str(e)}")
            self.errorOccurred.emit("Error", f"Failed to toggle mod: {str(e)}")

    @pyqtSlot(str)
    def installMod(self, file_path):

        try:
            print(f"[Mod Manager] Validating mod package: {Path(file_path).name}")

            metadata = self.mod_package_manager.validate_mod_package(file_path)

            print(f"[Mod Manager] Package valid:")
            print(f"[Mod Manager]   Name: {metadata['name']}")
            print(f"[Mod Manager]   Author: {metadata.get('author', 'Unknown')}")
            print(f"[Mod Manager]   Version: {metadata.get('version', '1.0.0')}")
            print(f"[Mod Manager]   Description: {metadata.get('description', 'N/A')}")

            replacement_count = sum(
                len(files) for files in metadata.get("replacements", {}).values()
            )
            pck_count = len(metadata.get("replacements", {}))
            print(
                f"[Mod Manager]   Replaces {replacement_count} file(s) in {pck_count} PCK(s)"
            )

            print(f"[Mod Manager] Installing mod: {metadata['name']}")
            install_result = self.mod_package_manager.install_mod(file_path)

            if install_result is None:

                print(f"[Mod Manager] Installation skipped: newer version already installed")
                self.errorOccurred.emit(
                    "Installation Skipped",
                    f"A newer version of '{metadata['name']}' is already installed."
                )
                return

            mod_uuid = install_result['uuid']
            mod_name = install_result['mod_name']
            version = install_result['version']
            replaced = install_result['replaced']

            if replaced:
                print(f"[Mod Manager] Replaced existing mod with v{version}")
                self.progressUpdate.emit(f"Updated: {mod_name} to v{version}")

                self.modInstallSuccess.emit(
                    "Mod Updated Successfully",
                    f"Updated to latest version:\n\n"
                    f"Name: {mod_name}\n"
                    f"Version: {version}\n\n"
                    f"Enable the mod and click 'Apply Mods' to use it.",
                    ""
                )
            else:
                print(f"[Mod Manager] Installed successfully! UUID: {mod_uuid}")
                self.progressUpdate.emit(f"Installed: {mod_name} v{version}")

                self.modInstallSuccess.emit(
                    "Mod Installed Successfully",
                    f"Successfully installed:\n\n"
                    f"Name: {mod_name}\n"
                    f"Version: {version}\n\n"
                    f"Enable the mod and click 'Apply Mods' to use it.",
                    ""
                )

            self.modInstalled.emit(mod_uuid)

            self.refreshMods()

        except InvalidModPackageError as e:
            print(f"[Mod Manager] ERROR: Invalid mod package: {str(e)}")
            self.errorOccurred.emit("Invalid Mod Package", str(e))
        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to install mod: {str(e)}")
            self.errorOccurred.emit("Error", f"Failed to install mod: {str(e)}")

    @pyqtSlot(str)
    def removeMod(self, mod_uuid):

        try:
            print(f"[Mod Manager] Removing mod: {mod_uuid}")
            self.mod_package_manager.remove_mod(mod_uuid)
            print(f"[Mod Manager] Mod removed successfully")
            self.progressUpdate.emit("Mod removed")
            self.modRemoved.emit(mod_uuid)
            self.refreshMods()
        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to remove mod: {str(e)}")
            self.errorOccurred.emit("Error", f"Failed to remove mod: {str(e)}")

    @pyqtSlot(list)
    def removeMods(self, mod_uuids):

        errors = []
        removed = 0
        for mod_uuid in mod_uuids:
            try:
                print(f"[Mod Manager] Removing mod: {mod_uuid}")
                self.mod_package_manager.remove_mod(mod_uuid)
                self.modRemoved.emit(mod_uuid)
                removed += 1
            except Exception as e:
                print(f"[Mod Manager] ERROR: Failed to remove mod {mod_uuid}: {str(e)}")
                errors.append(str(e))

        if removed > 0:
            self.progressUpdate.emit(f"{removed} mod(s) removed")
            self.refreshMods()

        if errors:
            self.errorOccurred.emit("Error", f"Failed to remove some mods: {'; '.join(errors)}")

    @pyqtSlot()
    def refreshMods(self):

        print("[Mod Manager] Refreshing mod list...")
        self.mod_package_manager.load_config()
        mods = self.getInstalledMods()
        self.modsLoaded.emit(mods)
        print(f"[Mod Manager] Loaded {len(mods)} mod(s)")

    @pyqtSlot(str)
    def saveConflictPreferences(self, preferences_json):

        try:
            preferences = json.loads(preferences_json)
        except (json.JSONDecodeError, TypeError) as e:
            print(f"[Mod Manager] ERROR: Failed to parse conflict preferences: {e}")
            return

        print(f"[Mod Manager] Saving {len(preferences)} conflict preferences")

        for pref in preferences:
            key = f"{pref['pck']}:{pref['file_id']}"
            self.conflict_preferences[key] = pref['winner_mod']
            print(f"[Mod Manager]   {key} -> {pref['winner_mod']}")

        try:
            settings = {}
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)

            settings["conflict_preferences"] = self.conflict_preferences

            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)

            print("[Mod Manager] Conflict preferences saved to settings")
        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to save conflict preferences: {e}")

    @pyqtSlot()
    def applyModsAfterConflictResolution(self):

        self._apply_mods_internal()

    @pyqtSlot()
    def applyMods(self):

        print("[Mod Manager] Starting mod application...")

        if not self.game_audio_dir or not Path(self.game_audio_dir).exists():
            print("[Mod Manager] ERROR: Game audio directory not set or doesn't exist")
            self.errorOccurred.emit(
                "Missing Directory",
                "Game audio directory not set. Please configure it in settings first.",
            )
            return

        if not self.persistent_dir:
            print("[Mod Manager] ERROR: Persistent audio directory not set")
            self.errorOccurred.emit(
                "Missing Directory",
                "Persistent audio directory not set. Please configure it in settings first.",
            )
            return

        try:

            mods = self.mod_package_manager.get_installed_mods()
            enabled_mods = [m for m in mods if m["enabled"]]
            print(
                f"[Mod Manager] Found {len(enabled_mods)} enabled mod(s) out of {len(mods)} total"
            )

            if not enabled_mods:
                print("[Mod Manager] No mods enabled, will clean up modded PCK files...")

            conflicts = self.mod_package_manager.get_mod_conflicts_summary()
            if conflicts["conflicts"]:
                conflict_count = len(conflicts["conflicts"])
                print(f"[Mod Manager] Warning: {conflict_count} conflict(s) detected")
                for conflict in conflicts["conflicts"][:5]:
                    print(f"[Mod Manager]   - {conflict}")

                conflicts_with_prefs = []
                for conflict in conflicts["conflicts"]:
                    conflict_key = f"{conflict['pck']}:{conflict['file_id']}"
                    saved_winner = self.conflict_preferences.get(conflict_key)

                    if saved_winner and saved_winner != conflict['winner_mod']:

                        if saved_winner in conflict['loser_mods']:
                            print(f"[Mod Manager] Restoring saved preference for {conflict_key}: {saved_winner}")
                            old_winner = conflict['winner_mod']
                            conflict['loser_mods'].remove(saved_winner)
                            conflict['loser_mods'].append(old_winner)
                            conflict['winner_mod'] = saved_winner
                            conflict['saved_preference'] = saved_winner
                        else:

                            print(f"[Mod Manager] Saved preference '{saved_winner}' no longer available for {conflict_key}, ignoring")
                            conflict['saved_preference'] = None
                    elif saved_winner:
                        conflict['saved_preference'] = saved_winner
                    else:
                        conflict['saved_preference'] = None

                    conflicts_with_prefs.append(conflict)

                if self.mod_creation_mode:
                    self.conflictsDetected.emit(conflicts_with_prefs)
                else:
                    mod_conflicts = conflicts.get('mod_conflicts', [])
                    for mc in mod_conflicts:
                        first_file = mc['files'][0] if mc['files'] else {}
                        first_key = f"{first_file.get('pck', '')}:{first_file.get('file_id', '')}"
                        saved = self.conflict_preferences.get(first_key)
                        if saved and saved in mc['mods']:
                            mc['winner_mod'] = saved
                    self.modConflictsDetected.emit(mod_conflicts, conflicts_with_prefs)

                return
            else:
                print("[Mod Manager] No conflicts detected")
                self.progressUpdate.emit("Applying mods...")

            self._apply_mods_internal()

        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to apply mods: {str(e)}")
            self.errorOccurred.emit("Error", f"Failed to apply mods: {str(e)}")

    def _apply_mods_internal(self):

        try:

            if self.persistent_dir:
                try:
                    persistent_path = Path(self.persistent_dir)

                    if persistent_path.exists():
                        self.progressUpdate.emit("Cleaning up old PCK files...")

                        lang_folders_to_skip = set()
                        for lang_folder in persistent_path.iterdir():
                            if lang_folder.is_dir():
                                pck_count = len(list(lang_folder.glob("*.pck")))
                                if pck_count == 57:
                                    lang_folders_to_skip.add(lang_folder)
                                    print(f"[Mod Manager] Skipping language folder {lang_folder.name} (has 57 PCK files)")

                        PROTECTED_PCKS = {'Patch.pck', 'Hotfix.pck'}

                        cleaned_files = 0
                        for pck_file in persistent_path.rglob("*.pck"):

                            if any(lang_folder in pck_file.parents for lang_folder in lang_folders_to_skip):
                                continue

                            if pck_file.name in PROTECTED_PCKS:
                                print(f"[Mod Manager] Skipping protected file: {pck_file.name}")
                                continue

                            try:
                                pck_file.chmod(0o644)
                                pck_file.unlink()
                                cleaned_files += 1
                            except Exception as e:
                                print(f"[Mod Manager] Failed to delete {pck_file}: {e}")

                        if cleaned_files > 0:
                            print(f"[Mod Manager] Cleaned up {cleaned_files} old PCK file(s) from Persistent folder")
                except Exception as e:
                    print(f"[Mod Manager] Warning: Failed to clean up Persistent folder: {e}")

            self.progressUpdate.emit("Applying mods...")

            def progress_callback(message, current, total):
                print(f"[Mod Manager] [{current}/{total}] {message}")
                self.progressUpdate.emit(f"[{current}/{total}] {message}")

            self.mod_package_manager.apply_mods(
                self.game_audio_dir,
                self.persistent_dir,
                progress_callback,
                conflict_preferences=self.conflict_preferences
            )

            print("[Mod Manager] Mods applied successfully!")
            self.progressUpdate.emit("Mods applied successfully!")

        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to apply mods: {str(e)}")
            self.errorOccurred.emit("Error", f"Failed to apply mods: {str(e)}")

    @pyqtSlot(result=str)
    def getModLibraryPath(self):

        return str(self.mod_package_manager.mod_library_path)

    @pyqtSlot(str, result="QVariant")
    def getModInfo(self, mod_uuid):

        try:

            if mod_uuid not in self.mod_package_manager.mod_config.get(
                "installed_mods", {}
            ):
                print(f"[Mod Manager] Mod not found: {mod_uuid}")
                return None

            mod_info = self.mod_package_manager.mod_config["installed_mods"][mod_uuid]
            metadata = mod_info.get("metadata", {})
            replacements = metadata.get("replacements", {})

            file_count = 0
            for pck_name, pck_files in replacements.items():
                file_count += len(pck_files)

            thumbnail_path = ""
            if metadata.get("thumbnail"):
                mod_dir = self.mod_package_manager.mods_dir / mod_uuid
                thumb_file = mod_dir / metadata["thumbnail"]
                if thumb_file.exists():
                    thumbnail_path = thumb_file.as_uri()

            return {
                "uuid": mod_uuid,
                "name": metadata.get("name", "Unknown"),
                "author": metadata.get("author", "Unknown"),
                "version": metadata.get("version", "1.0.0"),
                "description": metadata.get("description", ""),
                "thumbnailPath": thumbnail_path,
                "createdDate": metadata.get(
                    "created_date", mod_info.get("install_date", "")
                ),
                "fileCount": file_count,
                "replacements": replacements,
                "gamebananaUrl": (
                    f"https://gamebanana.com/mods/{metadata['gamebanana_id']}"
                    if metadata.get("gamebanana_id")
                    else metadata.get("gamebanana_download_url", "")
                ),
            }

        except Exception as e:
            print(f"[Mod Manager] ERROR getting mod info: {e}")
            import traceback

            traceback.print_exc()
            return None

    @pyqtSlot(str)
    def playSound(self, path):
        try:
            from urllib.request import url2pathname
            from urllib.parse import urlparse
            parsed = urlparse(path)
            if parsed.scheme == 'file':
                path = url2pathname(parsed.path)
                if sys.platform.startswith('win') and path.startswith('/'):
                    path = path[1:]
            if sys.platform.startswith('win'):
                import winsound
                winsound.PlaySound(path, winsound.SND_FILENAME | winsound.SND_ASYNC)
            else:
                subprocess.Popen(['aplay', '-q', path],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"[playSound] ERROR: {e}")

    @pyqtSlot(str, result=list)
    def browseImportFiles(self, mode):


        if "pck" in mode:
            filter_str = "PCK Files (*.pck);;All Files (*)"
            title = "Select PCK File(s)"
        else:
            filter_str = "WEM Files (*.wem);;All Files (*)"
            title = "Select WEM File(s)"

        filenames = NativeDialogs.get_open_files(title, str(Path.home()), filter_str)

        if filenames:
            print(f"[Import Wizard] Selected {len(filenames)} file(s)")
            return [Path(f).name for f in filenames]
        return []

    @pyqtSlot(str, result=list)
    def browseImportFolder(self, mode):


        dirname = NativeDialogs.get_directory("Select Folder", str(Path.home()))

        if dirname:
            folder_path = Path(dirname)
            print(f"[Import Wizard] Selected folder: {folder_path}")

            folder_path_lower = str(folder_path).lower()
            use_recursive = (
                "soundbank" in folder_path_lower or "streaming" in folder_path_lower
            )

            if not use_recursive:
                for subdir in folder_path.iterdir():
                    if subdir.is_dir():
                        subdir_name_lower = subdir.name.lower()
                        if (
                            "soundbank" in subdir_name_lower
                            or "streaming" in subdir_name_lower
                        ):
                            use_recursive = True
                            break

            if "pck" in mode:
                if use_recursive:
                    files = list(folder_path.rglob("*.pck"))
                else:
                    files = list(folder_path.glob("*.pck"))
            else:
                if use_recursive:
                    files = list(folder_path.rglob("*.wem"))
                else:
                    files = list(folder_path.glob("*.wem"))

            file_names = []
            for path in files:
                if use_recursive:
                    file_names.append(str(path.relative_to(folder_path)))
                else:
                    file_names.append(path.name)

            print(f"[Import Wizard] Found {len(file_names)} file(s) in folder")
            return file_names

        return []

    @pyqtSlot(result=str)
    def browseImportThumbnail(self):


        filename = NativeDialogs.get_open_file(
            "Select Thumbnail Image",
            str(Path.home()),
            "Images (*.png *.jpg *.jpeg *.bmp);;All Files (*)",
        )

        if filename:
            print(f"[Import Wizard] Selected thumbnail: {filename}")
            return filename
        return ""

    @pyqtSlot(str, result=str)
    def getDetectedFilesSummary(self, mode):


        return ""

    @pyqtSlot(str, result=str)
    def askSavePath(self, mod_name):


        default_name = mod_name.replace(" ", "_") + ".zzar"
        save_path = NativeDialogs.get_save_file(
            "Save .zzar Mod Package",
            str(Path.home() / default_name),
            "ZZAR Mod Packages (*.zzar);;All Files (*)",
        )

        return save_path if save_path else ""

    @pyqtSlot(str)
    def exportMod(self, mod_uuid):

        try:
            print(f"[Mod Manager] Exporting mod: {mod_uuid}")

            installed_mods = self.mod_package_manager.get_installed_mods()
            mod_info = None
            for mod in installed_mods:
                if mod['uuid'] == mod_uuid:
                    mod_info = mod
                    break

            if not mod_info:
                print(f"[Mod Manager] ERROR: Mod {mod_uuid} not found in installed mods")
                self.errorOccurred.emit("Error", "Mod not found")
                return

            metadata = mod_info['metadata']
            mod_name = metadata.get('name', 'Unknown')
            mod_version = metadata.get('version', '1.0.0')

            default_name = mod_name.replace(" ", "_") + "_v" + mod_version + ".zzar"
            save_path = NativeDialogs.get_save_file(
                "Export Mod as .zzar",
                str(Path.home() / default_name),
                "ZZAR Mod Packages (*.zzar);;All Files (*)",
            )

            if not save_path:
                print("[Mod Manager] Export cancelled by user")
                return

            mod_dir = self.mod_package_manager.mods_dir / mod_uuid
            if not mod_dir.exists():
                self.errorOccurred.emit("Error", "Mod files not found")
                return

            metadata_path = mod_dir / 'metadata.json'
            if not metadata_path.exists():
                self.errorOccurred.emit("Error", "Mod metadata not found")
                return

            with open(metadata_path, 'r') as f:
                full_metadata = json.load(f)

            thumbnail_path = None
            if 'thumbnail' in full_metadata:
                thumbnail_file = mod_dir / full_metadata['thumbnail']
                if thumbnail_file.exists():
                    thumbnail_path = str(thumbnail_file)

            wem_dir = mod_dir / 'wem_files'
            if not wem_dir.exists():
                self.errorOccurred.emit("Error", "Mod audio files not found")
                return

            current_replacements = {}
            for pck_name, files in full_metadata.get('replacements', {}).items():
                current_replacements[pck_name] = {}
                for file_id, file_info in files.items():
                    wem_file = wem_dir / f"{file_id}.wem"
                    if wem_file.exists():
                        current_replacements[pck_name][file_id] = {
                            'wem_path': str(wem_file),
                            'sound_name': file_info.get('sound_name', ''),
                            'lang_id': file_info.get('lang_id', 0),
                            'bnk_id': file_info.get('bnk_id'),
                            'file_type': file_info.get('file_type', 'wem')
                        }

            export_metadata = {
                'name': full_metadata.get('name', 'Unknown'),
                'author': full_metadata.get('author', 'Unknown'),
                'version': full_metadata.get('version', '1.0.0'),
                'description': full_metadata.get('description', '')
            }

            self.progressUpdate.emit(f"Exporting {mod_name}...")
            self.mod_package_manager.create_mod_package(
                save_path,
                export_metadata,
                current_replacements,
                thumbnail_path
            )

            print(f"[Mod Manager] Mod exported successfully to: {save_path}")
            self.progressUpdate.emit(f"Mod exported to {Path(save_path).name}")

        except Exception as e:
            print(f"[Mod Manager] ERROR: Failed to export mod: {str(e)}")
            import traceback
            traceback.print_exc()
            self.errorOccurred.emit("Export Error", f"Failed to export mod: {str(e)}")
