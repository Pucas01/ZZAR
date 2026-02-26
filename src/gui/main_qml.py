from PyQt5.QtCore import QCoreApplication


import os
import sys
import json
import platform
import subprocess
from pathlib import Path

if platform.system() == "Windows":
    os.environ["QT_QPA_PLATFORM"] = "windows:fontengine=freetype"
from PyQt5.QtGui import QGuiApplication, QIcon, QSurfaceFormat, QFontDatabase
from PyQt5.QtQml import QQmlApplicationEngine, qmlRegisterSingletonType
from PyQt5.QtCore import QUrl, QObject, QCoreApplication, QMetaObject, Q_ARG, Qt, QThread, pyqtSignal, pyqtSlot
from PyQt5.QtWidgets import QApplication


class ClipboardHelper(QObject):
    @pyqtSlot(str)
    def setText(self, text):
        QApplication.clipboard().setText(text)

project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(
    0, str(project_root / "src")
)

from gui.backend.mod_manager_bridge import ModManagerBridge
from gui.backend.audio_browser_bridge import AudioBrowserBridge
from gui.backend.audio_conversion_bridge import AudioConversionBridge
from gui.backend.update_manager_bridge import UpdateManagerBridge
from gui.backend.native_dialogs import NativeDialogs
from src.config_manager import get_settings_file, get_cache_dir

from gui.connectors.mod_manager_connector import ModManagerConnector
from gui.connectors.audio_browser_connector import AudioBrowserConnector
from gui.connectors.import_wizard_connector import ImportWizardConnector
from gui.connectors.settings_connector import SettingsConnector
from gui.connectors.update_connector import UpdateConnector
from gui.translation_manager import TranslationManager

class AutoDetectWorker(QThread):

    found = pyqtSignal(str)
    notFound = pyqtSignal()

    def __init__(self, system_type):
        super().__init__()
        self.system_type = system_type

    def run(self):

        if self.system_type == "Windows":

            search_paths = [
                Path("C:/Program Files/HoYoPlay/games/ZenlessZoneZero Game"),
                Path("D:/Program Files/HoYoPlay/games/ZenlessZoneZero Game"),
                Path("E:/Program Files/HoYoPlay/games/ZenlessZoneZero Game"),
                Path.home() / "Games/ZenlessZoneZero Game",
            ]

            for base_path in search_paths:
                game_data_dir = base_path / "ZenlessZoneZero_Data"
                if game_data_dir.exists() and (game_data_dir / "StreamingAssets").exists():
                    self.found.emit(str(game_data_dir))
                    return
        else:

            print("[ZZAR] Searching for ZenlessZoneZero_Data from root directory...")
            try:
                result = subprocess.run(
                    ["find", "/", "-name", "ZenlessZoneZero_Data", "-type", "d"],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL,
                    text=True,
                    timeout=60
                )

                if result.stdout:
                    lines = result.stdout.strip().split('\n')
                    for line in lines:
                        if ".local/share/dolphin" in line:
                            continue
                        game_data_dir = Path(line)
                        if game_data_dir.exists() and (game_data_dir / "StreamingAssets").exists():
                            self.found.emit(str(game_data_dir))
                            return
            except subprocess.TimeoutExpired:
                print("[ZZAR] Search timed out after 60 seconds")
            except Exception as e:
                print(f"[ZZAR] Search error: {e}")

        self.notFound.emit()

def theme_singleton_provider(engine, script_engine):

    return None

