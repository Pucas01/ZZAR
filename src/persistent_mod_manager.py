

import json
import shutil
from pathlib import Path
from datetime import datetime
from src.config_manager import get_mod_tracker_file

class PersistentModManager:


    def __init__(self, persistent_base_path=None):

        self.persistent_base_path = Path(persistent_base_path) if persistent_base_path else None
        self.mod_tracker_path = get_mod_tracker_file()
        self.mod_tracker = {}

        self._migrate_old_tracker()

        self.load_tracker()

    def set_persistent_path(self, path):

        self.persistent_base_path = Path(path)

    def add_replacement(self, pck_filename, file_id, wem_path, file_type='wem', lang_id=0, bnk_id=None):

        if pck_filename not in self.mod_tracker:
            self.mod_tracker[pck_filename] = {}

        key = f"{bnk_id}|{file_id}" if bnk_id is not None else str(file_id)
        self.mod_tracker[pck_filename][key] = {
            'wem_path': str(wem_path),
            'file_type': file_type,
            'lang_id': lang_id,
            'bnk_id': bnk_id,
            'date_modified': datetime.now().isoformat()
        }

        self.save_tracker()

    def get_replacements(self, pck_filename):

        return self.mod_tracker.get(pck_filename, {})

    def has_replacements(self, pck_filename):

        return pck_filename in self.mod_tracker and len(self.mod_tracker[pck_filename]) > 0

    def remove_replacement(self, pck_filename, file_id, bnk_id=None):
        key = f"{bnk_id}|{file_id}" if bnk_id is not None else str(file_id)

        if pck_filename in self.mod_tracker:
            if key in self.mod_tracker[pck_filename]:
                del self.mod_tracker[pck_filename][key]

                if not self.mod_tracker[pck_filename]:
                    del self.mod_tracker[pck_filename]

                self.save_tracker()
                return True
        return False

    def clear_pck_mods(self, pck_filename):

        if pck_filename in self.mod_tracker:
            del self.mod_tracker[pck_filename]
            self.save_tracker()
            return True
        return False

    def get_persistent_pck_path(self, pck_filename):

        if not self.persistent_base_path:
            raise ValueError("Persistent path not set")

        return self.persistent_base_path / pck_filename

    def _migrate_old_tracker(self):

        old_tracker = Path.home() / '.zzar_mod_tracker.json'

        if old_tracker.exists() and not self.mod_tracker_path.exists():
            try:
                shutil.copy2(old_tracker, self.mod_tracker_path)
                print(f"Migrated mod tracker: {old_tracker} -> {self.mod_tracker_path}")
            except Exception as e:
                print(f"Warning: Failed to migrate mod tracker: {e}")

    def load_tracker(self):

        try:
            if self.mod_tracker_path.exists():
                with open(self.mod_tracker_path, 'r') as f:
                    self.mod_tracker = json.load(f)
        except Exception as e:
            print(f"Warning: Failed to load mod tracker: {e}")
            self.mod_tracker = {}

    def save_tracker(self):

        try:
            with open(self.mod_tracker_path, 'w') as f:
                json.dump(self.mod_tracker, f, indent=2)
        except Exception as e:
            print(f"Warning: Failed to save mod tracker: {e}")

    def get_stats(self):

        total_pcks = len(self.mod_tracker)
        total_replacements = sum(len(repl) for repl in self.mod_tracker.values())

        return {
            'modded_pcks': total_pcks,
            'total_replacements': total_replacements,
            'pcks': list(self.mod_tracker.keys())
        }

    def export_mod_list(self, export_path):

        export_path = Path(export_path)
        with open(export_path, 'w') as f:
            json.dump(self.mod_tracker, f, indent=2)

    def get_all_replacements(self):

        return self.mod_tracker

    def clear_all_replacements(self):

        self.mod_tracker = {}
        self.save_tracker()

    def import_replacements_from_mods(self, resolved_mods):

        self.mod_tracker = resolved_mods
        self.save_tracker()
