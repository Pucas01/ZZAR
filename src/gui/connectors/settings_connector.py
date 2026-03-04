from PyQt5.QtCore import QCoreApplication
import json
import platform
from pathlib import Path

from PyQt5.QtCore import QObject, QMetaObject, Q_ARG, Qt
from PyQt5.QtWidgets import QApplication

from gui.backend.native_dialogs import NativeDialogs


class SettingsConnector:

    def _connect_settings(self):
        self.settings_page = self.root.findChild(QObject, "settingsPage")
        if not self.settings_page:
            return

        self.settings_page.browseGameDirClicked.connect(self.on_browse_game_dir)
        self.settings_page.autoDetectClicked.connect(self.on_auto_detect)
        self.settings_page.browseModsDirClicked.connect(self.on_browse_mods_dir)
        self.settings_page.resetModsDirClicked.connect(self.on_reset_mods_dir)
        self.settings_page.saveSettingsClicked.connect(self.on_save_settings)

        self.settings_page.modCreationModeToggled.connect(
            self.mod_manager_bridge.setModCreationMode
        )
        self.settings_page.checkWwiseClicked.connect(
            self.mod_manager_bridge.checkWwiseInstalled
        )
        self.settings_page.runWwiseSetupClicked.connect(
            self.mod_manager_bridge.runWwiseSetup
        )
        self.settings_page.checkAudioToolsClicked.connect(
            self.mod_manager_bridge.checkAudioToolsInstalled
        )
        self.settings_page.runAudioToolsSetupClicked.connect(
            self.mod_manager_bridge.runAudioToolsSetup
        )
        self.settings_page.languageChanged.connect(self.on_language_changed)

        self.mod_manager_bridge.modCreationModeChanged.connect(
            self.on_mod_creation_mode_changed
        )
        self.mod_manager_bridge.wwiseStatusChanged.connect(
            self.on_wwise_status_changed
        )
        self.mod_manager_bridge.wwiseSetupConfirmation.connect(
            self.on_wwise_setup_confirmation
        )
        self.mod_manager_bridge.wwiseSetupSuccess.connect(
            self.on_wwise_setup_success
        )
        self.mod_manager_bridge.audioToolsStatusChanged.connect(
            self.on_audio_tools_status_changed
        )
        self.mod_manager_bridge.audioToolsSetupSuccess.connect(
            self.on_audio_tools_setup_success
        )
        self.mod_manager_bridge.modInstallSuccess.connect(
            self.on_mod_install_success
        )
        self.mod_manager_bridge.conflictsDetected.connect(
            self.on_conflicts_detected
        )
        self.mod_manager_bridge.modConflictsDetected.connect(
            self.on_mod_conflicts_detected
        )

        self.load_settings_to_ui()
        print("[ZZAR] Settings page connected")

    def _connect_welcome_dialog(self):
        self.welcome_dialog = self.root.findChild(QObject, "welcomeDialog")
        if not self.welcome_dialog:
            print("[ZZAR] WARNING: Welcome dialog not found!")
            return

        self.welcome_dialog.modeSelected.connect(self.on_welcome_mode_selected)
        self.welcome_dialog.browseGameDirClicked.connect(self.on_welcome_browse_game_dir)
        self.welcome_dialog.autoDetectClicked.connect(self.on_welcome_auto_detect)
        self.welcome_dialog.checkWwiseClicked.connect(
            self.mod_manager_bridge.checkWwiseInstalled
        )
        self.welcome_dialog.runWwiseSetupClicked.connect(
            self.mod_manager_bridge.runWwiseSetup
        )
        self.welcome_dialog.checkAudioToolsClicked.connect(
            self.mod_manager_bridge.checkAudioToolsInstalled
        )
        self.welcome_dialog.runAudioToolsSetupClicked.connect(
            self.mod_manager_bridge.runAudioToolsSetup
        )

        self.mod_manager_bridge.wwiseStatusChanged.connect(
            self.on_welcome_wwise_status_changed
        )
        self.mod_manager_bridge.audioToolsStatusChanged.connect(
            self.on_welcome_audio_tools_status_changed
        )

        self.welcome_dialog.welcomeLanguageChanged.connect(self.on_language_changed)

        if hasattr(self.welcome_dialog, 'startTutorialClicked'):
            self.welcome_dialog.startTutorialClicked.connect(self.on_start_tutorial)

        print("[ZZAR] Welcome dialog connected")

    def load_settings_to_ui(self):
        from config_manager import get_default_mod_library_dir

        settings = self.load_settings()
        existing_audio_dir = settings.get("game_audio_dir", "")

        mod_creation_mode = settings.get("mod_creation_mode", False)
        self.root.setProperty("modCreationEnabled", mod_creation_mode)
        self.settings_page.setProperty("modCreationEnabled", mod_creation_mode)

        if mod_creation_mode:
            self.mod_manager_bridge.checkWwiseInstalled()

        if platform.system() == "Windows":
            self.mod_manager_bridge.checkAudioToolsInstalled()

        if existing_audio_dir:
            audio_path = Path(existing_audio_dir)

            if "StreamingAssets" in audio_path.parts:
                game_data_dir = audio_path.parent.parent.parent.parent
                self.settings_page.setGameDirectory(str(game_data_dir))
            else:
                self.settings_page.setGameDirectory(existing_audio_dir)

        self.settings_page.setProperty("defaultModsDirectory", str(get_default_mod_library_dir()))
        custom_mods_dir = settings.get("custom_mod_library_dir", "")
        if custom_mods_dir:
            self.settings_page.setModsDirectory(custom_mods_dir)

        saved_lang = settings.get("language", "en")
        self.settings_page.setProperty("currentLanguage", saved_lang)

    def on_language_changed(self, lang_code):
        self.translation_manager.changeLanguage(lang_code)

        if self.settings_page:
            self.settings_page.setProperty("currentLanguage", lang_code)

        try:
            settings = self.load_settings()
            settings["language"] = lang_code
            self.settings_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)
            print(f"[ZZAR] Language changed to: {lang_code}")
        except Exception as e:
            print(f"[ZZAR] Error saving language preference: {e}")

    def on_mod_creation_mode_changed(self, enabled):
        self.root.setProperty("modCreationEnabled", enabled)

        if self.settings_page:
            self.settings_page.setProperty("modCreationEnabled", enabled)
            if enabled:
                self.mod_manager_bridge.checkWwiseInstalled()

    def on_wwise_status_changed(self, installed):
        if self.settings_page:
            self.settings_page.setProperty("wwiseInstalled", installed)
            self.settings_page.setProperty("isInstallingWwise", False)

    def on_wwise_setup_confirmation(self):
        title = QCoreApplication.translate("Application", "Wwise Setup Warning")
        message = QCoreApplication.translate("Application", "You are about to download licensed software from Audiokinetic.\n\n"
            "By proceeding, you acknowledge that:\n"
            "• You are downloading software directly from Audiokinetic\n"
            "• This software is subject to Audiokinetic's licensing terms\n"
            "• You use this software at your own risk\n"
            "• Pucas01 and other ZZAR contributors are not responsible for any issues\n\n"
            "Do you want to continue?")
        QMetaObject.invokeMethod(
            self.root,
            "showConfirmDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", "wwise_setup"),
            Q_ARG("QVariant", "../assets/BellNervous.png")
        )

    def on_wwise_setup_success(self, title, message):
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", ""),
        )

    def on_audio_tools_status_changed(self, installed):
        print(f"[ZZAR] on_audio_tools_status_changed called: installed={installed}")
        if self.settings_page:
            print(f"[ZZAR] Setting audioToolsInstalled={installed}, isInstallingAudioTools=False")
            self.settings_page.setProperty("audioToolsInstalled", installed)
            self.settings_page.setProperty("isInstallingAudioTools", False)
            print("[ZZAR] Properties set successfully")
        else:
            print("[ZZAR] WARNING: settings_page is None!")

    def on_audio_tools_setup_success(self, title, message):
        if self.audio_browser_bridge:
            self.audio_browser_bridge.refresh_audio_tools()
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", ""),
        )

    def on_mod_install_success(self, title, message, image_path):
        print(f"[DEBUG] Mod install success dialog triggered: {title}")
        print(f"[DEBUG] Message: {message}")
        print(f"[DEBUG] Image: {image_path}")
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", image_path),
        )

    def on_browse_game_dir(self):
        current = self.settings_page.property("gameDirectory")
        start_dir = current if current and Path(current).exists() else str(Path.home())

        dirname = NativeDialogs.get_directory(
            QCoreApplication.translate("Application", "Select ZenlessZoneZero_Data Folder"), start_dir
        )

        if dirname:
            selected_path = Path(dirname)

            if (
                selected_path.name != "ZenlessZoneZero_Data"
                and not (selected_path / "StreamingAssets").exists()
            ):
                QMetaObject.invokeMethod(
                    self.root,
                    "showAlertDialog",
                    Qt.QueuedConnection,
                    Q_ARG("QVariant", QCoreApplication.translate("Application", "Invalid Directory")),
                    Q_ARG(
                        "QVariant",
                        QCoreApplication.translate("Application", "Please select the ZenlessZoneZero_Data folder.\n\nThis folder should contain 'StreamingAssets' and other game data folders."),
                    ),
                    Q_ARG("QVariant", ""),
                )
                return

            self.settings_page.setGameDirectory(dirname)

    def on_browse_mods_dir(self):
        current = self.settings_page.property("modsDirectory")
        start_dir = current if current and Path(current).exists() else str(Path.home())

        dirname = NativeDialogs.get_directory(
            QCoreApplication.translate("Application", "Select Mods Directory"), start_dir
        )

        if dirname:
            self.settings_page.setModsDirectory(dirname)

    def on_reset_mods_dir(self):
        self.settings_page.setModsDirectory("")

    def on_auto_detect(self):
        if self.auto_detect_worker and self.auto_detect_worker.isRunning():
            return

        if self.settings_page:
            self.settings_page.setProperty("isAutoDetecting", True)

        from gui.main_qml import AutoDetectWorker
        self.auto_detect_worker = AutoDetectWorker(platform.system())
        self.auto_detect_worker.found.connect(self.on_auto_detect_found_settings)
        self.auto_detect_worker.notFound.connect(self.on_auto_detect_not_found_settings)
        self.auto_detect_worker.start()

    def on_auto_detect_found_settings(self, game_data_dir):
        if self.settings_page:
            self.settings_page.setProperty("isAutoDetecting", False)
            self.settings_page.setGameDirectory(game_data_dir)

        QMetaObject.invokeMethod(
            self.root,
            "showSuccessToast",
            Qt.QueuedConnection,
            Q_ARG("QVariant", QCoreApplication.translate("Application", "Found game directory:\n%1").replace("%1", game_data_dir)),
        )

    def on_auto_detect_not_found_settings(self):
        if self.settings_page:
            self.settings_page.setProperty("isAutoDetecting", False)

        QMetaObject.invokeMethod(
            self.root,
            "showAlertDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", QCoreApplication.translate("Application", "Not Found")),
            Q_ARG(
                "QVariant",
                QCoreApplication.translate("Application", "Could not auto-detect game directory.\n\nPlease select the ZenlessZoneZero_Data folder manually using the Browse button."),
            ),
            Q_ARG("QVariant", ""),
        )

    def on_save_settings(self, game_path):
        print(f"[Settings] Saving settings with game path: {game_path}")

        if not game_path:
            print("[Settings] ERROR: No game path provided")
            QMetaObject.invokeMethod(
                self.root,
                "showAlertDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Invalid Directory")),
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Please select a valid ZenlessZoneZero_Data folder.")),
                Q_ARG("QVariant", ""),
            )
            return

        game_data_path = Path(game_path)

        if not game_data_path.exists():
            print(f"[Settings] ERROR: Path does not exist: {game_data_path}")
            QMetaObject.invokeMethod(
                self.root,
                "showAlertDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Invalid Directory")),
                Q_ARG("QVariant", QCoreApplication.translate("Application", "The selected directory does not exist.")),
                Q_ARG("QVariant", ""),
            )
            return

        if (
            game_data_path.name != "ZenlessZoneZero_Data"
            and not (game_data_path / "StreamingAssets").exists()
        ):
            print(f"[Settings] ERROR: Invalid directory structure")
            QMetaObject.invokeMethod(
                self.root,
                "showAlertDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Invalid Directory")),
                Q_ARG(
                    "QVariant",
                    QCoreApplication.translate("Application", "Please select the ZenlessZoneZero_Data folder.\n\nThis folder should contain 'StreamingAssets' and other game data folders."),
                ),
                Q_ARG("QVariant", ""),
            )
            return

        audio_dir = game_data_path / "StreamingAssets" / "Audio" / "Windows" / "Full"
        persistent_dir = game_data_path / "Persistent" / "Audio" / "Windows" / "Full"

        mod_creation_mode = self.settings_page.property("modCreationEnabled")

        try:
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)
            else:
                settings = {}
        except Exception:
            settings = {}

        custom_mods_dir = self.settings_page.property("modsDirectory") or ""

        settings["game_audio_dir"] = str(audio_dir)
        settings["persistent_audio_dir"] = str(persistent_dir)
        settings["mod_creation_mode"] = mod_creation_mode
        settings["custom_mod_library_dir"] = custom_mods_dir

        print(f"[Settings] Game audio dir: {audio_dir}")
        print(f"[Settings] Persistent dir: {persistent_dir}")
        print(f"[Settings] Mod Creation Mode: {mod_creation_mode}")
        print(f"[Settings] Custom mods dir: {custom_mods_dir or '(default)'}")

        try:
            self.settings_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)

            print(f"[Settings] Settings saved to: {self.settings_file}")

            QMetaObject.invokeMethod(
                self.root,
                "showSuccessToast",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Settings have been saved successfully!")),
            )

            if self.mod_manager_bridge:
                print("[Settings] Reloading mod manager with new paths...")
                self.mod_manager_bridge.load_settings()
                self.mod_manager_bridge.refreshMods()

        except Exception as e:
            print(f"[Settings] ERROR: Failed to save settings: {e}")
            QMetaObject.invokeMethod(
                self.root,
                "showAlertDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Error")),
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Failed to save settings:\n\n%1").replace("%1", str(e))),
                Q_ARG("QVariant", ""),
            )

    def check_first_launch(self):
        try:
            if not self.settings_file.exists():
                print("[ZZAR] First launch detected - showing welcome dialog")
                QMetaObject.invokeMethod(
                    self.root,
                    "showWelcomeDialog",
                    Qt.QueuedConnection,
                )
                return True
            else:
                print("[ZZAR] Settings file exists, skipping welcome dialog")
                return False
        except Exception as e:
            print(f"[ZZAR] Error checking first launch: {e}")
            return False

    def _is_original_language_folder(self, folder_path):
        """Check if a persistent language folder contains original (unmodded) game files.
        Original folders have exactly 57 PCK files (the game's default count)."""
        pck_files = list(folder_path.glob("*.pck"))
        return len(pck_files) == 57

    def _can_move_language_folder(self, folder_name, persistent_path, streaming_path):
        """Check if a persistent language folder can be moved to streaming.
        Moveable only if:
        1. The streaming folder does NOT already have this language folder
        2. The persistent folder contains original (unmodded) audio files"""
        persistent_folder = persistent_path / folder_name
        streaming_folder = streaming_path / folder_name

        streaming_exists = streaming_folder.exists()
        streaming_has_pcks = streaming_exists and any(streaming_folder.glob("*.pck"))
        print(f"[ZZAR] Move check for '{folder_name}': streaming exists={streaming_exists}, has PCKs={streaming_has_pcks}")

        if streaming_has_pcks:
            print(f"[ZZAR]   -> NOT moveable: streaming already has '{folder_name}' with PCK files")
            return False

        is_original = self._is_original_language_folder(persistent_folder)
        pck_count = len(list(persistent_folder.glob("*.pck")))
        print(f"[ZZAR]   -> persistent has {pck_count} PCKs, is_original={is_original}")

        if not is_original:
            print(f"[ZZAR]   -> NOT moveable: not original game files (expected 57 PCKs)")
            return False

        print(f"[ZZAR]   -> MOVEABLE")
        return True

    def check_multiple_languages(self):
        try:
            settings = self.load_settings()
            if settings.get("hide_language_warning", False):
                print("[ZZAR] Language warning disabled by user")
                return

            persistent_dir = settings.get("persistent_audio_dir", "")
            if not persistent_dir:
                print("[ZZAR] No persistent directory configured yet")
                return

            persistent_path = Path(persistent_dir)
            if not persistent_path.exists():
                print("[ZZAR] Persistent directory does not exist yet")
                return

            streaming_dir = settings.get("game_audio_dir", "")
            streaming_path = Path(streaming_dir) if streaming_dir else None

            language_folders = []
            moveable_folders = []
            for item in persistent_path.iterdir():
                if item.is_dir():
                    pck_files = list(item.glob("*.pck"))
                    if pck_files:
                        language_folders.append(item.name)
                        print(f"[ZZAR] Found language folder: {item.name} with {len(pck_files)} PCK files")

                        if streaming_path and self._can_move_language_folder(item.name, persistent_path, streaming_path):
                            moveable_folders.append(item.name)
                            print(f"[ZZAR] Language folder {item.name} is moveable to streaming")

            if moveable_folders:
                print(f"[ZZAR] Found moveable language folders in Persistent: {moveable_folders}")
                languages_text = ", ".join(language_folders)
                moveable_text = ", ".join(moveable_folders)
                QMetaObject.invokeMethod(
                    self.root,
                    "showMultipleLanguagesWarning",
                    Qt.QueuedConnection,
                    Q_ARG("QVariant", languages_text),
                    Q_ARG("QVariant", moveable_text),
                )
            else:
                print(f"[ZZAR] Language check OK: {len(language_folders)} language folder(s), none moveable")
                QMetaObject.invokeMethod(
                    self.root,
                    "hideLanguageWarningDialog",
                    Qt.QueuedConnection,
                )

        except Exception as e:
            print(f"[ZZAR] Error checking multiple languages: {e}")

    def on_move_language_to_streaming(self, folder_name):
        """Move a language folder from Persistent to StreamingAssets."""
        import shutil

        try:
            settings = self.load_settings()
            persistent_dir = settings.get("persistent_audio_dir", "")
            streaming_dir = settings.get("game_audio_dir", "")

            if not persistent_dir or not streaming_dir:
                QMetaObject.invokeMethod(
                    self.root, "showErrorToast", Qt.QueuedConnection,
                    Q_ARG("QVariant", QCoreApplication.translate("Application", "Game directories not configured")),
                )
                return

            persistent_path = Path(persistent_dir)
            streaming_path = Path(streaming_dir)
            source = persistent_path / folder_name
            destination = streaming_path / folder_name

            if not source.exists():
                QMetaObject.invokeMethod(
                    self.root, "showErrorToast", Qt.QueuedConnection,
                    Q_ARG("QVariant", QCoreApplication.translate("Application", "Folder '%1' not found in Persistent").replace("%1", folder_name)),
                )
                return

            if destination.exists() and any(destination.glob("*.pck")):
                QMetaObject.invokeMethod(
                    self.root, "showErrorToast", Qt.QueuedConnection,
                    Q_ARG("QVariant", QCoreApplication.translate("Application", "Folder '%1' already exists in StreamingAssets").replace("%1", folder_name)),
                )
                return

            if not self._is_original_language_folder(source):
                QMetaObject.invokeMethod(
                    self.root, "showErrorToast", Qt.QueuedConnection,
                    Q_ARG("QVariant", QCoreApplication.translate("Application", "Folder '%1' does not contain original game files").replace("%1", folder_name)),
                )
                return

            PROTECTED_PCKS = {'Patch.pck', 'Hotfix.pck'}

            print(f"[ZZAR] Moving language folder: {source} -> {destination}")
            destination.mkdir(parents=True, exist_ok=True)

            skipped = []
            for item in source.iterdir():
                if item.is_file() and item.name in PROTECTED_PCKS:
                    skipped.append(item.name)
                    print(f"[ZZAR] Leaving protected file in Persistent: {item.name}")
                    continue
                shutil.move(str(item), str(destination / item.name))

            if not any(source.iterdir()):
                source.rmdir()
                print(f"[ZZAR] Removed empty source folder: {source}")
            elif skipped:
                print(f"[ZZAR] Source folder kept (contains protected files: {', '.join(skipped)})")

            print(f"[ZZAR] Successfully moved {folder_name} to StreamingAssets")

            QMetaObject.invokeMethod(
                self.root, "showSuccessToast", Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Moved '%1' to StreamingAssets successfully!").replace("%1", folder_name)),
            )

            self.check_multiple_languages()

        except Exception as e:
            print(f"[ZZAR] Error moving language folder: {e}")
            QMetaObject.invokeMethod(
                self.root, "showErrorToast", Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Failed to move '%1': %2").replace("%1", folder_name).replace("%2", str(e))),
            )

    def on_welcome_mode_selected(self, mode):
        print(f"[ZZAR] User selected mode: {mode}")

        try:
            settings = {}
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)

            settings["mod_creation_mode"] = (mode == "maker")
            settings["first_launch_complete"] = True

            game_dir = self.welcome_dialog.property("gameDirectory")
            if game_dir:
                game_data_path = Path(game_dir)
                audio_dir = game_data_path / "StreamingAssets" / "Audio" / "Windows" / "Full"
                persistent_dir = game_data_path / "Persistent" / "Audio" / "Windows" / "Full"
                settings["game_audio_dir"] = str(audio_dir)
                settings["persistent_audio_dir"] = str(persistent_dir)

            self.settings_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=4)

            mod_creation = (mode == "maker")
            self.root.setProperty("modCreationEnabled", mod_creation)
            if self.settings_page:
                self.settings_page.setProperty("modCreationEnabled", mod_creation)
                if game_dir:
                    self.settings_page.setGameDirectory(game_dir)

            if game_dir and self.audio_page:
                QMetaObject.invokeMethod(
                    self.audio_page, "setGameDirectory",
                    Qt.QueuedConnection, Q_ARG("QVariant", game_dir),
                )
                if self.audio_browser_bridge:
                    self.audio_browser_bridge.scanLanguageFolders(game_dir)

            self.mod_manager_bridge.setModCreationMode(mod_creation)

            if game_dir:
                self.mod_manager_bridge.load_settings()
                self.mod_manager_bridge.refreshMods()

            QMetaObject.invokeMethod(
                self.root,
                "showSuccessToast",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Welcome setup complete! Settings have been saved.")),
            )

            self.check_multiple_languages()

        except Exception as e:
            print(f"[ZZAR] Error saving welcome mode: {e}")
            QMetaObject.invokeMethod(
                self.root,
                "showErrorToast",
                Qt.QueuedConnection,
                Q_ARG("QVariant", QCoreApplication.translate("Application", "Error saving settings: %1").replace("%1", str(e))),
            )

    def on_start_tutorial(self):
        print("[ZZAR] Starting tutorial...")
        self.root.setProperty("tutorialActive", True)
        QMetaObject.invokeMethod(
            self.root,
            "showTutorial",
            Qt.QueuedConnection,
        )

    def on_welcome_browse_game_dir(self):
        print("[ZZAR] Welcome browse button clicked!")
        current = self.welcome_dialog.property("gameDirectory")
        start_dir = current if current and Path(current).exists() else str(Path.home())

        was_visible = self.welcome_dialog.property("visible")
        if was_visible:
            self.welcome_dialog.setProperty("visible", False)
            QApplication.processEvents()

        dirname = NativeDialogs.get_directory(
            QCoreApplication.translate("Application", "Select ZenlessZoneZero_Data Folder"), start_dir
        )

        if was_visible:
            self.welcome_dialog.setProperty("visible", True)

        if dirname:
            selected_path = Path(dirname)

            if (
                selected_path.name != "ZenlessZoneZero_Data"
                and not (selected_path / "StreamingAssets").exists()
            ):
                QMetaObject.invokeMethod(
                    self.root,
                    "showAlertDialog",
                    Qt.QueuedConnection,
                    Q_ARG("QVariant", QCoreApplication.translate("Application", "Invalid Directory")),
                    Q_ARG(
                        "QVariant",
                        QCoreApplication.translate("Application", "Please select the ZenlessZoneZero_Data folder.\n\nThis folder should contain 'StreamingAssets' and other game data folders."),
                    ),
                    Q_ARG("QVariant", ""),
                )
                return

            QMetaObject.invokeMethod(
                self.welcome_dialog,
                "setGameDirectory",
                Qt.QueuedConnection,
                Q_ARG("QVariant", dirname),
            )

    def on_welcome_auto_detect(self):
        print("[ZZAR] Welcome auto-detect button clicked!")

        if self.auto_detect_worker and self.auto_detect_worker.isRunning():
            return

        if self.welcome_dialog:
            self.welcome_dialog.setProperty("isAutoDetecting", True)

        from gui.main_qml import AutoDetectWorker
        self.auto_detect_worker = AutoDetectWorker(platform.system())
        self.auto_detect_worker.found.connect(self.on_auto_detect_found_welcome)
        self.auto_detect_worker.notFound.connect(self.on_auto_detect_not_found_welcome)
        self.auto_detect_worker.start()

    def on_auto_detect_found_welcome(self, game_data_dir):
        if self.welcome_dialog:
            self.welcome_dialog.setProperty("isAutoDetecting", False)
            QMetaObject.invokeMethod(
                self.welcome_dialog,
                "setGameDirectory",
                Qt.QueuedConnection,
                Q_ARG("QVariant", game_data_dir),
            )

        QMetaObject.invokeMethod(
            self.root,
            "showSuccessToast",
            Qt.QueuedConnection,
            Q_ARG("QVariant", QCoreApplication.translate("Application", "Found game directory!")),
        )

    def on_auto_detect_not_found_welcome(self):
        if self.welcome_dialog:
            self.welcome_dialog.setProperty("isAutoDetecting", False)

        QMetaObject.invokeMethod(
            self.root,
            "showAlertDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", QCoreApplication.translate("Application", "Not Found")),
            Q_ARG(
                "QVariant",
                QCoreApplication.translate("Application", "Could not auto-detect game directory.\n\nPlease select the ZenlessZoneZero_Data folder manually using the Browse button."),
            ),
            Q_ARG("QVariant", ""),
        )

    def on_welcome_wwise_status_changed(self, installed):
        if self.welcome_dialog:
            self.welcome_dialog.setProperty("wwiseInstalled", installed)
            self.welcome_dialog.setProperty("isInstallingWwise", False)

    def on_welcome_audio_tools_status_changed(self, installed):
        print(f"[ZZAR] on_welcome_audio_tools_status_changed called: installed={installed}")
        if self.welcome_dialog:
            print(f"[ZZAR] Setting welcome dialog audioToolsInstalled={installed}, isInstallingAudioTools=False")
            self.welcome_dialog.setProperty("audioToolsInstalled", installed)
            self.welcome_dialog.setProperty("isInstallingAudioTools", False)
            print("[ZZAR] Welcome dialog properties set successfully")
        else:
            print("[ZZAR] WARNING: welcome_dialog is None!")

    def on_language_warning_dont_show_again(self, dont_show):
        try:
            settings = self.load_settings()
            settings["hide_language_warning"] = dont_show

            self.settings_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)

            print(f"[ZZAR] Language warning preference saved: hide={dont_show}")
        except Exception as e:
            print(f"[ZZAR] Error saving language warning preference: {e}")
