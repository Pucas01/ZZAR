

from PyQt5.QtCore import QObject, QMetaObject, Q_ARG, Qt

class GameBananaConnector:
    

    def _connect_gamebanana(self):
        
        self.gamebanana_page = self.root.findChild(QObject, "gameBananaPage")
        if not self.gamebanana_page:
            print("[ZZAR] GameBanana page not found")
            return

        gb = self.gamebanana_bridge

        self.gamebanana_page.loadModsRequested.connect(gb.fetchMods)
        self.gamebanana_page.modCardClicked.connect(gb.fetchModDetails)
        self.gamebanana_page.refreshRequested.connect(gb.refresh)
        self.gamebanana_page.downloadModRequested.connect(gb.downloadMod)

        gb.modsLoaded.connect(
            lambda mods: QMetaObject.invokeMethod(
                self.gamebanana_page, "onModsLoaded",
                Qt.QueuedConnection, Q_ARG("QVariant", mods)
            )
        )

        gb.modDetailsLoaded.connect(
            lambda details: QMetaObject.invokeMethod(
                self.gamebanana_page, "onModDetailsLoaded",
                Qt.QueuedConnection, Q_ARG("QVariant", details)
            )
        )

        gb.loadingStateChanged.connect(
            lambda loading: QMetaObject.invokeMethod(
                self.gamebanana_page, "setLoadingState",
                Qt.QueuedConnection, Q_ARG("QVariant", loading)
            )
        )

        gb.downloadProgress.connect(
            lambda progress: QMetaObject.invokeMethod(
                self.gamebanana_page, "onDownloadProgress",
                Qt.QueuedConnection, Q_ARG("QVariant", progress)
            )
        )

        gb.downloadComplete.connect(self.on_gamebanana_download_complete)

        gb.thumbnailUpdated.connect(
            lambda mod_id, url: QMetaObject.invokeMethod(
                self.gamebanana_page, "onThumbnailUpdated",
                Qt.QueuedConnection, Q_ARG("QVariant", mod_id), Q_ARG("QVariant", url)
            )
        )

        gb.downloadCountUpdated.connect(
            lambda mod_id, count: QMetaObject.invokeMethod(
                self.gamebanana_page, "onDownloadCountUpdated",
                Qt.QueuedConnection, Q_ARG("QVariant", mod_id), Q_ARG("QVariant", count)
            )
        )

        gb.zzarSupportUpdated.connect(
            lambda mod_id, supported: QMetaObject.invokeMethod(
                self.gamebanana_page, "onZZARSupportUpdated",
                Qt.QueuedConnection, Q_ARG("QVariant", mod_id), Q_ARG("QVariant", supported)
            )
        )

        gb.errorOccurred.connect(self.on_error_occurred)

        print("[ZZAR] GameBanana page connected")

        gb.fetchMods(1, "default")

    def on_gamebanana_download_complete(self, file_path):
        

        QMetaObject.invokeMethod(
            self.root,
            "showSuccessToast",
            Qt.QueuedConnection,
            Q_ARG("QVariant", f"Downloaded mod file successfully")
        )

        print(f"[ZZAR] Mod downloaded to: {file_path}")

