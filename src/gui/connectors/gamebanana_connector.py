

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
        self.gamebanana_page.downloadModRequested.connect(
            lambda url, filename, mod_name, mod_id: gb.downloadMod(url, filename, mod_name, mod_id)
        )
        self.gamebanana_page.installChosenZZARRequested.connect(gb.installChosenZZAR)

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
        gb.installComplete.connect(self.on_gamebanana_install_complete)
        gb.multipleZZARFound.connect(self.on_gamebanana_multiple_zzar)
        gb.installStateChanged.connect(
            lambda installing: QMetaObject.invokeMethod(
                self.gamebanana_page, "setInstallState",
                Qt.QueuedConnection, Q_ARG("QVariant", installing)
            )
        )

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

        gb.installedModsChanged.connect(
            lambda names: QMetaObject.invokeMethod(
                self.gamebanana_page, "onInstalledModsChanged",
                Qt.QueuedConnection, Q_ARG("QVariant", names)
            )
        )

        gb.errorOccurred.connect(self.on_error_occurred)

        print("[ZZAR] GameBanana page connected")

    def on_gamebanana_download_complete(self, file_path):
        print(f"[ZZAR] Mod downloaded to: {file_path}")

    def on_gamebanana_install_complete(self, message):
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessToast",
            Qt.QueuedConnection,
            Q_ARG("QVariant", message)
        )
        self.mod_manager_bridge.refreshMods()
        print(f"[ZZAR] {message}")

    def on_gamebanana_multiple_zzar(self, zzar_names, zip_path):
        QMetaObject.invokeMethod(
            self.gamebanana_page, "showZZARChooser",
            Qt.QueuedConnection,
            Q_ARG("QVariant", zzar_names),
            Q_ARG("QVariant", zip_path)
        )

