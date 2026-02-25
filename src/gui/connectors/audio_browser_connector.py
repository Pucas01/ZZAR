import platform
import subprocess
from pathlib import Path

from PyQt5.QtCore import QObject, QMetaObject, Q_ARG, Qt

from gui.backend.native_dialogs import NativeDialogs


class AudioBrowserConnector:

    def _connect_audio_browser(self):
        self.audio_page = self.root.findChild(QObject, "audioBrowserPage")
        if not self.audio_page:
            return

        ab = self.audio_browser_bridge

        self.audio_page.openAudioFolderClicked.connect(self.on_open_audio_folder)
        self.audio_page.languageTabChanged.connect(ab.onLanguageTabChanged)
        self.audio_page.searchRequested.connect(ab.search)
        self.audio_page.clearSearchClicked.connect(ab.clearSearch)
        self.audio_page.findMatchingSoundClicked.connect(ab.findMatchingSound)
        self.audio_page.mergeWemToggled.connect(ab.setMergeWem)
        self.audio_page.hideUselessPckToggled.connect(ab.setHideUselessPck)
        self.audio_page.hideEmptyBnkToggled.connect(ab.setHideEmptyBnk)
        self.audio_page.treeItemExpanded.connect(self.on_audio_tree_expanded)

        self.audio_page.treeItemDoubleClicked.connect(ab.onTreeItemDoubleClicked)
        self.audio_page.treeItemRightClicked.connect(self.on_audio_context_menu)
        self.audio_page.tagSoundRequested.connect(ab.tagSound)
        self.audio_page.importZzarForEditingClicked.connect(ab.browseAndImportZzar)
        self.audio_page.showChangesClicked.connect(ab.showChanges)
        self.audio_page.removeChangeRequested.connect(ab.removeChange)
        self.audio_page.navigateToChangeClicked.connect(ab.navigateToChange)
        self.audio_page.playReplacementClicked.connect(ab.playReplacementAudio)
        self.audio_page.applyChangesClicked.connect(ab.applyAllChanges)
        self.audio_page.exportModClicked.connect(ab.exportAsMod)
        self.audio_page.createModPackageRequested.connect(ab.createModPackage)
        self.audio_page.resetAllClicked.connect(ab.resetAllChanges)
        self.audio_page.playClicked.connect(ab.play)
        self.audio_page.pauseClicked.connect(ab.pause)
        self.audio_page.stopClicked.connect(ab.stop)
        self.audio_page.volumeAdjusted.connect(ab.setVolume)
        self.audio_page.seekRequested.connect(ab.seekTo)
        self.audio_page.wipDialogRequested.connect(self.on_wip_dialog_requested)
        self.audio_page.normalizeAudioToggled.connect(ab.setNormalizeAudio)

        ab.statusUpdate.connect(
            lambda msg: self.audio_page.setProperty("statusText", msg)
        )
        ab.nowPlayingUpdate.connect(
            lambda txt: self.audio_page.setProperty("nowPlayingText", txt)
        )
        ab.playbackStateUpdate.connect(self._on_audio_playback_state)
        ab.progressUpdate.connect(self._on_audio_progress)
        ab.treeCleared.connect(
            lambda: QMetaObject.invokeMethod(self.audio_page, "clearTree", Qt.QueuedConnection)
        )
        ab.treeItemsReady.connect(self._on_audio_tree_items)
        ab.languageTabsReady.connect(
            lambda tabs: QMetaObject.invokeMethod(
                self.audio_page, "setLanguageTabs",
                Qt.QueuedConnection, Q_ARG("QVariant", tabs)
            )
        )
        ab.gameDirectoryReady.connect(
            lambda path: QMetaObject.invokeMethod(
                self.audio_page, "setGameDirectory",
                Qt.QueuedConnection, Q_ARG("QVariant", path)
            )
        )
        ab.errorOccurred.connect(self.on_error_occurred)
        ab.alertDialogRequested.connect(self.on_alert_dialog_requested)
        ab.wwiseErrorDialog.connect(self.on_wwise_error_dialog)
        ab.successDialogRequested.connect(self.on_audio_success_dialog)
        ab.searchResultsReady.connect(self._on_audio_search_results)
        ab.navigateToItem.connect(self._on_audio_navigate_to_item)
        ab.changesReady.connect(self._on_audio_changes)
        ab.closeChangesDialog.connect(self._on_close_changes_dialog)
        ab.tagDialogReady.connect(self._on_audio_tag_dialog)
        ab.tagUpdated.connect(self._on_audio_tag_updated)
        ab.exportMetadataDialogReady.connect(self._on_audio_metadata_dialog)
        ab.thumbnailPathSelected.connect(self._on_audio_thumbnail_selected)
        ab.changesCountUpdated.connect(self._on_changes_count_updated)
        ab.normalizeAudioChanged.connect(
            lambda enabled: self.audio_page.setProperty("normalizeAudioChecked", enabled)
        )
        ab.hideEmptyBnkChanged.connect(
            lambda enabled: self.audio_page.setProperty("hideEmptyBnkChecked", enabled)
        )

        self.audio_page.downloadOfficialTagDbClicked.connect(ab.downloadOfficialTagDb)
        self.audio_page.applyOfficialTagDb.connect(ab.applyOfficialTagDb)
        self.audio_page.openTagDbFolderClicked.connect(self.on_open_tag_db_folder)
        ab.tagDbDownloadStarted.connect(
            lambda: QMetaObject.invokeMethod(
                self.audio_page, "onTagDbDownloadStarted", Qt.QueuedConnection
            )
        )
        ab.tagDbDownloadReady.connect(
            lambda count: QMetaObject.invokeMethod(
                self.audio_page, "onTagDbDownloadReady",
                Qt.QueuedConnection, Q_ARG("QVariant", count)
            )
        )
        ab.tagDbDownloadError.connect(
            lambda msg: QMetaObject.invokeMethod(
                self.audio_page, "onTagDbDownloadError",
                Qt.QueuedConnection, Q_ARG("QVariant", msg)
            )
        )
        ab.tagDbImportComplete.connect(
            lambda count: QMetaObject.invokeMethod(
                self.audio_page, "onTagDbImportComplete",
                Qt.QueuedConnection, Q_ARG("QVariant", count)
            )
        )
        ab.newTagDbAvailable.connect(self._on_new_tag_db_available)
        self.audio_page.dismissTagDbNotify.connect(ab.dismissTagDbNotify)

        self.audio_page.cancelMatchClicked.connect(ab.cancelMatchingSound)
        self.audio_page.matchResultNavigateClicked.connect(ab.navigateToSearchResult)
        ab.matchStarted.connect(
            lambda: QMetaObject.invokeMethod(
                self.audio_page, "onMatchStarted", Qt.QueuedConnection
            )
        )
        ab.matchFinished.connect(
            lambda: QMetaObject.invokeMethod(
                self.audio_page, "onMatchFinished", Qt.QueuedConnection
            )
        )
        ab.matchProgressUpdate.connect(
            lambda current, total: QMetaObject.invokeMethod(
                self.audio_page, "onMatchProgress",
                Qt.QueuedConnection,
                Q_ARG("QVariant", current),
                Q_ARG("QVariant", total),
            )
        )
        ab.matchResultsReady.connect(self._on_match_results)

        ab.loadFromSettings()
        ab.checkForNewTagDb()
        print("[ZZAR] Audio browser page connected")


    def _on_new_tag_db_available(self, count):
        self.root.setProperty("pendingTagDbCount", count)

    def on_audio_tree_expanded(self, item_id, item_type):
        if item_type == "PCK":
            pass
        else:
            self.audio_browser_bridge.onTreeItemExpanded(item_id, item_type)

    def on_audio_context_menu(self, item_id, item_type, pck_path, x, y):
        if "WEM" not in item_type and "wem" not in item_type.lower():
            return
        pass

    def _on_audio_playback_state(self, playing, paused, enabled):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "setPlaybackState",
                Qt.QueuedConnection,
                Q_ARG("QVariant", playing),
                Q_ARG("QVariant", paused),
                Q_ARG("QVariant", enabled),
            )

    def _on_audio_progress(self, position, time_str):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "setProgress",
                Qt.QueuedConnection,
                Q_ARG("QVariant", position),
                Q_ARG("QVariant", time_str),
            )

    def _on_audio_tree_items(self, items):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "addTreeItems",
                Qt.QueuedConnection,
                Q_ARG("QVariant", items),
            )

    def _on_audio_search_results(self, query, results):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "showSearchResults",
                Qt.QueuedConnection,
                Q_ARG("QVariant", query),
                Q_ARG("QVariant", results),
            )

    def _on_audio_navigate_to_item(self, file_id, pck_path):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "scrollToItem",
                Qt.QueuedConnection,
                Q_ARG("QVariant", file_id),
                Q_ARG("QVariant", pck_path),
            )

    def _on_audio_changes(self, changes):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "showChanges",
                Qt.QueuedConnection,
                Q_ARG("QVariant", changes),
            )

    def _on_changes_count_updated(self, count):
        if self.audio_page:
            self.audio_page.setProperty("changesCount", count)

    def _on_close_changes_dialog(self):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "closeChangesDialog",
                Qt.QueuedConnection,
            )

    def _on_audio_tag_dialog(self, sound_info):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "showTagDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", sound_info),
            )

    def _on_audio_tag_updated(self, item_id, item_type, pck_path, tag_text):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "updateTreeItemTag",
                Qt.QueuedConnection,
                Q_ARG("QVariant", item_id),
                Q_ARG("QVariant", item_type),
                Q_ARG("QVariant", pck_path),
                Q_ARG("QVariant", tag_text),
            )

    def _on_audio_metadata_dialog(self, metadata):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "showMetadataDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", metadata or {}),
            )

    def _on_audio_thumbnail_selected(self, path):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "setThumbnailPath",
                Qt.QueuedConnection,
                Q_ARG("QVariant", path),
            )

    def on_open_audio_folder(self, folder_type):
        game_dir = self.audio_browser_bridge.game_root_dir
        if not game_dir:
            return

        if folder_type == "streaming":
            folder = Path(game_dir) / "StreamingAssets" / "Audio" / "Windows" / "Full"
        else:
            folder = Path(game_dir) / "Persistent" / "Audio" / "Windows" / "Full"

        if not folder.exists():
            print(f"[Audio Browser] Folder does not exist: {folder}")
            QMetaObject.invokeMethod(
                self.root, "showErrorToast", Qt.QueuedConnection,
                Q_ARG("QVariant", self.tr("Folder does not exist:\n%1").replace("%1", str(folder))),
            )
            return

        print(f"[Audio Browser] Opening folder: {folder}")
        system = platform.system()
        try:
            if system == "Windows":
                subprocess.Popen(["explorer", str(folder)])
            elif system == "Darwin":
                subprocess.Popen(["open", str(folder)])
            else:
                env = NativeDialogs._get_clean_env()
                subprocess.Popen(
                    ["xdg-open", str(folder)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    stdin=subprocess.DEVNULL,
                    start_new_session=True,
                    env=env,
                )
        except Exception as e:
            print(f"[Audio Browser] ERROR: Could not open folder: {e}")

    def on_open_tag_db_folder(self):
        from src.config_manager import get_sound_database_file

        folder = get_sound_database_file().parent
        folder.mkdir(parents=True, exist_ok=True)

        print(f"[Audio Browser] Opening tag DB folder: {folder}")
        system = platform.system()
        try:
            if system == "Windows":
                subprocess.Popen(["explorer", str(folder)])
            elif system == "Darwin":
                subprocess.Popen(["open", str(folder)])
            else:
                env = NativeDialogs._get_clean_env()
                subprocess.Popen(
                    ["xdg-open", str(folder)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    stdin=subprocess.DEVNULL,
                    start_new_session=True,
                    env=env,
                )
        except Exception as e:
            print(f"[Audio Browser] ERROR: Could not open tag DB folder: {e}")

    def _on_match_results(self, results):
        if self.audio_page:
            QMetaObject.invokeMethod(
                self.audio_page, "showMatchResults",
                Qt.QueuedConnection,
                Q_ARG("QVariant", results),
            )