class Application(
    ModManagerConnector,
    AudioBrowserConnector,
    ImportWizardConnector,
    SettingsConnector,
    UpdateConnector,
    QObject,
):


    def __init__(self, version):
        super().__init__()

        QCoreApplication.setApplicationVersion(version)

        self.app = None
        self.engine = None
        self.mod_manager_bridge = None
        self.audio_browser_bridge = None
        self.audio_conversion_bridge = None
        self.settings_file = get_settings_file()
        self.settings_page = None
        self.mod_page = None
        self.audio_page = None
        self.conversion_page = None
        self.import_wizard = None
        self.mod_info_dialog = None
        self.pending_remove_uuids = []
        self.import_worker = None
        self.wizard_selected_files = []
        self.wizard_selected_folder = ""
        self.auto_detect_worker = None
        self.update_manager_bridge = None
        self.update_dialog = None
        self._startup_update_check = False

    def run(self):

        print("=" * 50)
        print("ZZAR - Zenless Zone Zero Audio Replacer")
        print("QML UI Version")
        print("=" * 50)

        QCoreApplication.setAttribute(Qt.AA_DontUseNativeDialogs, False)

        QCoreApplication.setAttribute(Qt.AA_EnableHighDpiScaling, True)
        QCoreApplication.setAttribute(Qt.AA_UseHighDpiPixmaps, True)

        format = QSurfaceFormat()
        format.setSamples(4)
        QSurfaceFormat.setDefaultFormat(format)

        QCoreApplication.setOrganizationName("ZZAR")
        QCoreApplication.setOrganizationDomain("zzar.local")
        QCoreApplication.setApplicationName("ZZAR")

        self.app = QApplication(sys.argv)
        self.app.setApplicationName("ZZAR")
        self.app.setApplicationVersion(QCoreApplication.applicationVersion())

        ui_path = Path(__file__).parent
        icon_path = ui_path / "assets" / "ZZAR-Logo2.png"
        if icon_path.exists():
            self.app.setWindowIcon(QIcon(str(icon_path)))

        fonts_dir = ui_path / "assets" / "fonts"

        audiowide_font = fonts_dir / "Audiowide" / "Audiowide-Regular.ttf"
        alatsi_font = fonts_dir / "Alatsi" / "Alatsi-Regular.ttf"
        stretch_pro_font = fonts_dir / "Stretch_Pro" / "StretchPro.otf"

        if audiowide_font.exists():
            if QFontDatabase.addApplicationFont(str(audiowide_font)) == -1:
                print("[ZZAR] WARNING: Failed to load Audiowide font")
        else:
            print(f"[ZZAR] WARNING: Audiowide font not found at {audiowide_font}")

        if alatsi_font.exists():
            if QFontDatabase.addApplicationFont(str(alatsi_font)) == -1:
                print("[ZZAR] WARNING: Failed to load Alatsi font")
        else:
            print(f"[ZZAR] WARNING: Alatsi font not found at {alatsi_font}")

        if stretch_pro_font.exists():
            if QFontDatabase.addApplicationFont(str(stretch_pro_font)) == -1:
                print("[ZZAR] WARNING: Failed to load Stretch Pro font")
        else:
            print(f"[ZZAR] WARNING: Stretch Pro font not found at {stretch_pro_font}")

        zzz_font = fonts_dir / "ZZZ-Font" / "ZZZ-Font.ttf"
        if zzz_font.exists():
            if QFontDatabase.addApplicationFont(str(zzz_font)) == -1:
                print("[ZZAR] WARNING: Failed to load ZZZ font")
        else:
            print(f"[ZZAR] WARNING: ZZZ font not found at {zzz_font}")

        self.engine = QQmlApplicationEngine()
        self.mod_manager_bridge = ModManagerBridge()
        self.audio_browser_bridge = AudioBrowserBridge()
        self.audio_conversion_bridge = AudioConversionBridge()
        self.update_manager_bridge = UpdateManagerBridge()
        self.update_manager_bridge.setCurrentVersion(QCoreApplication.applicationVersion())

        context = self.engine.rootContext()
        context.setContextProperty("modManagerBackend", self.mod_manager_bridge)
        context.setContextProperty("audioBrowserBackend", self.audio_browser_bridge)
        context.setContextProperty("audioConversionBackend", self.audio_conversion_bridge)
        self.clipboard_helper = ClipboardHelper()
        context.setContextProperty("clipboardHelper", self.clipboard_helper)

        self.translation_manager = TranslationManager(self.engine)
        context.setContextProperty("translationManager", self.translation_manager)

        settings = self.load_settings()
        saved_lang = settings.get("language", "en")
        if saved_lang != "en":
            self.translation_manager.changeLanguage(saved_lang)

        ui_path = Path(__file__).parent
        self.engine.addImportPath(str(ui_path / "qml"))
        self.engine.addImportPath(str(ui_path / "components"))

        qml_file = ui_path / "qml" / "MainWindow.qml"
        print(f"Loading QML from: {qml_file}")
        self.engine.load(QUrl.fromLocalFile(str(qml_file)))

        if not self.engine.rootObjects():
            print("Error: Failed to load QML")

        print("[ZZAR] QML loaded successfully!")
        print("[ZZAR] Initializing mod manager...")

        root = self.engine.rootObjects()[0]
        self.root = root

        self._connect_mod_manager()
        self._connect_audio_browser()
        self._connect_conversion_page()
        self._connect_settings()
        self._connect_updates()
        self._connect_import_wizard()

        self.mod_info_dialog = root.findChild(QObject, "modInfoDialog")
        if self.mod_info_dialog:
            self.mod_info_dialog.exportRequested.connect(
                self.mod_manager_bridge.exportMod
            )
            print("[ZZAR] Mod info dialog connected")

        self.update_dialog = root.findChild(QObject, "updateDialog")
        if self.update_dialog:
            self.update_dialog.updateAccepted.connect(self._on_update_dialog_accepted)
            self.update_dialog.updateDismissed.connect(self._on_update_dialog_dismissed)
            print("[ZZAR] Update dialog connected")

        self.conflict_resolution_dialog = root.findChild(QObject, "conflictResolutionDialog")
        if self.conflict_resolution_dialog:
            self.conflict_resolution_dialog.setProperty("modManager", self.mod_manager_bridge)
            print("[ZZAR] Conflict resolution dialog connected")

        self.mod_conflict_dialog = root.findChild(QObject, "modConflictDialog")
        if self.mod_conflict_dialog:
            self.mod_conflict_dialog.setProperty("modManager", self.mod_manager_bridge)
            print("[ZZAR] Mod conflict dialog connected")

        self.audio_match_dialog = root.findChild(QObject, "audioMatchDialog")
        if self.audio_match_dialog:
            self.audio_match_dialog.fileSelectionRequested.connect(
                self.audio_browser_bridge.selectRecordingFile
            )
            self.audio_match_dialog.matchStartRequested.connect(
                self.audio_browser_bridge.startMatchingWithFile
            )
            self.audio_match_dialog.matchCancelled.connect(
                self.audio_browser_bridge.cancelMatchingSound
            )
            self.audio_browser_bridge.audio_match_dialog = self.audio_match_dialog
            print("[ZZAR] Audio match dialog connected")

        self._connect_welcome_dialog()

        print("[ZZAR] Application ready!")
        print("-" * 50)

        is_first_launch = self.check_first_launch()

        if not is_first_launch:
            self.check_multiple_languages()

        self._check_update_success_flag()

        if hasattr(sys, '_MEIPASS'):
            print("[ZZAR] PyInstaller build detected, checking for updates...")
            self._startup_update_check = True
            self.update_manager_bridge.checkForUpdates()

        return self.app.exec_()

    def _connect_conversion_page(self):
        self.conversion_page = self.root.findChild(QObject, "audioConversionPage")
        if not self.conversion_page:
            return

        ac = self.audio_conversion_bridge

        self.conversion_page.browseInputFileClicked.connect(
            self.on_conversion_browse_input_file
        )
        self.conversion_page.browseInputDirectoryClicked.connect(
            self.on_conversion_browse_input_dir
        )
        self.conversion_page.browseOutputDirectoryClicked.connect(
            self.on_conversion_browse_output_dir
        )
        self.conversion_page.convertAudioClicked.connect(ac.convertAudio)

        ac.inputPathSelected.connect(
            lambda path: QMetaObject.invokeMethod(
                self.conversion_page, "setInputPath",
                Qt.QueuedConnection, Q_ARG("QVariant", path)
            )
        )
        ac.outputPathSelected.connect(
            lambda path: QMetaObject.invokeMethod(
                self.conversion_page, "setOutputPath",
                Qt.QueuedConnection, Q_ARG("QVariant", path)
            )
        )
        ac.conversionStarted.connect(
            lambda: QMetaObject.invokeMethod(
                self.conversion_page, "setConvertingState",
                Qt.QueuedConnection, Q_ARG("QVariant", True)
            )
        )
        ac.conversionFinished.connect(
            lambda: QMetaObject.invokeMethod(
                self.conversion_page, "setConvertingState",
                Qt.QueuedConnection, Q_ARG("QVariant", False)
            )
        )
        ac.logMessage.connect(
            lambda msg: QMetaObject.invokeMethod(
                self.conversion_page, "appendLog",
                Qt.QueuedConnection, Q_ARG("QVariant", msg)
            )
        )
        ac.errorOccurred.connect(self.on_error_occurred)
        ac.conversionSuccess.connect(self.on_conversion_success)
        ac.conversionErrorDialog.connect(self.on_conversion_error_dialog)

        ab = self.audio_browser_bridge
        self.conversion_page.normalizeAudioToggled.connect(ab.setNormalizeAudio)
        ab.normalizeAudioChanged.connect(
            lambda enabled: self.conversion_page.setProperty("normalizeChecked", enabled)
        )
        self.conversion_page.setProperty("normalizeChecked", ab.normalize_audio_enabled)

        print("[ZZAR] Audio conversion page connected")

    def load_settings(self):
        try:
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    return json.load(f)
        except Exception as e:
            print(f"Warning: Failed to load settings: {e}")
        return {}

    def on_progress_update(self, message):
        if "successfully" in message.lower() or "applied" in message.lower():
            QMetaObject.invokeMethod(
                self.root,
                "showSuccessToast",
                Qt.QueuedConnection,
                Q_ARG("QVariant", message),
            )

    def on_error_occurred(self, title, message):
        full_message = f"{title}: {message}" if title else message
        QMetaObject.invokeMethod(
            self.root,
            "showErrorToast",
            Qt.QueuedConnection,
            Q_ARG("QVariant", full_message),
        )

    def on_alert_dialog_requested(self, title, message, sticker_path=""):
        QMetaObject.invokeMethod(
            self.root,
            "showAlertDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", sticker_path),
        )

    def on_wip_dialog_requested(self):
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", QCoreApplication.translate("Application", "Work in Progress")),
            Q_ARG("QVariant", QCoreApplication.translate("Application", "This feature is not yet implemented.\n\nThis will be added in a future update. (i hope)")),
            Q_ARG("QVariant", "../assets/YuzuhaSilly.png")
        )

    def on_wwise_error_dialog(self, title, message):
        QMetaObject.invokeMethod(
            self.root,
            "showAlertDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", ""),
        )

    def on_audio_success_dialog(self, title, message, image_path):
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", image_path),
        )

    def on_conversion_success(self, title, message):
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", ""),
        )

    def on_conversion_error_dialog(self, title, message):
        QMetaObject.invokeMethod(
            self.root,
            "showAlertDialog",
            Qt.QueuedConnection,
            Q_ARG("QVariant", title),
            Q_ARG("QVariant", message),
            Q_ARG("QVariant", ""),
        )

    def on_conversion_browse_input_file(self):
        if not self.conversion_page:
            return

        mode = self.conversion_page.property("currentMode")

        if mode == 0:
            filter_str = "WEM Files (*.wem);;All Files (*)"
            title = "Select WEM File"
        elif mode == 1:
            filter_str = "Audio Files (*.mp3 *.flac *.ogg *.m4a *.aac);;All Files (*)"
            title = "Select Audio File"
        else:
            filter_str = "WAV Files (*.wav);;All Files (*)"
            title = "Select WAV File"

        file_path = NativeDialogs.get_open_file(title, str(Path.home()), filter_str)

        if file_path:
            self.audio_conversion_bridge.inputPathSelected.emit(file_path)

    def on_conversion_browse_input_dir(self):
        dirname = NativeDialogs.get_directory(
            "Select Input Directory", str(Path.home())
        )

        if dirname:
            self.audio_conversion_bridge.inputPathSelected.emit(dirname)

    def on_conversion_browse_output_dir(self):
        dirname = NativeDialogs.get_directory(
            "Select Output Directory", str(Path.home())
        )

        if dirname:
            self.audio_conversion_bridge.outputPathSelected.emit(dirname)

def main():

    app = Application(version=__version__)
    return app.run()

if __name__ == "__main__":
    sys.exit(main())
