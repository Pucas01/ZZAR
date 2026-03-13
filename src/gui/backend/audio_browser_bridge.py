

import hashlib
import json
import os
import struct
import threading
import tempfile
import subprocess
import urllib.request
import urllib.error
from pathlib import Path
from PyQt5.QtCore import (
    QObject, pyqtSlot, pyqtSignal, QMetaObject, Qt, Q_ARG, QThread, QCoreApplication
)

from src.app_config import (
    GAME_DATA_FOLDER, MOD_FILE_EXT, MOD_FILE_EXT_UPPER, ASSETS_DIR, APP_NAME, DATA_SUBDIR,
    AUDIO_SUBPATH, SOUNDBANK_PCK_GLOB, STREAMED_PCK_GLOB, STREAMED_PCK_PREFIX, SOUNDBANK_PCK_PREFIX,
    LANGUAGE_FOLDERS, BUILD_TARGET, AUDIO_ROOT_FRIENDLY_NAME, SUBFOLDER_SORT_PRIORITY,
)
from src.pck_indexer import PCKIndexer
from src.bnk_indexer import BNKIndexer
from src.temp_cache_manager import TempCacheManager
from src.audio_player import AudioPlayer
from src.audio_converter import AudioConverter
from src.sound_database import SoundDatabase
from src.fingerprint_database import FingerprintDatabase
from src.persistent_mod_manager import PersistentModManager
from src.pck_packer import PCKPacker
from src.mod_package_manager import ModPackageManager
from src.config_manager import get_settings_file, get_config_dir
from gui.backend.update_manager_bridge import _urlopen

OFFICIAL_TAG_DB_URL = f"https://raw.githubusercontent.com/Pucas01/{APP_NAME}/main/data/{DATA_SUBDIR}/official_sound_database.json"
OFFICIAL_FINGERPRINT_DB_URL = f"https://raw.githubusercontent.com/Pucas01/{APP_NAME}/main/data/{DATA_SUBDIR}/official_fingerprint_database.json"

def _get_tag_db_url():
    from ZZAR import DEV_MODE, get_base_path
    if DEV_MODE:
        dev_path = get_base_path() / "data" / DATA_SUBDIR / "dev_sound_database.json"
        return dev_path.as_uri()
    return OFFICIAL_TAG_DB_URL

def _get_fingerprint_db_url():
    from ZZAR import DEV_MODE, get_base_path
    if DEV_MODE:
        dev_path = get_base_path() / "data" / DATA_SUBDIR / "dev_fingerprint_database.json"
        return dev_path.as_uri()
    return OFFICIAL_FINGERPRINT_DB_URL

class _WorkerThread(QThread):

    finished = pyqtSignal(bool, object)

    def __init__(self, func, *args):
        super().__init__()
        self.func = func
        self.args = args

    def run(self):
        try:
            result = self.func(*self.args)
            self.finished.emit(True, result)
        except Exception as e:
            import traceback
            self.finished.emit(False, f"{e}\n{traceback.format_exc()}")

class ReplaceAudioWorker(QThread):

    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)

    def __init__(self, custom_file_path, meta, normalize, mod_manager):
        super().__init__()
        self.custom_file_path = custom_file_path
        self.meta = meta
        self.normalize = normalize
        self.mod_manager = mod_manager

    def run(self):
        try:
            pck_file_path = Path(self.meta["pck_path"])
            pck_filename = pck_file_path.name

            if self.meta["type"] == "wem":
                file_id = self.meta["file_id"]
                lang_id = self.meta["lang_id"]
                bnk_id = None
            else:
                file_id = self.meta["wem_id"]
                lang_id = self.meta.get("lang_id", 0)
                bnk_id = self.meta["bnk_id"]

            custom_file = Path(self.custom_file_path)
            if custom_file.suffix.lower() == ".wem":
                wem_file = custom_file
            else:
                self.progress.emit(
                    QCoreApplication.translate("Application", "Converting %1 to WEM...").replace("%1", custom_file.suffix)
                )
                converter = AudioConverter()
                if custom_file.suffix.lower() == ".wav":
                    wav_file = custom_file
                else:
                    wav_file = converter.any_to_wav(str(custom_file), normalize=self.normalize)
                wem_file = converter.wav_to_wem(str(wav_file))

            self.progress.emit(
                QCoreApplication.translate("Application", "Staging replacement...")
            )
            self.mod_manager.add_replacement(
                pck_filename, file_id, str(wem_file),
                "wem" if bnk_id is None else "bnk",
                lang_id, bnk_id,
            )

            streaming_path = pck_file_path.parent
            persistent_path = Path(str(streaming_path).replace("StreamingAssets", "Persistent"))
            self.mod_manager.set_persistent_path(str(persistent_path))

            self.finished.emit(True,
                QCoreApplication.translate("Application", "Replacement staged: %1 (ID: %2) - Click 'Apply Changes' to activate").replace("%1", pck_filename).replace("%2", str(file_id))
            )

        except RuntimeError as e:
            error_msg = str(e)
            if "Wwise is not installed" in error_msg or "Wwise Not" in error_msg:
                self.finished.emit(False, "WWISE:" + error_msg)
            else:
                self.finished.emit(False, error_msg)
        except Exception as e:
            import traceback
            traceback.print_exc()
            self.finished.emit(False, str(e))


class TagDatabaseDownloadWorker(QThread):

    downloadFinished = pyqtSignal(str)
    errorOccurred = pyqtSignal(str)

    def run(self):
        try:
            url = _get_tag_db_url()
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "ZZAR-TagDB")

            with _urlopen(req, timeout=30) as response:
                data = response.read()

            json.loads(data.decode("utf-8"))

            temp_file = tempfile.NamedTemporaryFile(
                suffix=".json", prefix="zzar_tagdb_", delete=False
            )
            temp_file.write(data)
            temp_file.close()

            self.downloadFinished.emit(temp_file.name)

        except json.JSONDecodeError:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Downloaded file is not valid JSON"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.errorOccurred.emit(QCoreApplication.translate("Application", "Official tag database not found on GitHub"))
            else:
                self.errorOccurred.emit(QCoreApplication.translate("Application", "HTTP error: %1 %2").replace("%1", str(e.code)).replace("%2", str(e.reason)))
        except urllib.error.URLError as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Network error: %1").replace("%1", str(e.reason)))
        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Download failed: %1").replace("%1", str(e)))

class TagDatabaseCheckWorker(QThread):

    newTagsFound = pyqtSignal(int, str)
    noNewTags = pyqtSignal()

    def __init__(self, last_seen_hash):
        super().__init__()
        self.last_seen_hash = last_seen_hash

    def run(self):
        try:
            url = _get_tag_db_url()
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "ZZAR-TagDB")

            with _urlopen(req, timeout=15) as response:
                data = response.read()

            content_hash = hashlib.sha256(data).hexdigest()

            if content_hash == self.last_seen_hash:
                self.noNewTags.emit()
                return

            db = json.loads(data.decode("utf-8"))
            entry_count = len(db)

            if entry_count == 0:
                self.noNewTags.emit()
                return

            self.newTagsFound.emit(entry_count, content_hash)

        except Exception:
            pass

class FingerprintDatabaseDownloadWorker(QThread):

    downloadFinished = pyqtSignal(str)
    errorOccurred = pyqtSignal(str)

    def run(self):
        try:
            url = _get_fingerprint_db_url()
            req = urllib.request.Request(url)
            req.add_header("User-Agent", "ZZAR-FingerprintDB")

            with _urlopen(req, timeout=30) as response:
                data = response.read()

            json.loads(data.decode("utf-8"))

            temp_file = tempfile.NamedTemporaryFile(
                suffix=".json", prefix="zzar_fingerprintdb_", delete=False
            )
            temp_file.write(data)
            temp_file.close()

            self.downloadFinished.emit(temp_file.name)

        except json.JSONDecodeError:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Downloaded file is not valid JSON"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.errorOccurred.emit(QCoreApplication.translate("Application", "Official fingerprint database not found on GitHub"))
            else:
                self.errorOccurred.emit(QCoreApplication.translate("Application", "HTTP error: %1 %2").replace("%1", str(e.code)).replace("%2", str(e.reason)))
        except urllib.error.URLError as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Network error: %1").replace("%1", str(e.reason)))
        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Download failed: %1").replace("%1", str(e)))

