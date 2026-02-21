from pathlib import Path

from PyQt5.QtCore import QObject, QMetaObject, Q_ARG, Qt

from gui.backend.native_dialogs import NativeDialogs


class ImportWizardConnector:

    def _connect_import_wizard(self):
        self.import_wizard = self.root.findChild(QObject, "importWizard")
        if not self.import_wizard:
            return

        self.import_wizard.browseFilesClicked.connect(self.on_wizard_browse_files)
        self.import_wizard.browseFolderClicked.connect(self.on_wizard_browse_folder)
        self.import_wizard.browseThumbnailClicked.connect(
            self.on_wizard_browse_thumbnail
        )
        self.import_wizard.createModClicked.connect(self.on_wizard_create_mod)
        self.import_wizard.wizardCancelled.connect(self.on_wizard_cancelled)
        print("[ZZAR] Import wizard connected")

    def on_wizard_browse_files(self, mode):
        print(f"[Import Wizard] Browsing for files, mode: {mode}")

        if mode == "pck_file":
            filter_str = "PCK Files (*.pck);;All Files (*)"
            title = "Select PCK File(s)"
        else:
            filter_str = "WEM Files (*.wem);;All Files (*)"
            title = "Select WEM File(s)"

        files = NativeDialogs.get_open_files(title, str(Path.home()), filter_str)

        if files:
            print(f"[Import Wizard] Selected {len(files)} file(s)")
            self.wizard_selected_files = files

            display_names = [Path(f).name for f in files]
            QMetaObject.invokeMethod(
                self.import_wizard,
                "setSelectedFiles",
                Qt.QueuedConnection,
                Q_ARG("QVariant", display_names),
            )
        else:
            print("[Import Wizard] File selection cancelled")

    def on_wizard_browse_folder(self, mode):
        print(f"[Import Wizard] Browsing for folder, mode: {mode}")

        folder = NativeDialogs.get_directory("Select Folder", str(Path.home()))

        if folder:
            print(f"[Import Wizard] Selected folder: {folder}")
            self.wizard_selected_folder = folder

            folder_path = Path(folder)
            if mode == "pck_folder":
                files = list(folder_path.rglob("*.pck"))
            else:
                files = list(folder_path.rglob("*.wem"))

            self.wizard_selected_files = [str(f) for f in files]

            display_names = [str(f.relative_to(folder_path)) for f in files]

            print(f"[Import Wizard] Found {len(files)} files in folder (recursive)")

            QMetaObject.invokeMethod(
                self.import_wizard,
                "setSelectedFolder",
                Qt.QueuedConnection,
                Q_ARG("QVariant", folder),
                Q_ARG("QVariant", display_names),
            )
        else:
            print("[Import Wizard] Folder selection cancelled")

    def on_wizard_browse_thumbnail(self):
        print("[Import Wizard] Browsing for thumbnail...")

        file_path = NativeDialogs.get_open_file(
            "Select Thumbnail Image",
            str(Path.home()),
            "Image Files (*.png *.jpg *.jpeg *.bmp *.gif);;All Files (*)",
        )

        if file_path:
            print(f"[Import Wizard] Selected thumbnail: {file_path}")
            QMetaObject.invokeMethod(
                self.import_wizard,
                "setThumbnailPath",
                Qt.QueuedConnection,
                Q_ARG("QVariant", file_path),
            )
        else:
            print("[Import Wizard] Thumbnail selection cancelled")

    def on_wizard_create_mod(self, wizard_data_js):
        print("[Import Wizard] Creating mod...")

        wizard_data = wizard_data_js.toVariant()
        print(f"[Import Wizard] Data: {wizard_data}")

        settings = self.load_settings()
        game_audio_dir = settings.get("game_audio_dir", "")

        if not game_audio_dir or not Path(game_audio_dir).exists():
            self.mod_manager_bridge.errorOccurred.emit(
                "Error",
                "Game audio directory not set. Please configure it in Settings first.",
            )
            return

        save_path = NativeDialogs.get_save_file(
            "Save .zzar Mod Package",
            str(Path.home() / f"{wizard_data['modName']}.zzar"),
            "ZZAR Mod Packages (*.zzar)",
        )

        if not save_path:
            print("[Import Wizard] Save cancelled")
            return

        if not save_path.endswith(".zzar"):
            save_path += ".zzar"

        print(f"[Import Wizard] Saving to: {save_path}")

        QMetaObject.invokeMethod(self.import_wizard, "startImporting", Qt.QueuedConnection)

        import_mode = wizard_data["importMode"]
        files_dict = {}

        for file_path in self.wizard_selected_files:
            file_id = Path(file_path).stem
            files_dict[file_id] = {"path": file_path}

        import_data = {
            "import_mode": import_mode,
            "files": files_dict,
            "metadata": {
                "name": wizard_data["modName"],
                "author": wizard_data["modAuthor"],
                "version": wizard_data["modVersion"],
                "description": wizard_data["modDescription"],
            },
            "thumbnail": wizard_data.get("thumbnailPath", ""),
            "save_path": save_path,
        }

        from gui.backend.import_worker import ImportWorker

        self.import_worker = ImportWorker(
            import_data, game_audio_dir, self.mod_manager_bridge.mod_package_manager
        )

        self.import_worker.progress.connect(self.on_import_progress)
        self.import_worker.progressPercent.connect(self.on_import_percent)
        self.import_worker.finished.connect(self.on_import_finished)
        self.import_worker.start()

    def on_wizard_cancelled(self):
        print("[Import Wizard] Wizard cancelled")
        self.wizard_selected_files = []
        self.wizard_selected_folder = ""

    def on_import_progress(self, message):
        print(f"[Import Worker] {message}")
        if self.import_wizard:
            self.import_wizard.setProperty("importStatus", message)

    def on_import_percent(self, percent):
        if self.import_wizard:
            self.import_wizard.setProperty("importPercent", percent)

    def on_import_finished(self, success, message):
        if self.import_wizard:
            QMetaObject.invokeMethod(self.import_wizard, "finishImporting", Qt.QueuedConnection)

        if success:
            print(f"[Import Worker] Success: {message}")
            self.mod_manager_bridge.progressUpdate.emit(message)
            self.mod_manager_bridge.refreshMods()
        else:
            print(f"[Import Worker] Error: {message}")
            self.mod_manager_bridge.errorOccurred.emit("Import Error", message)

        self.import_worker = None
        self.wizard_selected_files = []
        self.wizard_selected_folder = ""
