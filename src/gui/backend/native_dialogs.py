import sys
import subprocess
import os
from pathlib import Path
from PyQt5.QtWidgets import QFileDialog

class NativeDialogs:
    @staticmethod
    def _is_linux():
        return sys.platform.startswith("linux")

    @staticmethod
    def _get_clean_env():
        """Get environment for running system commands like zenity.
        PyInstaller sets LD_LIBRARY_PATH to its bundled libs, which crashes
        system GTK apps. Restore the original value so they find their own libs."""
        env = os.environ.copy()
        if hasattr(sys, '_MEIPASS'):
            orig = env.get('LD_LIBRARY_PATH_ORIG')
            if orig is not None:
                env['LD_LIBRARY_PATH'] = orig
            else:
                env.pop('LD_LIBRARY_PATH', None)
        return env

    @staticmethod
    def _zenity_available():

        try:
            subprocess.run(
                ["zenity", "--version"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
                env=NativeDialogs._get_clean_env(),
            )
            return True
        except (FileNotFoundError, subprocess.CalledProcessError):
            return False
        except Exception as e:
            print(f"Zenity check error: {e}")
            return False

    @staticmethod
    def _run_zenity(args):

        try:
            cmd = ["zenity"] + args
            result = subprocess.run(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                env=NativeDialogs._get_clean_env(),
            )
            if result.returncode == 0:
                return (True, result.stdout.strip())
            return (True, None)
        except Exception as e:
            print(f"Native dialog error: {e}")
            return (False, None)

    @staticmethod
    def _parse_qt_filters(filter_str):


        zenity_args = []
        if not filter_str:
            return zenity_args

        filters = filter_str.split(";;")
        for f in filters:
            f = f.strip()
            if not f:
                continue

            if "(" in f and ")" in f:
                name = f.split("(")[0].strip()
                patterns = f.split("(")[1].split(")")[0]
                zenity_args.append(f"--file-filter={name} | {patterns}")
            else:

                zenity_args.append(f"--file-filter={f} | {f}")

        return zenity_args

    @staticmethod
    def get_open_file(title="Open File", start_dir=None, filter_str=""):

        if NativeDialogs._is_linux() and NativeDialogs._zenity_available():
            args = ["--file-selection", f"--title={title}"]
            if start_dir:
                args.append(f"--filename={start_dir}/")

            args.extend(NativeDialogs._parse_qt_filters(filter_str))

            success, res = NativeDialogs._run_zenity(args)
            if success:
                return res if res else ""

        path, _ = QFileDialog.getOpenFileName(None, title, start_dir or "", filter_str)
        return path

    @staticmethod
    def get_open_files(title="Select Files", start_dir=None, filter_str=""):

        if NativeDialogs._is_linux() and NativeDialogs._zenity_available():
            args = [
                "--file-selection",
                "--multiple",
                "--separator=|",
                f"--title={title}",
            ]
            if start_dir:
                args.append(f"--filename={start_dir}/")

            args.extend(NativeDialogs._parse_qt_filters(filter_str))

            success, res = NativeDialogs._run_zenity(args)
            if success:
                return res.split("|") if res else []

        paths, _ = QFileDialog.getOpenFileNames(
            None, title, start_dir or "", filter_str
        )
        return paths

    @staticmethod
    def get_directory(title="Select Directory", start_dir=None):

        if NativeDialogs._is_linux() and NativeDialogs._zenity_available():
            args = ["--file-selection", "--directory", f"--title={title}"]
            if start_dir:
                args.append(f"--filename={start_dir}/")

            success, res = NativeDialogs._run_zenity(args)
            if success:
                return res if res else ""

        return QFileDialog.getExistingDirectory(None, title, start_dir or "")

    @staticmethod
    def get_save_file(title="Save File", start_dir=None, filter_str=""):

        if NativeDialogs._is_linux() and NativeDialogs._zenity_available():
            args = [
                "--file-selection",
                "--save",
                "--confirm-overwrite",
                f"--title={title}",
            ]
            if start_dir:
                args.append(f"--filename={start_dir}")

            args.extend(NativeDialogs._parse_qt_filters(filter_str))

            success, res = NativeDialogs._run_zenity(args)
            if success:
                return res if res else ""

        path, _ = QFileDialog.getSaveFileName(None, title, start_dir or "", filter_str)
        return path