class AudioBrowserBridge(QObject):

    statusUpdate = pyqtSignal(str, arguments=["message"])
    nowPlayingUpdate = pyqtSignal(str, arguments=["text"])
    playbackStateUpdate = pyqtSignal(bool, bool, bool, arguments=["playing", "paused", "enabled"])
    progressUpdate = pyqtSignal(float, str, arguments=["position", "timeStr"])
    treeCleared = pyqtSignal()
    treeItemsReady = pyqtSignal(list, arguments=["items"])
    languageTabsReady = pyqtSignal(list, arguments=["tabs"])
    gameDirectoryReady = pyqtSignal(str, arguments=["path"])
    errorOccurred = pyqtSignal(str, str, arguments=["title", "message"])
    alertDialogRequested = pyqtSignal(str, str, str, arguments=["title", "message", "stickerPath"])
    wwiseErrorDialog = pyqtSignal(str, str, arguments=["title", "message"])
    successDialogRequested = pyqtSignal(str, str, str, arguments=["title", "message", "imagePath"])
    searchResultsReady = pyqtSignal(str, list, arguments=["query", "results"])
    navigateToItem = pyqtSignal(str, str, str, arguments=["fileId", "pckPath", "bnkId"])
    changesReady = pyqtSignal(list, arguments=["changes"])
    closeChangesDialog = pyqtSignal()
    tagDialogReady = pyqtSignal(object, arguments=["soundInfo"])
    tagUpdated = pyqtSignal(str, str, str, str, arguments=["itemId", "itemType", "pckPath", "tagText"])
    exportMetadataDialogReady = pyqtSignal(object, arguments=["metadata"])
    thumbnailPathSelected = pyqtSignal(str, arguments=["path"])
    changesCountUpdated = pyqtSignal(int, arguments=["count"])
    normalizeAudioChanged = pyqtSignal(bool, arguments=["enabled"])
    hideEmptyBnkChanged = pyqtSignal(bool, arguments=["enabled"])
    loadingStarted = pyqtSignal(str, arguments=["message"])
    loadingFinished = pyqtSignal()
    tagDbDownloadStarted = pyqtSignal()
    tagDbDownloadReady = pyqtSignal(int, arguments=["entryCount"])
    tagDbDownloadError = pyqtSignal(str, arguments=["message"])
    tagDbImportComplete = pyqtSignal(int, arguments=["importedCount"])
    newTagDbAvailable = pyqtSignal(int, arguments=["entryCount"])
    fingerprintDbPrompt = pyqtSignal(int, arguments=["entryCount"])
    fingerprintDbDownloadStarted = pyqtSignal()
    fingerprintDbDownloadReady = pyqtSignal(int, arguments=["entryCount"])
    fingerprintDbDownloadError = pyqtSignal(str, arguments=["message"])
    fingerprintDbImportComplete = pyqtSignal(int, arguments=["importedCount"])
    matchProgressUpdate = pyqtSignal(int, int, arguments=["current", "total"])
    matchResultsReady = pyqtSignal(list, arguments=["results"])
    matchStarted = pyqtSignal()
    matchFinished = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings_file = get_settings_file()

        self.cache_manager = TempCacheManager(max_cached_files=100)
        self.audio_player = AudioPlayer(AudioConverter(), self.cache_manager)
        self.sound_db = SoundDatabase()
        self.fingerprint_db = FingerprintDatabase()
        self.mod_manager = PersistentModManager()

        self.game_root_dir = None
        self.language_folders = {}
        self.current_language_folder = ""
        self.merge_wem_enabled = BUILD_TARGET != "SRAR"
        self.hide_useless_pck_enabled = BUILD_TARGET != "SRAR"
        self.hide_empty_bnk_enabled = True
        self.normalize_audio_enabled = True

        self.file_id_index = {}
        self.index_ready = False

        self._item_data = {}
        self._pck_loaded = {}
        self._bnk_loaded = {}

        self._index_cache = {}
        self._tree_cache = {}
        self._current_directory = None
        self._match_metadata = {}

        self._worker = None
        self._index_thread = None
        self._index_cancel = threading.Event()
        self._playback_duration = 0

        self._imported_mod_metadata = None
        self._match_thread = None
        self._match_cancel = threading.Event()
        self._tag_db_worker = None
        self._tag_db_temp_path = None
        self._tag_db_check_worker = None
        self._tag_db_notify_dismissed = False
        self._tag_db_last_seen_hash = ""
        self._tag_db_check_done = False
        self._fingerprint_db_worker = None
        self._fingerprint_db_temp_path = None
        self._fingerprint_db_prompt_shown = False
        self._pending_match_path = None

        self.audio_player.state_changed.connect(self._on_playback_state_changed)
        self.audio_player.position_changed.connect(self._on_position_changed)
        self.audio_player.duration_changed.connect(self._on_duration_changed)
        self.audio_player.error_occurred.connect(self._on_playback_error)

    def _invalidate_caches(self):
        self._index_cache.clear()
        self._tree_cache.clear()
        self._current_directory = None
        self.index_ready = False

    @pyqtSlot()
    def invalidateIndexCache(self):
        self._invalidate_caches()

    @pyqtSlot()
    def loadFromSettings(self):

        try:
            if not self.settings_file.exists():
                return

            with open(self.settings_file, "r") as f:
                settings = json.load(f)

            normalize = settings.get("normalize_audio", True)
            self.normalize_audio_enabled = normalize
            self.normalizeAudioChanged.emit(normalize)

            hide_empty_bnk = settings.get("hide_empty_bnk", True)
            self.hide_empty_bnk_enabled = hide_empty_bnk
            self.hideEmptyBnkChanged.emit(hide_empty_bnk)

            self._tag_db_notify_dismissed = settings.get("tag_db_notify_dismissed", False)
            self._tag_db_last_seen_hash = settings.get("tag_db_last_seen_hash", "")

            game_audio_dir = settings.get("game_audio_dir", "")
            if not game_audio_dir:
                return

            audio_path = Path(game_audio_dir)

            if "StreamingAssets" in audio_path.parts:
                game_data_dir = str(audio_path.parent.parent.parent.parent)
            else:
                game_data_dir = game_audio_dir

            if Path(game_data_dir).exists():
                self.gameDirectoryReady.emit(game_data_dir)
                self.scanLanguageFolders(game_data_dir)

            self._emit_changes_count()

        except Exception as e:
            print(f"[Audio Browser] Error loading settings: {e}")

    @pyqtSlot(str)
    def scanLanguageFolders(self, selected_dir):

        selected_dir = Path(selected_dir)

        data_folder = None
        if selected_dir.name == GAME_DATA_FOLDER:
            data_folder = selected_dir
        elif (selected_dir / GAME_DATA_FOLDER).exists():
            data_folder = selected_dir / GAME_DATA_FOLDER

        if not data_folder or not data_folder.exists():
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Invalid Directory"),
                                    QCoreApplication.translate("Application", f"Could not find {GAME_DATA_FOLDER} folder."))
            return

        self.game_root_dir = data_folder
        full_folder = data_folder.joinpath(*AUDIO_SUBPATH)

        if not full_folder.exists():
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Invalid Directory"),
                                    QCoreApplication.translate("Application", "Could not find audio folder at:\n%1").replace("%1", str(full_folder)))
            return

        self.language_folders = {}
        language_mapping = LANGUAGE_FOLDERS

        pck_files = list(full_folder.glob("*.pck"))
        if pck_files:
            self.language_folders["Full"] = {
                "path": full_folder,
                "friendly_name": AUDIO_ROOT_FRIENDLY_NAME,
                "pck_count": len(pck_files),
            }

        for subfolder in full_folder.iterdir():
            if subfolder.is_dir() and subfolder.name in language_mapping:
                pck_files = list(subfolder.glob("*.pck"))
                if pck_files:
                    self.language_folders[subfolder.name] = {
                        "path": subfolder,
                        "friendly_name": language_mapping[subfolder.name],
                        "pck_count": len(pck_files),
                    }

        persistent_full = Path(str(full_folder).replace("StreamingAssets", "Persistent"))
        if persistent_full.exists():
            for subfolder in persistent_full.iterdir():
                if subfolder.is_dir() and subfolder.name in language_mapping and subfolder.name not in self.language_folders:
                    pck_files = list(subfolder.glob("*.pck"))
                    if pck_files:
                        self.language_folders[subfolder.name] = {
                            "path": subfolder,
                            "friendly_name": language_mapping[subfolder.name],
                            "pck_count": len(pck_files),
                        }
                        print(f"[ZZAR] Found language folder in Persistent: {subfolder.name} ({len(pck_files)} PCKs)")

        if not self.language_folders:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "No Audio Files"),
                                    QCoreApplication.translate("Application", "No PCK files found in:\n%1").replace("%1", str(full_folder)))
            return

        sorted_folders = sorted(self.language_folders.keys(),
                                key=lambda x: (0, "") if x == "Full" else (1, str(SUBFOLDER_SORT_PRIORITY.get(x, 99)).zfill(3) + x))

        tabs = []
        for folder_name in sorted_folders:
            info = self.language_folders[folder_name]
            tabs.append(f"{info['friendly_name']} ({info['pck_count']})")

        self.languageTabsReady.emit(tabs)

        self._check_missing_streaming_pcks(full_folder)

        self._load_language_tab(0)

    def _check_missing_streaming_pcks(self, full_folder):
        thread = threading.Thread(
            target=self._check_missing_streaming_threaded,
            args=(full_folder,),
            daemon=True,
        )
        thread.start()

    def _check_missing_streaming_threaded(self, full_folder):
        try:
            soundbank_files = sorted(full_folder.glob(SOUNDBANK_PCK_GLOB))
            streamed_files = sorted(full_folder.glob(STREAMED_PCK_GLOB))

            print(f"[File Check] Found {len(soundbank_files)} soundbank PCK(s), "
                  f"{len(streamed_files)} streamed PCK(s) in {full_folder.name}/")

            if not soundbank_files:
                print("[File Check] No soundbank files found, skipping check")
                return

            if not streamed_files:
                print("[File Check] WARNING: Missing all streamed PCK files!")
                QMetaObject.invokeMethod(
                    self, "_emitStreamingAlert",
                    Qt.QueuedConnection,
                    Q_ARG(str, QCoreApplication.translate("Application", "Missing Streaming Audio Files")),
                    Q_ARG(str,
                        QCoreApplication.translate("Application", "No streamed PCK files were found in the game's audio folder.\n\n"
                        "This means your game installation is incomplete or corrupted. "
                        "Audio mods may not work correctly without these files.\n\n"
                        "Please repair your game files through the game launcher.")
                    ),
                )
                return

            streamed_names = {f.name for f in streamed_files}

            missing_pairs = []
            for sb_file in soundbank_files:
                suffix = sb_file.name.replace(SOUNDBANK_PCK_PREFIX, "", 1)
                expected_streamed = f"{STREAMED_PCK_PREFIX}{suffix}"
                if expected_streamed not in streamed_names:
                    missing_pairs.append((sb_file.name, expected_streamed))
                    print(f"[File Check] WARNING: {sb_file.name} has no matching {expected_streamed}")

            empty_pcks = []
            corrupt_pcks = []
            total_streaming_wems = 0

            for streamed_pck in streamed_files:
                try:
                    file_size = streamed_pck.stat().st_size
                    if file_size < 16:
                        empty_pcks.append(streamed_pck.name)
                        print(f"[File Check] WARNING: {streamed_pck.name} is empty ({file_size} bytes)")
                        continue

                    si = PCKIndexer(str(streamed_pck))
                    si.build_index()
                    wem_count = len(si.index_data["sounds"]) + len(si.index_data["externals"])
                    total_streaming_wems += wem_count

                    if wem_count == 0:
                        empty_pcks.append(streamed_pck.name)
                        print(f"[File Check] WARNING: {streamed_pck.name} contains 0 WEM files")
                    else:
                        print(f"[File Check] {streamed_pck.name}: {wem_count} WEM(s)")

                except Exception as e:
                    corrupt_pcks.append(streamed_pck.name)
                    print(f"[File Check] ERROR: {streamed_pck.name} could not be parsed: {e}")

            print(f"[File Check] Total streaming WEMs: {total_streaming_wems}")

            problems = []
            if missing_pairs:
                problems.append(
                    f"{len(missing_pairs)} SoundBank PCK(s) have no matching Streamed PCK:\n"
                    + "\n".join(f"  - {sb} (missing {st})" for sb, st in missing_pairs[:10])
                    + (f"\n  ... and {len(missing_pairs) - 10} more" if len(missing_pairs) > 10 else "")
                )
            if empty_pcks:
                problems.append(f"{len(empty_pcks)} Streamed PCK file(s) are empty or contain no audio:\n"
                                + "\n".join(f"  - {name}" for name in empty_pcks[:10])
                                + (f"\n  ... and {len(empty_pcks) - 10} more" if len(empty_pcks) > 10 else ""))
            if corrupt_pcks:
                problems.append(f"{len(corrupt_pcks)} Streamed PCK file(s) are corrupted:\n"
                                + "\n".join(f"  - {name}" for name in corrupt_pcks[:10])
                                + (f"\n  ... and {len(corrupt_pcks) - 10} more" if len(corrupt_pcks) > 10 else ""))

            if problems:
                detail = "\n\n".join(problems)
                print(f"[File Check] WARNING: Issues found with streaming PCK files")
                QMetaObject.invokeMethod(
                    self, "_emitStreamingAlert",
                    Qt.QueuedConnection,
                    Q_ARG(str, QCoreApplication.translate("Application", "Missing Streaming Audio Files")),
                    Q_ARG(str,
                        detail + "\n\n" +
                        QCoreApplication.translate("Application", "Your game installation may be incomplete or corrupted. "
                        "Some audio mods may not work correctly without these files.\n\n"
                        "Please repair your game files through the game launcher.")
                    ),
                )
            else:
                print(f"[File Check] All {len(streamed_files)} Streamed PCK files look healthy - all clear")

        except Exception as e:
            print(f"[File Check] Error during check: {e}")

    @pyqtSlot(str, str)
    def _emitStreamingAlert(self, title, message):
        self.alertDialogRequested.emit(title, message, "")

    @pyqtSlot(int)
    def onLanguageTabChanged(self, index):

        self._load_language_tab(index)

    def _load_language_tab(self, index):

        sorted_folders = sorted(self.language_folders.keys(),
                                key=lambda x: (0, "") if x == "Full" else (1, str(SUBFOLDER_SORT_PRIORITY.get(x, 99)).zfill(3) + x))
        if index < 0 or index >= len(sorted_folders):
            return

        folder_name = sorted_folders[index]
        self.current_language_folder = folder_name
        folder_path = self.language_folders[folder_name]["path"]
        self._load_pck_files(folder_path)

    def _load_pck_files(self, directory):

        directory = Path(directory)
        dir_key = str(directory)

        if dir_key == str(self._current_directory) and self.index_ready:
            return

        self._current_directory = directory

        self.treeCleared.emit()

        if dir_key in self._tree_cache:
            cached = self._tree_cache[dir_key]
            self._item_data = dict(cached["item_data"])
            self._pck_loaded = dict(cached["pck_loaded"])
            self._bnk_loaded = dict(cached["bnk_loaded"])
            self.treeItemsReady.emit(cached["items"])

            if dir_key in self._index_cache:
                self.file_id_index = self._index_cache[dir_key]
                self.index_ready = True
                self.statusUpdate.emit(QCoreApplication.translate("Application", "Index ready - %1 unique file IDs").replace("%1", str(len(self.file_id_index))))
            else:
                self._build_file_index(cached["pck_files"])

            return

        self._item_data.clear()
        self._pck_loaded.clear()
        self._bnk_loaded.clear()

        pck_files = sorted(directory.glob("*.pck"))
        if not pck_files:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "No PCK files found"))
            return

        items = []
        for pck_file in pck_files:

            if self.merge_wem_enabled and pck_file.name.startswith(STREAMED_PCK_PREFIX):
                continue

            is_language_folder = self.current_language_folder not in ["Full", "Common"]
            if self.hide_useless_pck_enabled and is_language_folder:
                if not pck_file.name.startswith(SOUNDBANK_PCK_PREFIX):
                    continue

            pck_path = str(pck_file)
            item = {
                "fileName": pck_file.name,
                "itemId": "",
                "fileSize": "",
                "duration": "",
                "itemType": "PCK",
                "tags": "",
                "hasChildren": True,
                "depth": 0,
                "pckPath": pck_path,
                "isModified": False,
            }
            items.append(item)

            self._item_data[f"pck:{pck_path}"] = {
                "type": "pck",
                "path": pck_path,
            }

        self._tree_cache[dir_key] = {
            "items": items,
            "item_data": dict(self._item_data),
            "pck_loaded": dict(self._pck_loaded),
            "bnk_loaded": dict(self._bnk_loaded),
            "pck_files": pck_files,
        }

        self.treeItemsReady.emit(items)
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Found %1 PCK files - building index...").replace("%1", str(len(items))))

        self._build_file_index(pck_files)

    @pyqtSlot(str, str)
    def onTreeItemExpanded(self, item_id, item_type):

        if item_type == "PCK":

            pass
        elif item_type == "BNK":
            self._expand_bnk_item(item_id)

    @pyqtSlot(str, str)
    def onItemCollapsed(self, item_id, item_type):

        if item_type == "PCK":

            self._pck_loaded.pop(item_id, None)

            to_remove = [k for k in self._bnk_loaded if k.startswith(item_id + ":")]
            for k in to_remove:
                self._bnk_loaded.pop(k, None)
        elif item_type == "BNK":

            to_remove = [k for k in self._bnk_loaded if k.endswith(f":{item_id}")]
            for k in to_remove:
                self._bnk_loaded.pop(k, None)

    @pyqtSlot(str)
    def expandPckItem(self, pck_path):
        print(f"[ExpandPCK] expandPckItem called: {pck_path}")

        if pck_path in self._pck_loaded:
            print(f"[ExpandPCK] PCK already loaded, returning")
            return

        self._pck_loaded[pck_path] = True
        print(f"[ExpandPCK] Marking PCK as loaded and indexing")
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Indexing %1...").replace("%1", Path(pck_path).name))

        try:
            indexer = PCKIndexer(pck_path)
            indexer.build_index()

            items = []

            for bnk_info in indexer.index_data["banks"]:
                bnk_id = str(bnk_info["id"])

                if self.hide_empty_bnk_enabled:
                    try:
                        bnk_bytes = indexer.extract_single_file(
                            bnk_info["id"], "bnk", bnk_info["lang_id"]
                        )
                        bnk_idx = BNKIndexer(bnk_bytes)
                        bnk_idx.parse_didx()
                        if bnk_idx.get_wem_count() == 0:
                            continue
                    except Exception:
                        pass

                data_key = f"bnk:{pck_path}:{bnk_id}"
                self._item_data[data_key] = {
                    "type": "bnk",
                    "file_id": bnk_info["id"],
                    "lang_id": bnk_info["lang_id"],
                    "pck_path": pck_path,
                    "metadata": bnk_info,
                }

                items.append({
                    "fileName": f"{bnk_id}.bnk",
                    "itemId": bnk_id,
                    "fileSize": self._format_size(bnk_info["size"]),
                    "duration": "",
                    "itemType": "BNK",
                    "tags": "",
                    "hasChildren": True,
                    "depth": 1,
                    "pckPath": pck_path,
                    "isModified": False,
                    "parentPck": pck_path,
                })

            if not self.merge_wem_enabled:
                for wem_info in indexer.index_data["sounds"] + indexer.index_data["externals"]:
                    wem_id = str(wem_info["id"])
                    data_key = f"wem:{pck_path}:{wem_id}"
                    self._item_data[data_key] = {
                        "type": "wem",
                        "file_id": wem_info["id"],
                        "lang_id": wem_info["lang_id"],
                        "pck_path": pck_path,
                        "metadata": wem_info,
                    }

                    tag_text = ""
                    duration_text = ""
                    try:
                        wem_bytes = indexer.extract_single_file(
                            wem_info["id"], "wem", wem_info["lang_id"]
                        )
                        duration_text = self._get_wem_duration(wem_bytes)
                        sound_info = self.sound_db.get_sound_info(wem_bytes)
                        if sound_info:
                            tag_text = sound_info["name"]
                            if sound_info["tags"]:
                                tag_text += f" [{', '.join(sound_info['tags'])}]"
                    except Exception:
                        pass

                    items.append({
                        "fileName": f"{wem_id}.wem",
                        "itemId": wem_id,
                        "fileSize": self._format_size(wem_info["size"]),
                        "duration": duration_text,
                        "itemType": "WEM",
                        "tags": tag_text,
                        "hasChildren": False,
                        "depth": 1,
                        "pckPath": pck_path,
                        "isModified": False,
                        "parentPck": pck_path,
                    })

            print(f"[ExpandPCK] Emitting {len(items)} items via treeItemsReady")
            self.treeItemsReady.emit(items)
            self.statusUpdate.emit(
                QCoreApplication.translate("Application", "Loaded %1 files from %2").replace("%1", str(len(items))).replace("%2", Path(pck_path).name)
            )
            print(f"[ExpandPCK] expandPckItem completed successfully")

        except Exception as e:
            print(f"[ExpandPCK] Error during expansion: {e}")
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Error loading %1: %2").replace("%1", Path(pck_path).name).replace("%2", str(e)))

    def _expand_bnk_item(self, bnk_id):

        bnk_data = None
        bnk_key = None
        for key, data in self._item_data.items():
            if key.startswith("bnk:") and str(data.get("file_id")) == bnk_id:
                bnk_data = data
                bnk_key = key
                break

        if not bnk_data:
            return

        load_key = f"{bnk_data['pck_path']}:{bnk_id}"
        if load_key in self._bnk_loaded:
            return
        self._bnk_loaded[load_key] = True

        try:
            indexer = PCKIndexer(bnk_data["pck_path"])
            indexer.build_index()
            bnk_bytes = indexer.extract_single_file(
                bnk_data["file_id"], "bnk", bnk_data["lang_id"]
            )

            bnk_indexer = BNKIndexer(bnk_bytes)
            wem_list = bnk_indexer.parse_didx()

            streaming_wem_data = {}
            if self.merge_wem_enabled:
                pck_dir = Path(bnk_data["pck_path"]).parent
                for streamed_pck in pck_dir.glob(STREAMED_PCK_GLOB):
                    try:
                        si = PCKIndexer(str(streamed_pck))
                        si.build_index()
                        for sw in si.index_data["sounds"] + si.index_data["externals"]:
                            streaming_wem_data[sw["id"]] = (sw, str(streamed_pck))
                    except Exception:
                        pass

            items = []
            for wem_info in wem_list:
                wem_id = wem_info["wem_id"]
                streaming = streaming_wem_data.get(wem_id) if self.merge_wem_enabled else None

                display_size = wem_info["size"]
                type_label = "WEM (embedded)"
                if streaming:
                    sw, sp = streaming
                    if sw["size"] > wem_info["size"]:
                        display_size = sw["size"]
                        type_label = "WEM (merged)"

                data_key = f"wem_embedded:{bnk_data['pck_path']}:{bnk_data['file_id']}:{wem_id}"
                item_meta = {
                    "type": "wem_embedded",
                    "wem_id": wem_id,
                    "bnk_id": bnk_data["file_id"],
                    "bnk_bytes": bnk_bytes,
                    "pck_path": bnk_data["pck_path"],
                    "lang_id": bnk_data.get("lang_id", 0),
                }
                if streaming:
                    sw, sp = streaming
                    item_meta["streaming_wem"] = sw
                    item_meta["streaming_pck_path"] = sp

                self._item_data[data_key] = item_meta

                tag_text = ""
                duration_text = ""
                try:
                    if streaming:

                        sw, sp = streaming
                        streaming_indexer = PCKIndexer(sp)
                        streaming_indexer.build_index()
                        wem_bytes = streaming_indexer.extract_single_file(sw["id"], "wem", sw["lang_id"])
                    else:

                        wem_bytes = bnk_indexer.extract_wem(wem_id)

                    duration_text = self._get_wem_duration(wem_bytes)
                    sound_info = self.sound_db.get_sound_info(wem_bytes)
                    if sound_info:
                        tag_text = sound_info["name"]
                        if sound_info["tags"]:
                            tag_text += f" [{', '.join(sound_info['tags'])}]"
                except Exception:
                    pass

                items.append({
                    "fileName": f"{wem_id}.wem",
                    "itemId": str(wem_id),
                    "fileSize": self._format_size(display_size),
                    "duration": duration_text,
                    "itemType": type_label,
                    "tags": tag_text,
                    "hasChildren": False,
                    "depth": 2,
                    "pckPath": bnk_data["pck_path"],
                    "isModified": False,
                    "parentBnk": str(bnk_data["file_id"]),
                })

            self.treeItemsReady.emit(items)

        except Exception as e:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Error loading BNK %1: %2").replace("%1", str(bnk_id)).replace("%2", str(e)))

    @pyqtSlot(str, str, str)
    def onTreeItemDoubleClicked(self, item_id, item_type, pck_path):
        print(f"[PlayButton] onTreeItemDoubleClicked called: id={item_id}, type={item_type}, pck={pck_path}")

        meta = self._find_item_meta(item_id, item_type, pck_path)
        if not meta:
            print(f"[PlayButton] No meta found in _item_data, checking match metadata")

            meta_key = f"{item_id}:{pck_path}"
            if meta_key in self._match_metadata:
                meta = self._match_metadata[meta_key]
                print(f"[PlayButton] Found in match metadata: {meta}")
            else:
                print(f"[PlayButton] Not in match metadata either")

                if not pck_path or not Path(pck_path).exists():
                    print(f"[PlayButton] Invalid pck_path: {pck_path}")
                    return

                meta = {
                    "type": item_type or "wem",
                    "pck_path": pck_path,
                    "file_id": item_id,
                    "lang_id": "0",
                }
                print(f"[PlayButton] Created minimal meta from params: {meta}")

        print(f"[PlayButton] Playing audio, type={meta.get('type')}")
        if meta["type"] == "wem":
            self._play_wem_from_pck(meta)
        elif meta["type"] == "wem_embedded":
            self._play_wem_from_bnk(meta)

    def _play_wem_from_pck(self, meta):

        try:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Loading audio..."))
            indexer = PCKIndexer(meta["pck_path"])
            indexer.build_index()
            wem_bytes = indexer.extract_single_file(
                meta["file_id"], "wem", meta["lang_id"]
            )

            cache_key = self.cache_manager.get_cache_key(
                meta["pck_path"], meta["file_id"], "wem"
            )
            self.audio_player.play_wem(wem_bytes, cache_key)

            self.nowPlayingUpdate.emit(QCoreApplication.translate("Application", "Playing: %1.wem").replace("%1", str(meta['file_id'])))
            self.playbackStateUpdate.emit(True, False, True)
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Playing %1.wem").replace("%1", str(meta['file_id'])))

        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Playback Error"), str(e))

    def _play_wem_from_bnk(self, meta):

        try:
            if "streaming_wem" in meta and "streaming_pck_path" in meta:
                sw = meta["streaming_wem"]
                wem_id = sw["id"]
                indexer = PCKIndexer(meta["streaming_pck_path"])
                indexer.build_index()
                wem_bytes = indexer.extract_single_file(wem_id, "wem", sw["lang_id"])
                cache_key = self.cache_manager.get_cache_key(
                    meta["pck_path"], wem_id, "wem_streaming"
                )
            else:
                if "bnk_bytes" not in meta:
                    self.statusUpdate.emit(QCoreApplication.translate("Application", "Extracting BNK from PCK..."))
                    indexer = PCKIndexer(meta["pck_path"])
                    indexer.build_index()
                    bnk_bytes = indexer.extract_single_file(
                        meta["bnk_id"], "bnk", meta.get("lang_id", 0)
                    )
                else:
                    bnk_bytes = meta["bnk_bytes"]

                bnk_indexer = BNKIndexer(bnk_bytes)
                bnk_indexer.parse_didx()
                wem_id = meta.get("wem_id") or meta.get("file_id")
                wem_bytes = bnk_indexer.extract_wem(wem_id)
                cache_key = self.cache_manager.get_cache_key(
                    meta["pck_path"], f"{meta['bnk_id']}_{wem_id}", "wem_bnk"
                )

            self.audio_player.play_wem(wem_bytes, cache_key)
            self.nowPlayingUpdate.emit(
                QCoreApplication.translate("Application", "Playing: %1.wem (from BNK %2)").replace("%1", str(wem_id)).replace("%2", str(meta.get('bnk_id', '')))
            )
            self.playbackStateUpdate.emit(True, False, True)
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Playing %1.wem from BNK").replace("%1", str(wem_id)))

        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Playback Error"), str(e))

    @pyqtSlot()
    def play(self):
        self.audio_player.play()

    @pyqtSlot()
    def pause(self):
        self.audio_player.pause()

    @pyqtSlot()
    def stop(self):
        self.audio_player.stop()
        self.nowPlayingUpdate.emit(QCoreApplication.translate("Application", "Not playing"))
        self.progressUpdate.emit(0.0, "00:00 / 00:00")
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Stopped"))

    @pyqtSlot(str)
    def playUrl(self, url):
        try:
            self.audio_player.play_url(url)
        except Exception as e:
            self.errorOccurred.emit("Preview Error", str(e))

    @pyqtSlot(int)
    def setVolume(self, value):
        self.audio_player.set_volume(value)

    @pyqtSlot(float)
    def seekTo(self, position):

        if self._playback_duration > 0:
            self.audio_player.set_position(int(position * self._playback_duration))

    def _on_playback_state_changed(self, state):
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Playback: %1").replace("%1", str(state)))
        has_audio = self.audio_player.current_file is not None
        if state == "playing":
            self.playbackStateUpdate.emit(True, False, True)
        elif state == "paused":
            self.playbackStateUpdate.emit(False, True, True)
        elif state == "stopped":
            self.playbackStateUpdate.emit(False, False, has_audio)

    def _on_position_changed(self, position):
        if self._playback_duration > 0:
            norm = position / self._playback_duration
            time_str = f"{self._format_time(position)} / {self._format_time(self._playback_duration)}"
            self.progressUpdate.emit(norm, time_str)

    def _on_duration_changed(self, duration):
        self._playback_duration = duration

    def _on_playback_error(self, error):
        self.errorOccurred.emit(QCoreApplication.translate("Application", "Playback Error"), error)

    @pyqtSlot(bool)
    def setMergeWem(self, enabled):

        if self.merge_wem_enabled != enabled:
            self.merge_wem_enabled = enabled
            self._invalidate_caches()

            if self.current_language_folder:
                folder_path = self.language_folders[self.current_language_folder]["path"]
                self._load_pck_files(folder_path)
                state = "enabled" if enabled else "disabled"
                self.statusUpdate.emit(QCoreApplication.translate("Application", "Merge mode %1").replace("%1", state))

    @pyqtSlot(bool)
    def setHideUselessPck(self, enabled):

        if self.hide_useless_pck_enabled != enabled:
            self.hide_useless_pck_enabled = enabled
            self._invalidate_caches()

            if self.current_language_folder:
                folder_path = self.language_folders[self.current_language_folder]["path"]
                self._load_pck_files(folder_path)
                state = "enabled" if enabled else "disabled"
                self.statusUpdate.emit(QCoreApplication.translate("Application", "Hide useless PCK %1").replace("%1", state))

    @pyqtSlot(bool)
    def setHideEmptyBnk(self, enabled):
        if self.hide_empty_bnk_enabled != enabled:
            self.hide_empty_bnk_enabled = enabled
            self.hideEmptyBnkChanged.emit(enabled)
            self._invalidate_caches()

            if self.current_language_folder:
                folder_path = self.language_folders[self.current_language_folder]["path"]
                self._load_pck_files(folder_path)
                state = "enabled" if enabled else "disabled"
                self.statusUpdate.emit(QCoreApplication.translate("Application", "Hide empty BNK %1").replace("%1", state))

            try:
                if self.settings_file.exists():
                    with open(self.settings_file, "r") as f:
                        settings = json.load(f)
                else:
                    settings = {}
                settings["hide_empty_bnk"] = enabled
                self.settings_file.parent.mkdir(parents=True, exist_ok=True)
                with open(self.settings_file, "w") as f:
                    json.dump(settings, f, indent=2)
            except Exception as e:
                print(f"[Audio Browser] Error saving hide_empty_bnk setting: {e}")

    @pyqtSlot(bool)
    def setNormalizeAudio(self, enabled):
        self.normalize_audio_enabled = enabled
        self.normalizeAudioChanged.emit(enabled)
        try:
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)
            else:
                settings = {}
            settings["normalize_audio"] = enabled
            self.settings_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)
        except Exception as e:
            print(f"[Audio Browser] Error saving normalize setting: {e}")

    @pyqtSlot(str)
    def search(self, query):

        query = query.strip()
        if not query:
            return

        if not self.index_ready:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Index still building... Please wait"))
            return

        matches = []

        def _make_match(fid, name, tags, loc):
            return {
                "fileId": str(fid),
                "name": name,
                "tags": tags,
                "type": loc["type"],
                "pckPath": loc["pck_path"],
                "bnkId": str(loc.get("bnk_id", "")),
            }

        if query.isdigit():
            file_id = int(query)
            if file_id in self.file_id_index:
                for loc in self.file_id_index[file_id]:
                    matches.append(_make_match(file_id, f"File {file_id}", "", loc))

        if not matches:
            tag_results = self.sound_db.search_by_tag(query)
            name_results = self.sound_db.search_by_name(query)
            all_results = {**tag_results, **name_results}

            for sound_hash, info in all_results.items():
                for file_id in info.get("file_ids", []):
                    if file_id in self.file_id_index:
                        tag_str = ", ".join(info.get("tags", []))
                        for loc in self.file_id_index[file_id]:
                            matches.append(_make_match(
                                file_id, info.get("name", f"File {file_id}"), tag_str, loc))

        if not matches:
            query_lower = query.lower()
            for file_id in self.file_id_index:
                if query_lower in str(file_id):
                    for loc in self.file_id_index[file_id][:1]:
                        matches.append(_make_match(file_id, f"File {file_id}", "", loc))
                    if len(matches) >= 100:
                        break

        if self.merge_wem_enabled and matches:
            matches = [m for m in matches
                       if not Path(m["pckPath"]).name.startswith(STREAMED_PCK_PREFIX)]

        if matches:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Found %1 match(es) for '%2'").replace("%1", str(len(matches))).replace("%2", query))
            self.searchResultsReady.emit(query, matches)
        else:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "No files found matching '%1'").replace("%1", query))

    @pyqtSlot(str, str, str, str)
    def navigateToSearchResult(self, file_id, item_type, pck_path, bnk_id):
        print(f"[Navigate] navigateToSearchResult called: id={file_id}, type={item_type}, pck={pck_path}, bnk={bnk_id}")

        if not pck_path:
            print(f"[Navigate] No pck_path provided")
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Cannot navigate to file %1").replace("%1", str(file_id)))
            return

        if self.merge_wem_enabled and Path(pck_path).name.startswith(STREAMED_PCK_PREFIX):
            print(f"[Navigate] Streamed_SFX detected with merge enabled, looking up file_id_index")
            file_id_int = int(file_id) if file_id.isdigit() else file_id
            locs = self.file_id_index.get(file_id_int, [])

            alt_loc = None
            for loc in locs:
                if loc.get("type") == "wem_embedded" and not Path(loc["pck_path"]).name.startswith(STREAMED_PCK_PREFIX):
                    alt_loc = loc
                    break
            if alt_loc:
                pck_path = alt_loc["pck_path"]
                bnk_id = str(alt_loc.get("bnk_id", ""))
                item_type = "wem_embedded"
                print(f"[Navigate] Redirected to: pck={pck_path}, bnk={bnk_id}, type={item_type}")
            else:
                print(f"[Navigate] No alternative location found in file_id_index")

        needs_delay = False
        if pck_path not in self._pck_loaded:
            print(f"[Navigate] PCK not loaded, expanding: {pck_path}")
            self.expandPckItem(pck_path)
            needs_delay = True

        if bnk_id and item_type == "wem_embedded":
            load_key = f"{pck_path}:{bnk_id}"
            if load_key not in self._bnk_loaded:
                print(f"[Navigate] BNK not loaded, expanding: {bnk_id}")
                self._expand_bnk_item(bnk_id)
                needs_delay = True

        if needs_delay:
            print(f"[Navigate] Delaying navigation by 500ms to let tree update")
            from PyQt5.QtCore import QTimer
            QTimer.singleShot(500, lambda: self._do_navigate(file_id, pck_path, bnk_id))
        else:
            self._do_navigate(file_id, pck_path, bnk_id)

    def _do_navigate(self, file_id, pck_path, bnk_id=""):
        print(f"[Navigate] Emitting navigateToItem: {file_id}, {pck_path}, bnk={bnk_id}")
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Navigated to file %1 in %2").replace("%1", str(file_id)).replace("%2", Path(pck_path).name))
        self.navigateToItem.emit(file_id, pck_path, str(bnk_id) if bnk_id else "")

    @pyqtSlot()
    def clearSearch(self):
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Ready"))

    @pyqtSlot(str, str, str, bool, str)
    def replaceWithCustomAudio(self, item_id, item_type, pck_path, normalize=True, parent_bnk=""):

        meta = self._find_item_meta(item_id, item_type, pck_path, parent_bnk)
        if not meta:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Could not find item data"))
            return

        from .native_dialogs import NativeDialogs
        filename = NativeDialogs.get_open_file(
            "Select Custom Audio",
            str(Path.home()),
            "Audio Files (*.mp3 *.wav *.wem *.flac *.ogg *.m4a);;All Files (*)",
        )
        if not filename:
            return

        self.loadingStarted.emit(QCoreApplication.translate("Application", "Converting audio..."))
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Processing your custom audio..."))

        self._replace_worker = ReplaceAudioWorker(filename, meta, normalize, self.mod_manager)
        self._replace_worker.progress.connect(self._on_replace_progress)
        self._replace_worker.finished.connect(self._on_replace_finished)
        self._replace_worker.start()

    def _on_replace_progress(self, message):
        self.loadingStarted.emit(message)
        self.statusUpdate.emit(message)

    def _on_replace_finished(self, success, message):
        self.loadingFinished.emit()
        self._replace_worker = None

        if success:
            self.statusUpdate.emit(message)
            self._emit_changes_count()
        elif message.startswith("WWISE:"):
            self.wwiseErrorDialog.emit(
                QCoreApplication.translate("Application", "Wwise Required"),
                message[6:]
            )
        else:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Error: Failed to stage replacement"))
            self.errorOccurred.emit(
                QCoreApplication.translate("Application", "Error"),
                QCoreApplication.translate("Application", "Failed to stage replacement:\n%1").replace("%1", message)
            )

    @pyqtSlot(str, str, str, str)
    def exportAsWav(self, item_id, item_type, pck_path, parent_bnk=""):

        meta = self._find_item_meta(item_id, item_type, pck_path, parent_bnk)
        if not meta:
            return

        file_id = meta.get("file_id", meta.get("wem_id"))

        from .native_dialogs import NativeDialogs
        filename = NativeDialogs.get_save_file(
            "Export as WAV", str(Path.home() / f"{file_id}.wav"), "WAV Files (*.wav)"
        )
        if not filename:
            return

        try:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Exporting audio..."))

            if meta["type"] == "wem":
                indexer = PCKIndexer(meta["pck_path"])
                indexer.build_index()
                wem_bytes = indexer.extract_single_file(meta["file_id"], "wem", meta["lang_id"])
            else:

                if "streaming_wem" in meta and "streaming_pck_path" in meta:
                    sw = meta["streaming_wem"]
                    indexer = PCKIndexer(meta["streaming_pck_path"])
                    indexer.build_index()
                    wem_bytes = indexer.extract_single_file(sw["id"], "wem", sw["lang_id"])
                else:
                    bnk_indexer = BNKIndexer(meta["bnk_bytes"])
                    bnk_indexer.parse_didx()
                    wem_bytes = bnk_indexer.extract_wem(meta["wem_id"])

            from ZZAR import get_temp_dir
            temp_wem = Path(tempfile.mktemp(suffix=".wem", dir=str(get_temp_dir())))
            temp_wem.write_bytes(wem_bytes)

            converter = AudioConverter()
            converter.wem_to_wav(str(temp_wem), filename)
            temp_wem.unlink()

            self.statusUpdate.emit(QCoreApplication.translate("Application", "Exported to %1").replace("%1", Path(filename).name))

        except Exception as e:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Export failed"))
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Export Error"), str(e))

    @pyqtSlot(str, str, str, str)
    def muteAudio(self, item_id, item_type, pck_path, parent_bnk=""):

        meta = self._find_item_meta(item_id, item_type, pck_path, parent_bnk)
        if not meta:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Could not find item data"))
            return

        try:
            pck_file_path = Path(meta["pck_path"])
            pck_filename = pck_file_path.name

            self.statusUpdate.emit(QCoreApplication.translate("Application", "Creating silent audio replacement..."))

            if meta["type"] == "wem":
                file_id = meta["file_id"]
                lang_id = meta["lang_id"]
                bnk_id = None
            else:
                file_id = meta["wem_id"]
                lang_id = meta.get("lang_id", 0)
                bnk_id = meta["bnk_id"]

                print(f"[DEBUG] muteAudio: Detected lang_id={lang_id} for pck: {pck_filename}")

            import wave
            import struct

            from ZZAR import get_temp_dir
            silent_wav = Path(tempfile.mktemp(suffix=".wav", dir=str(get_temp_dir())))
            sample_rate = 48000
            duration_samples = int(0.1 * sample_rate)

            with wave.open(str(silent_wav), 'w') as wav_file:
                wav_file.setnchannels(2)
                wav_file.setsampwidth(2)
                wav_file.setframerate(sample_rate)

                silent_data = struct.pack('<h', 0) * (duration_samples * 2)
                wav_file.writeframes(silent_data)

            self.statusUpdate.emit(QCoreApplication.translate("Application", "Converting silent audio to WEM..."))
            converter = AudioConverter()
            try:
                wem_file = converter.wav_to_wem(str(silent_wav))
            except RuntimeError as e:
                error_msg = str(e)

                if "Wwise is not installed" in error_msg or "Wwise Not" in error_msg:
                    self.wwiseErrorDialog.emit(QCoreApplication.translate("Application", "Wwise Required"), error_msg)
                    silent_wav.unlink()
                    return
                else:
                    raise
            finally:

                if silent_wav.exists():
                    silent_wav.unlink()

            self.mod_manager.add_replacement(
                pck_filename, file_id, str(wem_file),
                "wem" if bnk_id is None else "bnk",
                lang_id, bnk_id,
            )

            streaming_path = pck_file_path.parent
            persistent_path = Path(str(streaming_path).replace("StreamingAssets", "Persistent"))
            self.mod_manager.set_persistent_path(str(persistent_path))

            self.statusUpdate.emit(QCoreApplication.translate("Application", "Audio muted: %1 (ID: %2) - Click 'Apply Changes' to activate").replace("%1", pck_filename).replace("%2", str(file_id)))
            self._emit_changes_count()

        except Exception as e:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Error: Failed to mute audio"))
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Failed to mute audio:\n%1").replace("%1", str(e)))
            import traceback
            traceback.print_exc()

    def _get_user_replacements(self):
        all_replacements = self.mod_manager.get_all_replacements()
        filtered = {}
        for pck_name, files in all_replacements.items():
            user_files = {fid: info for fid, info in files.items()
                          if info.get('source') != 'mod_manager'}
            if user_files:
                filtered[pck_name] = user_files
        return filtered

    def _emit_changes_count(self):
        replacements = self._get_user_replacements()
        count = sum(len(files) for files in replacements.values())
        self.changesCountUpdated.emit(count)

    @pyqtSlot()

    def tr(self, text):
        from PyQt5.QtCore import QCoreApplication
        return QCoreApplication.translate("Application", text)

    def showChanges(self):

        replacements = self._get_user_replacements()
        if not replacements:
            self.alertDialogRequested.emit(QCoreApplication.translate("Application", "No Changes found"), QCoreApplication.translate("Application", "No audio replacements found.\n\nDid you even replace anything?."), f"../assets/{ASSETS_DIR}/EllenSleep.png")
            return

        changes = []
        for pck_filename, files in replacements.items():
            for tracker_key, info in files.items():
                display_file_id = tracker_key.split('|')[1] if '|' in tracker_key else tracker_key

                if info['file_type'] == 'bnk' and info.get('bnk_id'):
                    display_type = f"WEM (in BNK {info['bnk_id']})"
                    item_type = "wem_embedded"
                    bnk_id = str(info['bnk_id'])
                else:
                    display_type = "WEM"
                    item_type = "wem"
                    bnk_id = ""

                tagged_name = ""
                try:
                    results = self.sound_db.search_by_id(int(display_file_id))
                    if results:
                        sound_info = list(results.values())[0]
                        tagged_name = sound_info.get("name", "")
                except Exception:
                    pass

                wem_path = info.get('wem_path', '')
                source_file = Path(wem_path).name if wem_path else ''

                changes.append({
                    "fileId": display_file_id,
                    "trackerKey": tracker_key,
                    "pckFile": pck_filename,
                    "fileType": display_type,
                    "itemType": item_type,
                    "bnkId": bnk_id,
                    "dateModified": info.get('date_modified', 'Unknown'),
                    "taggedName": tagged_name,
                    "sourceFile": source_file,
                    "wemPath": wem_path,
                })

        if not changes:
            self.alertDialogRequested.emit(QCoreApplication.translate("Application", "No Changes found"), QCoreApplication.translate("Application", "No manual audio replacements found.\n\nChanges from installed mods are managed in the Mod Manager."), f"../assets/{ASSETS_DIR}/EllenSleep.png")
            return

        self.changesReady.emit(changes)
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Showing %1 replacement(s)").replace("%1", str(len(changes))))

    @pyqtSlot()
    def applyAllChanges(self):

        replacements = self.mod_manager.get_all_replacements()
        if not replacements:

            if self.game_root_dir:
                try:
                    streaming_path = Path(self.game_root_dir).joinpath(*AUDIO_SUBPATH)
                    persistent_path = Path(str(streaming_path).replace("StreamingAssets", "Persistent"))

                    if persistent_path.exists():
                        self.statusUpdate.emit(QCoreApplication.translate("Application", "Cleaning up Persistent folder..."))

                        lang_folders_to_skip = set()
                        for lang_folder in persistent_path.iterdir():
                            if lang_folder.is_dir():
                                pck_count = len(list(lang_folder.glob("*.pck")))
                                if pck_count == 57:
                                    lang_folders_to_skip.add(lang_folder)
                                    print(f"[Audio Browser] Skipping language folder {lang_folder.name} (has 57 PCK files)")

                        cleaned_files = 0
                        for pck_file in persistent_path.rglob("*.pck"):

                            if any(lang_folder in pck_file.parents for lang_folder in lang_folders_to_skip):
                                continue

                            try:
                                pck_file.chmod(0o644)
                                pck_file.unlink()
                                cleaned_files += 1
                            except Exception as e:
                                print(f"[Audio Browser] Failed to delete {pck_file}: {e}")

                        if cleaned_files > 0:
                            self.statusUpdate.emit(QCoreApplication.translate("Application", "Cleaned up %1 modded PCK file(s) from Persistent folder").replace("%1", str(cleaned_files)))
                        else:
                            self.statusUpdate.emit(QCoreApplication.translate("Application", "No modded PCK files found in Persistent folder"))
                    else:
                        self.errorOccurred.emit(QCoreApplication.translate("Application", "No Changes"), QCoreApplication.translate("Application", "No changes to apply and no Persistent folder found."))
                except Exception as e:
                    self.errorOccurred.emit(QCoreApplication.translate("Application", "Cleanup Error"), QCoreApplication.translate("Application", "Failed to clean up Persistent folder:\n%1").replace("%1", str(e)))
            else:
                self.errorOccurred.emit(QCoreApplication.translate("Application", "No Changes"), QCoreApplication.translate("Application", "No changes to apply."))
            return

        if not self.game_root_dir:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "No Directory"), QCoreApplication.translate("Application", "Please select a game directory first."))
            return

        try:
            total_files = sum(len(files) for files in replacements.values())
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Applying %1 change(s)...").replace("%1", str(total_files)))

            for pck_filename, files in replacements.items():

                streaming_base = Path(self.game_root_dir).joinpath(*AUDIO_SUBPATH)
                pck_file_path = streaming_base / pck_filename

                if not pck_file_path.exists():
                    for subfolder in streaming_base.iterdir():
                        if subfolder.is_dir():
                            candidate = subfolder / pck_filename
                            if candidate.exists():
                                pck_file_path = candidate
                                break

                if not pck_file_path.exists():
                    self.statusUpdate.emit(QCoreApplication.translate("Application", "Warning: %1 not found, skipping").replace("%1", pck_filename))
                    continue

                streaming_path = pck_file_path.parent
                persistent_path = Path(str(streaming_path).replace("StreamingAssets", "Persistent"))
                persistent_path.mkdir(parents=True, exist_ok=True)
                self.mod_manager.set_persistent_path(str(persistent_path))

                self.statusUpdate.emit(QCoreApplication.translate("Application", "Creating modded %1...").replace("%1", pck_filename))
                output_pck = self.mod_manager.get_persistent_pck_path(pck_filename)
                output_pck.parent.mkdir(parents=True, exist_ok=True)

                if output_pck.exists():
                    import os, stat
                    os.chmod(str(output_pck), stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)

                packer = PCKPacker(str(pck_file_path), str(output_pck))
                packer.load_original_pck()

                print(f"[Apply] Packing {pck_filename}")
                print(f"[Apply] Original PCK: {pck_file_path}")
                print(f"[Apply] Language map: {packer.language_names}")

                self.statusUpdate.emit(QCoreApplication.translate("Application", "Adding %1 replacement(s) to %2...").replace("%1", str(len(files))).replace("%2", pck_filename))

                for file_id, repl_info in files.items():
                    repl_wem = Path(repl_info["wem_path"])
                    if not repl_wem.exists():
                        self.statusUpdate.emit(QCoreApplication.translate("Application", "Warning: %1 not found, skipping").replace("%1", repl_wem.name))
                        continue

                    print(f"[Apply] Replacing file_id={file_id}, lang_id={repl_info['lang_id']}, type={repl_info['file_type']}")

                    if repl_info["file_type"] == "wem":
                        packer.replace_file(int(file_id) if str(file_id).isdigit() else int(str(file_id), 16), str(repl_wem), repl_info["lang_id"])
                    else:
                        repl_bnk_id = repl_info.get("bnk_id")
                        if repl_bnk_id:
                            import shutil
                            from ZZAR import get_temp_dir
                            bnk_temp = Path(tempfile.mkdtemp(prefix="zzar_bnk_", dir=str(get_temp_dir())))
                            bnk_wem_dir = bnk_temp / f"{repl_bnk_id}_bnk"
                            bnk_wem_dir.mkdir(parents=True, exist_ok=True)
                            plain_wem_id = str(file_id).split('|')[-1] if '|' in str(file_id) else str(file_id)
                            shutil.copy(str(repl_wem), str(bnk_wem_dir / f"{plain_wem_id}.wem"))
                            packer.replace_bnk_wems(repl_bnk_id, str(bnk_wem_dir), repl_info["lang_id"])
                            shutil.rmtree(str(bnk_temp), ignore_errors=True)

                self.statusUpdate.emit(QCoreApplication.translate("Application", "Packing %1...").replace("%1", pck_filename))
                packer.pack(use_patching=False)
                packer.close()

                import os, stat
                os.chmod(str(output_pck), stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)

            self.statusUpdate.emit(QCoreApplication.translate("Application", "Successfully applied %1 change(s)!").replace("%1", str(total_files)))

        except Exception as e:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Failed to apply changes"))
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Failed to apply changes:\n%1").replace("%1", str(e)))
            import traceback
            traceback.print_exc()

    @pyqtSlot()
    def exportAsMod(self):

        replacements = self._get_user_replacements()
        if not replacements:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "No Replacements"),
                                    QCoreApplication.translate("Application", "No audio replacements found. Replace some audio files first."))
            return

        self.exportMetadataDialogReady.emit(self._imported_mod_metadata or {})

    @pyqtSlot()
    def browseThumbnail(self):

        from .native_dialogs import NativeDialogs
        filename = NativeDialogs.get_open_file(
            "Select Thumbnail Image",
            str(Path.home()),
            "Images (*.png *.jpg *.jpeg *.bmp);;All Files (*)",
        )
        if filename:
            self.thumbnailPathSelected.emit(filename)

    @pyqtSlot(str, str, str, str, str)
    def createModPackage(self, name, author, version, description, thumbnail_path):

        replacements = self._get_user_replacements()
        if not replacements:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "No Replacements"), QCoreApplication.translate("Application", "No audio replacements found."))
            return

        default_name = f"{name.replace(' ', '_')}_v{version}{MOD_FILE_EXT}"

        from .native_dialogs import NativeDialogs
        filename = NativeDialogs.get_save_file(
            "Save Mod Package",
            str(Path.home() / default_name),
            f"{MOD_FILE_EXT_UPPER} Mod Packages (*{MOD_FILE_EXT});;All Files (*)",
        )
        if not filename:
            return

        if not filename.endswith(MOD_FILE_EXT):
            filename += MOD_FILE_EXT

        try:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Creating mod package..."))
            mod_pkg = ModPackageManager(persistent_mod_manager=self.mod_manager)

            metadata = {
                "name": name,
                "author": author,
                "version": version,
                "description": description
            }

            thumb_path = thumbnail_path if thumbnail_path and thumbnail_path.strip() else None

            mod_pkg.create_mod_package(filename, metadata, replacements, thumb_path)
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Mod package created: %1").replace("%1", Path(filename).name))
        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Export Error"), QCoreApplication.translate("Application", "Failed to create mod package:\n%1").replace("%1", str(e)))

    @pyqtSlot(str, str)
    def removeChange(self, pck_file, tracker_key):
        display_id = tracker_key.split('|')[1] if '|' in tracker_key else tracker_key

        try:
            replacements = self.mod_manager.get_all_replacements()
            wem_path_to_delete = None

            if pck_file in replacements and tracker_key in replacements[pck_file]:
                wem_path = replacements[pck_file][tracker_key].get('wem_path', '')

                if wem_path:
                    permanent_storage = get_config_dir() / "imported_mods"
                    wem_path_obj = Path(wem_path)

                    try:
                        if wem_path_obj.is_relative_to(permanent_storage):
                            wem_path_to_delete = wem_path_obj
                    except (ValueError, AttributeError):

                        if str(permanent_storage) in str(wem_path_obj):
                            wem_path_to_delete = wem_path_obj

            success = self.mod_manager.remove_replacement(pck_file, tracker_key)

            if success:
                self._emit_changes_count()

                if wem_path_to_delete and wem_path_to_delete.exists():
                    try:
                        wem_path_to_delete.unlink()
                        self.statusUpdate.emit(QCoreApplication.translate("Application", "Removed replacement and deleted imported mod file"))
                    except Exception as e:
                        self.statusUpdate.emit(QCoreApplication.translate("Application", "Removed replacement (but couldn't delete file: %1)").replace("%1", str(e)))
                else:
                    self.statusUpdate.emit(QCoreApplication.translate("Application", "Removed replacement for file %1").replace("%1", display_id))

                replacements = self.mod_manager.get_all_replacements()
                if not replacements:

                    self.closeChangesDialog.emit()
                    self.statusUpdate.emit(QCoreApplication.translate("Application", "All changes have been removed"))
                else:

                    self.showChanges()
            else:
                self.statusUpdate.emit(QCoreApplication.translate("Application", "Could not find replacement for file %1").replace("%1", display_id))

        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Failed to remove change: %1").replace("%1", str(e)))

    @pyqtSlot(str)
    def playReplacementAudio(self, wem_path):

        print(f"[PLAY DEBUG] Attempting to play: {wem_path}")
        print(f"[PLAY DEBUG] Path empty: {not wem_path}")
        print(f"[PLAY DEBUG] Path exists: {Path(wem_path).exists() if wem_path else 'N/A'}")

        if not wem_path or not Path(wem_path).exists():
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Replacement audio file not found: %1").replace("%1", wem_path))
            return

        try:

            wem_bytes = Path(wem_path).read_bytes()

            cache_key = f"replacement_{Path(wem_path).name}"
            self.audio_player.play_wem(wem_bytes, cache_key)

            self.nowPlayingUpdate.emit(QCoreApplication.translate("Application", "Playing: %1").replace("%1", Path(wem_path).name))
            self.playbackStateUpdate.emit(True, False, True)
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Playing replacement audio"))

        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Playback Error"), str(e))

    @pyqtSlot(str, str, str, str)
    def navigateToChange(self, pck_filename, file_id, item_type, bnk_id):

        if not self.game_root_dir:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Cannot navigate: no game directory selected"))
            return

        pck_path = None
        for loaded_path in self._pck_loaded:
            if Path(loaded_path).name == pck_filename:
                pck_path = loaded_path
                break

        if not pck_path:

            base_path = Path(self.game_root_dir).joinpath(*AUDIO_SUBPATH)

            potential_path = base_path / pck_filename
            if potential_path.exists():
                pck_path = str(potential_path)

            if not pck_path:
                for lang_dir in LANGUAGE_FOLDERS:
                    potential_path = base_path / lang_dir / pck_filename
                    if potential_path.exists():
                        pck_path = str(potential_path)
                        break

            if not pck_path and base_path.exists():
                for pck_file in base_path.rglob("*.pck"):
                    if pck_file.name == pck_filename:
                        pck_path = str(pck_file)
                        break

        if not pck_path:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Could not find PCK file: %1").replace("%1", pck_filename))
            return

        self.navigateToSearchResult(file_id, item_type, pck_path, bnk_id)

    @pyqtSlot()
    def resetAllChanges(self):

        stats = self.mod_manager.get_stats()
        if stats["modded_pcks"] == 0:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "No replacements to reset"))
            return

        try:
            if self.mod_manager.persistent_base_path:
                for pck_name in stats["pcks"]:
                    pck_path = self.mod_manager.get_persistent_pck_path(pck_name)
                    if pck_path.exists():
                        pck_path.chmod(0o644)
                        pck_path.unlink()

            self.mod_manager.clear_all_replacements()

            self._imported_mod_metadata = None

            self.statusUpdate.emit(QCoreApplication.translate("Application", "All changes reset"))
            self._emit_changes_count()
        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Failed to reset: %1").replace("%1", str(e)))

    @pyqtSlot(str, str, str)
    def tagSound(self, item_id, item_type, pck_path):

        meta = self._find_item_meta(item_id, item_type, pck_path)
        if not meta:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Could not find item data"))
            return

        try:

            if meta["type"] == "wem":
                indexer = PCKIndexer(meta["pck_path"])
                indexer.build_index()
                wem_bytes = indexer.extract_single_file(meta["file_id"], "wem", meta["lang_id"])
                file_id = meta["file_id"]
            else:

                if "streaming_wem" in meta and "streaming_pck_path" in meta:
                    sw = meta["streaming_wem"]
                    indexer = PCKIndexer(meta["streaming_pck_path"])
                    indexer.build_index()
                    wem_bytes = indexer.extract_single_file(sw["id"], "wem", sw["lang_id"])
                else:
                    bnk_indexer = BNKIndexer(meta["bnk_bytes"])
                    bnk_indexer.parse_didx()
                    wem_bytes = bnk_indexer.extract_wem(meta["wem_id"])
                file_id = meta.get("wem_id", meta.get("file_id"))

            existing_info = self.sound_db.get_sound_info(wem_bytes)
            sound_hash = self.sound_db.calculate_hash(wem_bytes)

            sound_info = {
                "itemId": item_id,
                "itemType": item_type,
                "pckPath": pck_path,
                "name": existing_info.get("name", "") if existing_info else "",
                "tags": ", ".join(existing_info.get("tags", [])) if existing_info else "",
                "notes": existing_info.get("notes", "") if existing_info else "",
                "hash": sound_hash[:16] + "...",
                "fileId": str(file_id),
            }

            self._tag_context = {
                "wem_bytes": wem_bytes,
                "file_id": file_id,
            }

            self.tagDialogReady.emit(sound_info)

        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Failed to load sound info:\n%1").replace("%1", str(e)))

    @pyqtSlot(str, str, str, str, str, str)
    def saveTag(self, item_id, item_type, pck_path, name, tags_text, notes):

        if not hasattr(self, '_tag_context'):
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "No tagging context available"))
            return

        try:
            wem_bytes = self._tag_context["wem_bytes"]
            file_id = self._tag_context["file_id"]

            tags = [t.strip() for t in tags_text.split(',') if t.strip()]

            self.sound_db.add_sound(wem_bytes, name, tags, notes, file_id)

            self.statusUpdate.emit(QCoreApplication.translate("Application", "Tagged sound: %1").replace("%1", name))

            tag_text = name
            if tags:
                tag_text += f" [{', '.join(tags)}]"

            self.tagUpdated.emit(item_id, item_type, pck_path, tag_text)

            del self._tag_context

        except Exception as e:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Error"), QCoreApplication.translate("Application", "Failed to save tag:\n%1").replace("%1", str(e)))

    @pyqtSlot()
    def findMatchingSound(self):

        if not self.game_root_dir:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "No Directory"), QCoreApplication.translate("Application", "Please select a game directory first."))
            return

        if not self.index_ready:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Not Ready"), QCoreApplication.translate("Application", "The file index is still building. Please wait."))
            return

        if self._match_thread and self._match_thread.is_alive():
            self.statusUpdate.emit(QCoreApplication.translate("Application", "A match is already in progress"))
            return

        from .native_dialogs import NativeDialogs
        recording_path = NativeDialogs.get_open_file(
            "Select Audio Recording",
            str(Path.home()),
            "Audio Files (*.wav *.mp3 *.m4a *.ogg *.flac);;All Files (*)",
        )
        if not recording_path:
            return

        self._match_cancel = threading.Event()

        self.matchStarted.emit()
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Preparing audio fingerprint..."))

        self._match_thread = threading.Thread(
            target=self._run_matching_threaded,
            args=(recording_path, self._match_cancel),
            daemon=True,
        )
        self._match_thread.start()

    @pyqtSlot()
    def cancelMatchingSound(self):
        self._match_cancel.set()
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Match cancelled"))
        self.matchFinished.emit()

    @pyqtSlot()
    def selectRecordingFile(self):

        from .native_dialogs import NativeDialogs
        recording_path = NativeDialogs.get_open_file(
            "Select Audio Recording",
            str(Path.home()),
            "Audio Files (*.wav *.mp3 *.m4a *.ogg *.flac);;All Files (*)",
        )
        if recording_path:
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "setSelectedFile",
                Qt.QueuedConnection, Q_ARG("QVariant", recording_path)
            )

    @pyqtSlot(str)
    def startMatchingWithFile(self, recording_path):

        if not self.game_root_dir:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "No Directory"), QCoreApplication.translate("Application", "Please select a game directory first."))
            return

        if not self.index_ready:
            self.errorOccurred.emit(QCoreApplication.translate("Application", "Not Ready"), QCoreApplication.translate("Application", "The file index is still building. Please wait."))
            return

        if self._match_thread and self._match_thread.is_alive():
            self.statusUpdate.emit(QCoreApplication.translate("Application", "A match is already in progress"))
            return

        if not self._fingerprint_db_prompt_shown and len(self.fingerprint_db.database) == 0:
            self._fingerprint_db_prompt_shown = True
            self._pending_match_path = recording_path
            self.fingerprintDbPrompt.emit(0)
            return

        self._match_cancel = threading.Event()

        self._match_thread = threading.Thread(
            target=self._run_matching_threaded,
            args=(recording_path, self._match_cancel),
            daemon=True,
        )
        self._match_thread.start()

    def _run_matching_threaded(self, recording_path, cancel_event):

        try:
            from src.audio_matcher import AudioMatcher

            matcher = AudioMatcher(fingerprint_db=self.fingerprint_db)

            recording_fp = matcher.extract_fingerprint(recording_path, duration=30)
            if recording_fp is None:
                QMetaObject.invokeMethod(
                    self, "_onMatchError",
                    Qt.QueuedConnection,
                    Q_ARG(str, QCoreApplication.translate("Application", "Failed to process the selected audio file.")),
                )
                return

            if cancel_event.is_set():
                return

            candidates = []
            directory = self._current_directory
            if not directory:
                QMetaObject.invokeMethod(
                    self, "_onMatchError",
                    Qt.QueuedConnection,
                    Q_ARG(str, QCoreApplication.translate("Application", "No audio directory loaded.")),
                )
                return

            pck_files = sorted(Path(directory).glob("*.pck"))
            total_pcks = len(pck_files)

            QMetaObject.invokeMethod(
                self, "_onMatchStatus",
                Qt.QueuedConnection,
                Q_ARG(str, QCoreApplication.translate("Application", "Scanning %1 PCK files for sounds...").replace("%1", str(total_pcks))),
            )

            for pck_idx, pck_file in enumerate(pck_files):
                if cancel_event.is_set():
                    return

                try:
                    indexer = PCKIndexer(str(pck_file))
                    indexer.build_index()

                    for wem_info in indexer.index_data["sounds"] + indexer.index_data["externals"]:
                        if cancel_event.is_set():
                            return
                        try:
                            wem_bytes = indexer.extract_single_file(
                                wem_info["id"], "wem", wem_info["lang_id"]
                            )
                            tag_text = ""
                            sound_info = self.sound_db.get_sound_info(wem_bytes)
                            if sound_info:
                                tag_text = sound_info.get("name", "")
                                if sound_info.get("tags"):
                                    tag_text += f" [{', '.join(sound_info['tags'])}]"

                            candidates.append((wem_bytes, {
                                "id": wem_info["id"],
                                "type": "wem",
                                "pck_path": str(pck_file),
                                "pck_name": pck_file.name,
                                "lang_id": wem_info["lang_id"],
                                "tags": tag_text,
                            }))
                        except Exception:
                            pass

                    for bnk_info in indexer.index_data["banks"]:
                        if cancel_event.is_set():
                            return
                        try:
                            bnk_bytes = indexer.extract_single_file(
                                bnk_info["id"], "bnk", bnk_info["lang_id"]
                            )
                            bnk_indexer = BNKIndexer(bnk_bytes)
                            bnk_indexer.parse_didx()

                            for wem in bnk_indexer.wem_list:
                                if cancel_event.is_set():
                                    return
                                try:
                                    wem_bytes = bnk_indexer.extract_wem(wem["wem_id"])
                                    tag_text = ""
                                    sound_info = self.sound_db.get_sound_info(wem_bytes)
                                    if sound_info:
                                        tag_text = sound_info.get("name", "")
                                        if sound_info.get("tags"):
                                            tag_text += f" [{', '.join(sound_info['tags'])}]"

                                    candidates.append((wem_bytes, {
                                        "id": wem["wem_id"],
                                        "type": "wem_embedded",
                                        "pck_path": str(pck_file),
                                        "pck_name": pck_file.name,
                                        "bnk_id": bnk_info["id"],
                                        "lang_id": bnk_info["lang_id"],
                                        "tags": tag_text,
                                    }))
                                except Exception:
                                    pass
                        except Exception:
                            pass

                except Exception:
                    pass

            if cancel_event.is_set():
                return

            if not candidates:
                QMetaObject.invokeMethod(
                    self, "_onMatchError",
                    Qt.QueuedConnection,
                    Q_ARG(str, QCoreApplication.translate("Application", "No audio files found in the current directory.")),
                )
                return

            QMetaObject.invokeMethod(
                self, "_onMatchStatus",
                Qt.QueuedConnection,
                Q_ARG(str, QCoreApplication.translate("Application", "Matching against %1 sounds...").replace("%1", str(len(candidates)))),
            )

            def progress_cb(current, total):
                if cancel_event.is_set():
                    return
                QMetaObject.invokeMethod(
                    self, "_onMatchProgress",
                    Qt.QueuedConnection,
                    Q_ARG(int, current), Q_ARG(int, total),
                )

            results = matcher.find_matches(
                recording_fp, candidates, top_n=20,
                progress_callback=progress_cb,
                cancel_event=cancel_event,
            )

            if cancel_event.is_set():
                return

            self.fingerprint_db.save()

            match_results = []
            self._match_metadata = {}

            for score, info in results:
                tag_text = info.get("tags", "")
                loc = None
                file_id = info["id"]
                if file_id in self.file_id_index:
                    locs = self.file_id_index[file_id]
                    if locs:
                        loc = locs[0]

                score_val = float(round(score, 1))
                print(f"[Match] ID {file_id}: score={score_val}")

                pck_path = info.get("pck_path", loc["pck_path"] if loc else "")
                item_type = info.get("type", loc["type"] if loc else "wem")
                lang_id = info.get("lang_id", loc.get("lang_id", "0") if loc else "0")
                bnk_id = info.get("bnk_id", loc.get("bnk_id", "") if loc else "")

                meta_key = f"{file_id}:{pck_path}"
                self._match_metadata[meta_key] = {
                    "file_id": file_id,
                    "type": item_type,
                    "pck_path": pck_path,
                    "lang_id": lang_id,
                    "bnk_id": bnk_id,
                }

                match_results.append({
                    "score": score_val,
                    "fileId": str(file_id),
                    "name": tag_text if tag_text else f"File {file_id}",
                    "pckName": info.get("pck_name", ""),
                    "pckPath": pck_path,
                    "itemType": item_type,
                    "bnkId": str(bnk_id),
                    "langId": str(lang_id),
                })

            QMetaObject.invokeMethod(
                self, "_onMatchResults",
                Qt.QueuedConnection,
                Q_ARG(object, match_results),
            )

        except Exception as e:
            import traceback
            traceback.print_exc()
            QMetaObject.invokeMethod(
                self, "_onMatchError",
                Qt.QueuedConnection,
                Q_ARG(str, QCoreApplication.translate("Application", "Matching failed: %1").replace("%1", str(e))),
            )

    @pyqtSlot(str)
    def _onMatchStatus(self, message):
        self.statusUpdate.emit(message)
        if hasattr(self, 'audio_match_dialog') and self.audio_match_dialog:
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "setStatus",
                Qt.QueuedConnection, Q_ARG("QVariant", message)
            )

    @pyqtSlot(int, int)
    def _onMatchProgress(self, current, total):
        self.matchProgressUpdate.emit(current, total)
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Matching... %1/%2 sounds").replace("%1", str(current)).replace("%2", str(total)))
        if hasattr(self, 'audio_match_dialog') and self.audio_match_dialog:
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "setProgress",
                Qt.QueuedConnection, Q_ARG("QVariant", current), Q_ARG("QVariant", total)
            )

    @pyqtSlot(object)
    def _onMatchResults(self, results):
        self.matchFinished.emit()
        self.matchResultsReady.emit(results)
        count = len(results)
        if count > 0:
            status_msg = QCoreApplication.translate("Application", "Found %1 match(es) — best score: %2%").replace("%1", str(count)).replace("%2", str(results[0]['score']))
            self.statusUpdate.emit(status_msg)
        else:
            status_msg = QCoreApplication.translate("Application", "No matches found")
            self.statusUpdate.emit(status_msg)

        if hasattr(self, 'audio_match_dialog') and self.audio_match_dialog:
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "setMatching",
                Qt.QueuedConnection, Q_ARG("QVariant", False)
            )
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "setStatus",
                Qt.QueuedConnection, Q_ARG("QVariant", status_msg)
            )

            from PyQt5.QtCore import QTimer
            QTimer.singleShot(1000, lambda: QMetaObject.invokeMethod(
                self.audio_match_dialog, "hide", Qt.QueuedConnection
            ))

    @pyqtSlot(str)
    def _onMatchError(self, message):
        self.matchFinished.emit()
        self.errorOccurred.emit(QCoreApplication.translate("Application", "Match Error"), message)

        if hasattr(self, 'audio_match_dialog') and self.audio_match_dialog:
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "setMatching",
                Qt.QueuedConnection, Q_ARG("QVariant", False)
            )
            QMetaObject.invokeMethod(
                self.audio_match_dialog, "hide", Qt.QueuedConnection
            )

    @pyqtSlot()
    def browseAndImportZzar(self):

        from .native_dialogs import NativeDialogs
        zzar_path = NativeDialogs.get_open_file(
            f"Select {MOD_FILE_EXT} Mod to Import for Editing",
            str(Path.home()),
            f"{MOD_FILE_EXT_UPPER} Mod Packages (*{MOD_FILE_EXT});;All Files (*)",
        )
        if not zzar_path:
            return

        self.importZzarForEditing(zzar_path)

    @pyqtSlot(str)
    def importZzarForEditing(self, zzar_path):

        try:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Importing %1 mod for editing...").replace("%1", MOD_FILE_EXT))

            if self.mod_manager.get_all_replacements():
                print("[Audio Browser] Clearing existing changes before importing new mod")
                self.mod_manager.clear_all_replacements()

            mod_pkg = ModPackageManager(persistent_mod_manager=self.mod_manager)
            metadata = mod_pkg.validate_mod_package(zzar_path)

            mod_name = metadata.get('name', 'Unknown')
            mod_author = metadata.get('author', 'Unknown')
            mod_version = metadata.get('version', '1.0.0')
            mod_description = metadata.get('description', '')

            print(f"[Audio Browser] Importing mod: {mod_name} v{mod_version} by {mod_author}")

            import zipfile
            import tempfile

            with zipfile.ZipFile(zzar_path, 'r') as zf:

                from ZZAR import get_temp_dir
                temp_dir = Path(tempfile.mkdtemp(prefix='zzar_import_', dir=str(get_temp_dir())))

                try:

                    zf.extractall(temp_dir)

                    thumbnail_path = ""
                    thumbnail_filename = metadata.get('thumbnail', '')
                    if thumbnail_filename:
                        source_thumbnail = temp_dir / thumbnail_filename
                        if source_thumbnail.exists():

                            permanent_storage = get_config_dir() / "imported_mods"
                            permanent_storage.mkdir(parents=True, exist_ok=True)

                            thumbnail_ext = source_thumbnail.suffix
                            permanent_thumbnail = permanent_storage / f"thumbnail_{mod_name.replace(' ', '_')}{thumbnail_ext}"

                            import shutil
                            shutil.copy2(source_thumbnail, permanent_thumbnail)
                            thumbnail_path = str(permanent_thumbnail)
                            print(f"[Audio Browser] Saved thumbnail to: {thumbnail_path}")

                    self._imported_mod_metadata = {
                        'name': mod_name,
                        'author': mod_author,
                        'version': mod_version,
                        'description': mod_description,
                        'thumbnail': thumbnail_path
                    }

                    replacement_count = 0
                    normalized_replacements = mod_pkg._normalize_metadata_replacements(metadata)
                    for pck_name, files in normalized_replacements.items():
                        for file_key, file_info in files.items():
                            file_id = file_key.split('|')[-1]
                            wem_file = file_info.get('wem_file', '')
                            if not wem_file:
                                continue

                            wem_path = temp_dir / wem_file
                            if not wem_path.exists():
                                print(f"[Audio Browser] Warning: WEM file not found: {wem_file}")
                                continue

                            permanent_storage = get_config_dir() / "imported_mods"
                            permanent_storage.mkdir(parents=True, exist_ok=True)

                            permanent_wem = permanent_storage / f"imported_{pck_name}_{file_id}_{replacement_count}.wem"
                            import shutil
                            shutil.copy2(wem_path, permanent_wem)

                            file_type = file_info.get('file_type', 'wem')
                            lang_id = file_info.get('lang_id', 0)
                            bnk_id = file_info.get('bnk_id')

                            self.mod_manager.add_replacement(
                                pck_name,
                                int(file_id),
                                str(permanent_wem),
                                file_type,
                                lang_id,
                                bnk_id
                            )

                            replacement_count += 1

                    shutil.rmtree(temp_dir, ignore_errors=True)

                    self._emit_changes_count()
                    self.statusUpdate.emit(
                        QCoreApplication.translate("Application", "Imported '%1' - %2 replacement(s) loaded. You can now view, edit, or add more replacements.")
                        .replace("%1", mod_name).replace("%2", str(replacement_count))
                    )

                    self.successDialogRequested.emit(
                        QCoreApplication.translate("Application", "Mod Imported for Editing"),
                        QCoreApplication.translate("Application", "Successfully imported:\n\n"
                        "Name: %1\n"
                        "Author: %2\n"
                        "Version: %3\n"
                        "Replacements: %4\n\n"
                        "The replacements are now loaded in your session.\n"
                        "You can view them in 'Show Changes', add more replacements, "
                        "or export as a new mod package.")
                        .replace("%1", mod_name).replace("%2", mod_author)
                        .replace("%3", mod_version).replace("%4", str(replacement_count)),
                        f"../assets/{ASSETS_DIR}/YanagiSmug.png"
                    )

                except Exception as e:

                    if temp_dir.exists():
                        import shutil
                        shutil.rmtree(temp_dir, ignore_errors=True)
                    raise

        except Exception as e:
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Failed to import %1").replace("%1", MOD_FILE_EXT))
            self.errorOccurred.emit(
                QCoreApplication.translate("Application", "Import Error"),
                QCoreApplication.translate("Application", "Failed to import %1 mod for editing:\n\n%2").replace("%1", MOD_FILE_EXT).replace("%2", str(e))
            )
            import traceback
            traceback.print_exc()

    def _build_file_index(self, pck_files):

        self._index_cancel.set()

        self.file_id_index = {}
        self.index_ready = False
        pck_paths = [str(pck) for pck in pck_files]
        self._indexing_directory = str(self._current_directory)

        self._index_cancel = threading.Event()
        cancel = self._index_cancel

        self._index_thread = threading.Thread(
            target=self._build_index_threaded, args=(pck_paths, cancel), daemon=True
        )
        self._index_thread.start()

    def _build_index_threaded(self, pck_paths, cancel_event):

        temp_index = {}
        for i, pck_path in enumerate(pck_paths):
            if cancel_event.is_set():
                return

            try:
                QMetaObject.invokeMethod(
                    self, "_updateIndexProgress",
                    Qt.QueuedConnection,
                    Q_ARG(int, i + 1), Q_ARG(int, len(pck_paths)),
                )

                indexer = PCKIndexer(pck_path)
                indexer.build_index()

                for bnk_info in indexer.index_data["banks"]:
                    if cancel_event.is_set():
                        return

                    bnk_id = bnk_info["id"]
                    temp_index.setdefault(bnk_id, []).append({
                        "pck_path": pck_path, "type": "bnk", "lang_id": bnk_info["lang_id"]
                    })

                    try:
                        bnk_bytes = indexer.extract_single_file(bnk_id, "bnk", bnk_info["lang_id"])
                        bi = BNKIndexer(bnk_bytes)
                        bi.parse_didx()
                        for wem in bi.wem_list:
                            temp_index.setdefault(wem["wem_id"], []).append({
                                "pck_path": pck_path, "type": "wem_embedded",
                                "bnk_id": bnk_id, "lang_id": bnk_info["lang_id"],
                            })
                    except Exception:
                        pass

                for wem_info in indexer.index_data["sounds"] + indexer.index_data["externals"]:
                    temp_index.setdefault(wem_info["id"], []).append({
                        "pck_path": pck_path, "type": "wem", "lang_id": wem_info["lang_id"]
                    })

            except Exception:
                pass

        if cancel_event.is_set():
            return

        QMetaObject.invokeMethod(
            self, "_finalizeIndex",
            Qt.QueuedConnection,
            Q_ARG(object, temp_index),
        )

    @pyqtSlot(int, int)
    def _updateIndexProgress(self, current, total):
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Indexing... %1/%2 PCK files").replace("%1", str(current)).replace("%2", str(total)))

    @pyqtSlot(object)
    def _finalizeIndex(self, index_data):
        self.file_id_index = index_data
        self.index_ready = True

        if hasattr(self, '_indexing_directory') and self._indexing_directory:
            self._index_cache[self._indexing_directory] = index_data

        self.statusUpdate.emit(QCoreApplication.translate("Application", "Index ready - %1 unique file IDs").replace("%1", str(len(self.file_id_index))))

    def _find_item_meta(self, item_id, item_type, pck_path, parent_bnk=""):

        for key, data in self._item_data.items():
            if data.get("type") == "wem" and str(data.get("file_id")) == item_id:
                if not pck_path or data.get("pck_path") == pck_path:
                    return data
            elif data.get("type") == "wem_embedded" and str(data.get("wem_id")) == item_id:
                if not pck_path or data.get("pck_path") == pck_path:
                    # If parent_bnk is known, use it to pick the correct BNK
                    if parent_bnk and str(data.get("bnk_id")) != str(parent_bnk):
                        continue
                    return data
            elif data.get("type") == "bnk" and str(data.get("file_id")) == item_id:
                if not pck_path or data.get("pck_path") == pck_path:
                    return data
        return None

    @staticmethod
    def _format_size(bytes_size):
        for unit in ["B", "KB", "MB", "GB"]:
            if bytes_size < 1024:
                return f"{bytes_size:.1f} {unit}"
            bytes_size /= 1024
        return f"{bytes_size:.1f} TB"

    @staticmethod
    def _format_time(ms):
        seconds = ms // 1000
        minutes = seconds // 60
        seconds = seconds % 60
        return f"{minutes:02d}:{seconds:02d}"

    @staticmethod
    def _get_wem_duration(wem_bytes):
        try:
            if len(wem_bytes) < 12:
                return ""
            if wem_bytes[:4] != b'RIFF':
                return ""

            pos = 12
            fmt_tag = 0
            sample_rate = 0
            avg_bytes = 0
            total_samples = 0

            while pos < len(wem_bytes) - 8:
                chunk_id = wem_bytes[pos:pos + 4]
                chunk_size = struct.unpack_from('<I', wem_bytes, pos + 4)[0]
                chunk_data = pos + 8

                if chunk_id == b'fmt ':
                    if chunk_size >= 16:
                        fmt_tag = struct.unpack_from('<H', wem_bytes, chunk_data)[0]
                        sample_rate = struct.unpack_from('<I', wem_bytes, chunk_data + 4)[0]
                        avg_bytes = struct.unpack_from('<I', wem_bytes, chunk_data + 8)[0]

                        if fmt_tag == 0xFFFF and chunk_size >= 0x1C:
                            total_samples = struct.unpack_from('<I', wem_bytes, chunk_data + 0x18)[0]

                elif chunk_id == b'vorb':
                    if chunk_size >= 4 and not total_samples:
                        total_samples = struct.unpack_from('<I', wem_bytes, chunk_data)[0]

                elif chunk_id == b'data' and fmt_tag == 1 and sample_rate > 0 and not total_samples:
                    channels = struct.unpack_from('<H', wem_bytes, 12 + 8 + 2)[0] if len(wem_bytes) > 24 else 1
                    bits = struct.unpack_from('<H', wem_bytes, 12 + 8 + 14)[0] if len(wem_bytes) > 34 else 16
                    frame_size = max(bits // 8, 1) * max(channels, 1)
                    total_samples = chunk_size // frame_size

                pos = chunk_data + chunk_size
                if chunk_size % 2 != 0:
                    pos += 1

            if sample_rate > 0 and total_samples > 0:
                duration_secs = total_samples / sample_rate
                mins = int(duration_secs) // 60
                secs = int(duration_secs) % 60
                return f"{mins}:{secs:02d}"

            if sample_rate > 0 and avg_bytes > 0:
                file_size = len(wem_bytes)
                duration_secs = file_size / avg_bytes
                mins = int(duration_secs) // 60
                secs = int(duration_secs) % 60
                return f"~{mins}:{secs:02d}"
        except Exception:
            pass
        return ""

    @pyqtSlot()
    def downloadOfficialTagDb(self):
        if self._tag_db_worker and self._tag_db_worker.isRunning():
            return

        self.statusUpdate.emit(QCoreApplication.translate("Application", "Downloading official tag database..."))
        self.tagDbDownloadStarted.emit()

        self._tag_db_worker = TagDatabaseDownloadWorker()
        self._tag_db_worker.downloadFinished.connect(self._on_tag_db_downloaded)
        self._tag_db_worker.errorOccurred.connect(self._on_tag_db_error)
        self._tag_db_worker.start()

    def _on_tag_db_downloaded(self, temp_path):
        self._tag_db_temp_path = temp_path
        try:
            with open(temp_path, "rb") as f:
                raw = f.read()
            self._tag_db_latest_hash = hashlib.sha256(raw).hexdigest()
            data = json.loads(raw.decode("utf-8"))
            entry_count = len(data)
            self.tagDbDownloadReady.emit(entry_count)
            self.statusUpdate.emit(
                QCoreApplication.translate("Application", "Official tag database downloaded (%1 entries)").replace("%1", str(entry_count))
            )
        except Exception as e:
            self.tagDbDownloadError.emit(QCoreApplication.translate("Application", "Failed to read downloaded database: %1").replace("%1", str(e)))

    def _on_tag_db_error(self, message):
        self._tag_db_temp_path = None
        self.tagDbDownloadError.emit(message)
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Tag database download failed: %1").replace("%1", message))

    @pyqtSlot(bool)
    def applyOfficialTagDb(self, merge):
        if not self._tag_db_temp_path:
            self.tagDbDownloadError.emit(QCoreApplication.translate("Application", "No downloaded database available"))
            return

        try:
            count = self.sound_db.import_from_file(self._tag_db_temp_path, merge=merge)
            mode = QCoreApplication.translate("Application", "Merged") if merge else QCoreApplication.translate("Application", "Replaced")
            self.tagDbImportComplete.emit(count)
            self.statusUpdate.emit(QCoreApplication.translate("Application", "%1 tag database — %2 entries imported").replace("%1", mode).replace("%2", str(count)))

            if hasattr(self, "_tag_db_latest_hash"):
                try:
                    settings = {}
                    if self.settings_file.exists():
                        with open(self.settings_file, "r") as f:
                            settings = json.load(f)
                    settings["tag_db_last_seen_hash"] = self._tag_db_latest_hash
                    self._tag_db_last_seen_hash = self._tag_db_latest_hash
                    with open(self.settings_file, "w") as f:
                        json.dump(settings, f, indent=2)
                except Exception:
                    pass
        except Exception as e:
            self.tagDbDownloadError.emit(QCoreApplication.translate("Application", "Failed to apply tag database: %1").replace("%1", str(e)))
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Failed to apply tag database: %1").replace("%1", str(e)))
        finally:
            try:
                os.unlink(self._tag_db_temp_path)
            except Exception:
                pass
            self._tag_db_temp_path = None

    @pyqtSlot()
    def checkForNewTagDb(self):
        if self._tag_db_notify_dismissed:
            return
        if self._tag_db_check_done:
            return
        if self._tag_db_check_worker and self._tag_db_check_worker.isRunning():
            return

        self._tag_db_check_done = True
        self._tag_db_check_worker = TagDatabaseCheckWorker(self._tag_db_last_seen_hash)
        self._tag_db_check_worker.newTagsFound.connect(self._on_new_tags_found)
        self._tag_db_check_worker.start()

    def _on_new_tags_found(self, entry_count, content_hash):
        self._tag_db_latest_hash = content_hash
        self.newTagDbAvailable.emit(entry_count)

    @pyqtSlot(bool)
    def dismissTagDbNotify(self, dont_show_again):
        try:
            settings = {}
            if self.settings_file.exists():
                with open(self.settings_file, "r") as f:
                    settings = json.load(f)

            if hasattr(self, "_tag_db_latest_hash"):
                settings["tag_db_last_seen_hash"] = self._tag_db_latest_hash
                self._tag_db_last_seen_hash = self._tag_db_latest_hash

            if dont_show_again:
                settings["tag_db_notify_dismissed"] = True
                self._tag_db_notify_dismissed = True

            with open(self.settings_file, "w") as f:
                json.dump(settings, f, indent=2)
        except Exception as e:
            print(f"[Audio Browser] Error saving tag DB notify preference: {e}")

    @pyqtSlot()
    def downloadOfficialFingerprintDb(self):
        if self._fingerprint_db_worker and self._fingerprint_db_worker.isRunning():
            return

        self.statusUpdate.emit(QCoreApplication.translate("Application", "Downloading official fingerprint database..."))
        self.fingerprintDbDownloadStarted.emit()

        self._fingerprint_db_worker = FingerprintDatabaseDownloadWorker()
        self._fingerprint_db_worker.downloadFinished.connect(self._on_fingerprint_db_downloaded)
        self._fingerprint_db_worker.errorOccurred.connect(self._on_fingerprint_db_error)
        self._fingerprint_db_worker.start()

    def _on_fingerprint_db_downloaded(self, temp_path):
        self._fingerprint_db_temp_path = temp_path
        try:
            with open(temp_path, "rb") as f:
                raw = f.read()
            data = json.loads(raw.decode("utf-8"))
            entry_count = len(data)
            self.fingerprintDbDownloadReady.emit(entry_count)
            self.statusUpdate.emit(
                QCoreApplication.translate("Application", "Official fingerprint database downloaded (%1 entries)").replace("%1", str(entry_count))
            )
        except Exception as e:
            self.fingerprintDbDownloadError.emit(QCoreApplication.translate("Application", "Failed to read downloaded database: %1").replace("%1", str(e)))

    def _on_fingerprint_db_error(self, message):
        self._fingerprint_db_temp_path = None
        self.fingerprintDbDownloadError.emit(message)
        self.statusUpdate.emit(QCoreApplication.translate("Application", "Fingerprint database download failed: %1").replace("%1", message))

    @pyqtSlot(bool)
    def applyOfficialFingerprintDb(self, merge):
        if not self._fingerprint_db_temp_path:
            self.fingerprintDbDownloadError.emit(QCoreApplication.translate("Application", "No downloaded database available"))
            return

        try:
            with open(self._fingerprint_db_temp_path, 'r') as f:
                imported_data = json.load(f)

            if merge:
                count = 0
                for sound_hash, info in imported_data.items():
                    if sound_hash not in self.fingerprint_db.database:
                        count += 1
                    self.fingerprint_db.database[sound_hash] = info
            else:
                count = len(imported_data)
                self.fingerprint_db.database = imported_data

            self.fingerprint_db.save()

            mode = QCoreApplication.translate("Application", "Merged") if merge else QCoreApplication.translate("Application", "Replaced")
            self.fingerprintDbImportComplete.emit(count)
            self.statusUpdate.emit(QCoreApplication.translate("Application", "%1 fingerprint database — %2 entries imported").replace("%1", mode).replace("%2", str(count)))

            if self._pending_match_path:
                QMetaObject.invokeMethod(
                    self, "continueMatchWithoutFingerprintDb",
                    Qt.QueuedConnection
                )

        except Exception as e:
            self.fingerprintDbDownloadError.emit(QCoreApplication.translate("Application", "Failed to apply fingerprint database: %1").replace("%1", str(e)))
            self.statusUpdate.emit(QCoreApplication.translate("Application", "Failed to apply fingerprint database: %1").replace("%1", str(e)))
        finally:
            try:
                os.unlink(self._fingerprint_db_temp_path)
            except Exception:
                pass
            self._fingerprint_db_temp_path = None

    @pyqtSlot()
    def continueMatchWithoutFingerprintDb(self):
        if self._pending_match_path:
            recording_path = self._pending_match_path
            self._pending_match_path = None

            self._match_cancel = threading.Event()

            self._match_thread = threading.Thread(
                target=self._run_matching_threaded,
                args=(recording_path, self._match_cancel),
                daemon=True,
            )
            self._match_thread.start()

    @pyqtSlot()
    def refresh_audio_tools(self):

        self.audio_player.refresh_tools()
        print("[Audio Browser] Audio tools refreshed")

    def cleanup(self):

        self.audio_player.stop()
        self.cache_manager.cleanup()
        if self._index_thread and self._index_thread.is_alive():
            self._index_thread.join(timeout=1.0)
        if self._tag_db_temp_path:
            try:
                os.unlink(self._tag_db_temp_path)
            except Exception:
                pass
