

import sys
import os
from pathlib import Path
from src.app_config import CONFIG_DIR_NAME

class ConfigManager:

    def __init__(self):
        self.platform = sys.platform
        self._config_dir = None
        self._data_dir = None
        self._custom_mod_library_dir = None

    @property
    def config_dir(self):

        if self._config_dir:
            return self._config_dir

        if self.platform == 'win32':

            appdata = Path(os.environ.get('APPDATA', Path.home() / 'AppData' / 'Roaming'))
            self._config_dir = appdata / CONFIG_DIR_NAME
        else:

            xdg_config = os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')
            self._config_dir = Path(xdg_config) / CONFIG_DIR_NAME

        self._config_dir.mkdir(parents=True, exist_ok=True)
        return self._config_dir

    @property
    def data_dir(self):

        if self._data_dir:
            return self._data_dir

        if self.platform == 'win32':

            localappdata = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData' / 'Local'))
            self._data_dir = localappdata / CONFIG_DIR_NAME
        else:

            xdg_data = os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')
            self._data_dir = Path(xdg_data) / CONFIG_DIR_NAME

        self._data_dir.mkdir(parents=True, exist_ok=True)
        return self._data_dir

    @property
    def settings_file(self):

        return self.config_dir / 'settings.json'

    @property
    def mod_config_file(self):

        return self.config_dir / 'mod_config.json'

    @property
    def mod_tracker_file(self):

        return self.config_dir / 'mod_tracker.json'

    @property
    def default_mod_library_dir(self):
        return self.data_dir / 'mod_library'

    @property
    def mod_library_dir(self):
        if self._custom_mod_library_dir:
            return self._custom_mod_library_dir
        return self.default_mod_library_dir

    def set_mod_library_dir(self, path):
        if path:
            self._custom_mod_library_dir = Path(path)
        else:
            self._custom_mod_library_dir = None

    @property
    def cache_dir(self):

        return self.data_dir / 'cache'

    @property
    def sound_database_file(self):

        return self.data_dir / 'sound_database.json'

    @property
    def fingerprint_database_file(self):

        return self.data_dir / 'fingerprint_database.json'

    def migrate_old_config(self):

        import shutil
        import json

        migrations = [
            (Path.home() / '.zzar_settings.json', self.settings_file),
            (Path.home() / '.zzar_mod_config.json', self.mod_config_file),
            (Path.home() / '.zzar_mod_tracker.json', self.mod_tracker_file),
        ]

        migrated = []

        for old_path, new_path in migrations:
            if old_path.exists() and not new_path.exists():
                try:
                    shutil.copy2(old_path, new_path)
                    migrated.append(f"Migrated {old_path.name} -> {new_path}")
                except Exception as e:
                    print(f"Warning: Failed to migrate {old_path}: {e}")

        old_mod_lib = Path.home() / '.zzar_mod_library'
        new_mod_lib = self.mod_library_dir

        if old_mod_lib.exists() and not new_mod_lib.exists():
            try:
                shutil.copytree(old_mod_lib, new_mod_lib)
                migrated.append(f"Migrated mod library -> {new_mod_lib}")
            except Exception as e:
                print(f"Warning: Failed to migrate mod library: {e}")

        return migrated

    def get_legacy_paths(self):

        legacy = {}

        old_settings = Path.home() / '.zzar_settings.json'
        if old_settings.exists():
            legacy['settings'] = old_settings

        old_mod_config = Path.home() / '.zzar_mod_config.json'
        if old_mod_config.exists():
            legacy['mod_config'] = old_mod_config

        old_mod_tracker = Path.home() / '.zzar_mod_tracker.json'
        if old_mod_tracker.exists():
            legacy['mod_tracker'] = old_mod_tracker

        old_mod_library = Path.home() / '.zzar_mod_library'
        if old_mod_library.exists():
            legacy['mod_library'] = old_mod_library

        return legacy

import os
_config_manager = ConfigManager()

def get_config_manager():

    return _config_manager

def get_config_dir():

    return _config_manager.config_dir

def get_data_dir():

    return _config_manager.data_dir

def get_settings_file():

    return _config_manager.settings_file

def get_mod_config_file():

    return _config_manager.mod_config_file

def get_mod_tracker_file():

    return _config_manager.mod_tracker_file

def get_mod_library_dir():

    return _config_manager.mod_library_dir

def get_default_mod_library_dir():

    return _config_manager.default_mod_library_dir

def set_mod_library_dir(path):

    _config_manager.set_mod_library_dir(path)

def get_cache_dir():

    return _config_manager.cache_dir

def get_sound_database_file():

    return _config_manager.sound_database_file

def get_fingerprint_database_file():

    return _config_manager.fingerprint_database_file
