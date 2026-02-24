import os
import sys

from PyQt5.QtCore import QObject, QMetaObject, Q_ARG, Qt, QCoreApplication
from PyQt5.QtWidgets import QApplication

from src.config_manager import get_cache_dir


class UpdateConnector:

    def _connect_updates(self):
        if not self.settings_page:
            return

        from ZZAR import DEV_MODE
        self.settings_page.setProperty("devMode", DEV_MODE)

        settings = self.load_settings()
        self.settings_page.setProperty("githubToken", settings.get("github_token", ""))

        self.settings_page.checkForUpdatesClicked.connect(self._on_check_for_updates)
        self.settings_page.downloadUpdateClicked.connect(
            self.update_manager_bridge.downloadAndInstall
        )
        self.settings_page.restartClicked.connect(self._on_restart_for_update)
        self.settings_page.githubTokenSaved.connect(self._on_github_token_changed)
        self.settings_page.testUpdateDialogClicked.connect(self._on_test_update_dialog)
        if hasattr(self.settings_page, 'redoTutorialClicked'):
            self.settings_page.redoTutorialClicked.connect(self.on_start_tutorial)

        self.update_manager_bridge.updateAvailable.connect(self._on_update_available)
        self.update_manager_bridge.updateNotAvailable.connect(self._on_update_not_available)
        self.update_manager_bridge.updateProgress.connect(self._on_update_progress)
        self.update_manager_bridge.updateDownloaded.connect(self._on_update_downloaded)
        self.update_manager_bridge.updateError.connect(self._on_update_error)
        self.update_manager_bridge.updateApplied.connect(self._on_update_applied)

        print("[ZZAR] Settings page connected")

    def _on_check_for_updates(self):
        if self.settings_page:
            self.settings_page.setProperty("isCheckingUpdates", True)
            self.settings_page.setProperty("updateAvailable", False)
            self.settings_page.setProperty("updateDownloaded", False)
        self.update_manager_bridge.checkForUpdates()

    def _on_update_available(self, version, release_notes):
        print(f"[ZZAR] Update available: {version}")
        if self.settings_page:
            self.settings_page.setProperty("isCheckingUpdates", False)
            self.settings_page.setProperty("updateAvailable", True)
            self.settings_page.setProperty("latestVersion", version)

        if os.environ.get('ZZAR_FLATPAK'):
            # In Flatpak, show an alert instead of the download dialog
            if self._startup_update_check:
                QMetaObject.invokeMethod(
                    self.root,
                    "showAlertDialog",
                    Qt.QueuedConnection,
                    Q_ARG("QVariant", self.tr("Update Available — v%1").replace("%1", version)),
                    Q_ARG("QVariant",
                           self.tr("A new version of ZZAR is available!\n\n"
                           "Update your Flatpak to the latest version:\n\n"
                           "new .flatpak file can be downloaded from https://github.com/Pucas01/ZZAR/releases")),
                    Q_ARG("QVariant", ""),
                )
        elif self._startup_update_check and self.update_dialog:
            QMetaObject.invokeMethod(
                self.root,
                "showUpdateDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", version),
                Q_ARG("QVariant", release_notes),
            )
        self._startup_update_check = False

    def _on_update_not_available(self):
        print("[ZZAR] Already up to date")
        was_startup = self._startup_update_check
        self._startup_update_check = False
        if self.settings_page:
            self.settings_page.setProperty("isCheckingUpdates", False)
            self.settings_page.setProperty("updateAvailable", False)
        if not was_startup:
            QMetaObject.invokeMethod(
                self.root,
                "showSuccessToast",
                Qt.QueuedConnection,
                Q_ARG("QVariant", self.tr("You're running the latest version!")),
            )

    def _on_update_progress(self, percent):
        if self.settings_page:
            self.settings_page.setProperty("downloadPercent", percent)
        if self.update_dialog:
            self.update_dialog.setProperty("downloadPercent", percent)

    def _on_update_downloaded(self):
        print("[ZZAR] Update downloaded, ready to install")
        if self.settings_page:
            self.settings_page.setProperty("isDownloadingUpdate", False)
            self.settings_page.setProperty("updateDownloaded", True)
        if self.update_dialog and self.update_dialog.property("visible"):
            self.update_dialog.setProperty("isDownloading", False)
            QMetaObject.invokeMethod(self.update_dialog, "hide", Qt.QueuedConnection)
            self._on_restart_for_update()

    def _on_update_error(self, message):
        print(f"[ZZAR] Update error: {message}")
        was_startup = self._startup_update_check
        self._startup_update_check = False
        if self.settings_page:
            self.settings_page.setProperty("isCheckingUpdates", False)
            self.settings_page.setProperty("isDownloadingUpdate", False)
        if self.update_dialog and self.update_dialog.property("visible"):
            self.update_dialog.setProperty("isDownloading", False)
            QMetaObject.invokeMethod(self.update_dialog, "hide", Qt.QueuedConnection)
        if not was_startup:
            QMetaObject.invokeMethod(
                self.root,
                "showErrorToast",
                Qt.QueuedConnection,
                Q_ARG("QVariant", self.tr("Update error: %1").replace("%1", message)),
            )

    def _on_github_token_changed(self, token):
        self.update_manager_bridge.setGithubToken(token)
        QMetaObject.invokeMethod(
            self.root,
            "showSuccessToast",
            Qt.QueuedConnection,
            Q_ARG("QVariant", self.tr("GitHub token saved")),
        )

    def _on_test_update_dialog(self):
        print("[ZZAR] Test update dialog triggered")
        if self.update_dialog:
            QMetaObject.invokeMethod(
                self.root,
                "showUpdateDialog",
                Qt.QueuedConnection,
                Q_ARG("QVariant", "99.0.0"),
                Q_ARG("QVariant", "## Test Release\n\n- This is a test changelog entry\n- Another cool feature\n- Bug fixes and improvements\n\nThis dialog is for testing only."),
            )

    def _on_update_dialog_accepted(self):
        print("[ZZAR] User accepted update from dialog")
        self.update_manager_bridge.downloadAndInstall()

    def _on_update_dialog_dismissed(self):
        print("[ZZAR] User dismissed update dialog")

    def _on_restart_for_update(self):
        print("[ZZAR] Applying update and restarting...")
        self.update_manager_bridge.applyUpdate()

    def _on_update_applied(self):
        print("[ZZAR] Update applied successfully, restarting application...")
        try:
            flag_file = get_cache_dir() / "update_success"
            flag_file.parent.mkdir(parents=True, exist_ok=True)
            flag_file.write_text(QCoreApplication.applicationVersion())
            print(f"[ZZAR] Update success flag written: {flag_file}")
        except Exception as e:
            print(f"[ZZAR] Failed to write update success flag: {e}")

        if sys.platform.startswith("win"):
            QApplication.quit()
        else:
            exe = self.update_manager_bridge._get_real_exe_path()
            print(f"[ZZAR] Launching updated binary: {exe}")
            import subprocess
            subprocess.Popen(
                [exe],
                start_new_session=True,
            )
            QApplication.quit()

    def _check_update_success_flag(self):
        try:
            flag_file = get_cache_dir() / "update_success"
            if flag_file.exists():
                old_version = flag_file.read_text().strip()
                flag_file.unlink()
                new_version = QCoreApplication.applicationVersion()
                print(f"[ZZAR] Update success! {old_version} -> {new_version}")
                QMetaObject.invokeMethod(
                    self.root,
                    "showSuccessDialog",
                    Qt.QueuedConnection,
                    Q_ARG("QVariant", self.tr("Update Successful!")),
                    Q_ARG("QVariant", self.tr("ZZAR has been updated to version %1.").replace("%1", new_version)),
                    Q_ARG("QVariant", "../assets/VivianHappy.png"),
                )
        except Exception as e:
            print(f"[ZZAR] Error checking update success flag: {e}")
