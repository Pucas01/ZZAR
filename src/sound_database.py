

import json
import hashlib
import shutil
from pathlib import Path
from datetime import datetime

from src.config_manager import get_sound_database_file

class SoundDatabase:


    def __init__(self, db_path=None):

        if db_path is None:
            self.db_path = get_sound_database_file()
        else:
            self.db_path = Path(db_path)

        self._migrate_old_location()
        self.database = {}
        self.load()

    def _migrate_old_location(self):
        old_path = Path.home() / '.zzar_sound_db.json'
        if old_path.exists() and not self.db_path.exists():
            try:
                self.db_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(old_path), str(self.db_path))
                print(f"[SoundDB] Migrated {old_path} -> {self.db_path}")
            except Exception as e:
                print(f"[SoundDB] Migration failed, copying instead: {e}")
                try:
                    shutil.copy2(old_path, self.db_path)
                except Exception as e2:
                    print(f"[SoundDB] Copy also failed: {e2}")

    def calculate_hash(self, file_bytes):

        return hashlib.sha256(file_bytes).hexdigest()

    def add_sound(self, file_bytes, name, tags=None, notes="", file_id=None):

        sound_hash = self.calculate_hash(file_bytes)
        now = datetime.now().isoformat()

        if sound_hash in self.database:
            entry = self.database[sound_hash]
            entry['name'] = name
            entry['tags'] = tags or []
            entry['notes'] = notes
            entry['date_modified'] = now

            if file_id is not None and file_id not in entry['file_ids']:
                entry['file_ids'].append(file_id)
        else:

            self.database[sound_hash] = {
                'name': name,
                'tags': tags or [],
                'notes': notes,
                'file_ids': [file_id] if file_id is not None else [],
                'date_added': now,
                'date_modified': now
            }

        self.save()
        return sound_hash

    def get_sound_info(self, file_bytes):

        sound_hash = self.calculate_hash(file_bytes)
        return self.database.get(sound_hash)

    def search_by_name(self, query):

        query_lower = query.lower()
        results = {}

        for sound_hash, info in self.database.items():
            if query_lower in info['name'].lower():
                results[sound_hash] = info

        return results

    def search_by_tag(self, tag):

        tag_lower = tag.lower()
        results = {}

        for sound_hash, info in self.database.items():
            if any(tag_lower in t.lower() for t in info['tags']):
                results[sound_hash] = info

        return results

    def search_by_id(self, file_id):

        results = {}

        for sound_hash, info in self.database.items():
            if file_id in info['file_ids']:
                results[sound_hash] = info

        return results

    def delete_sound(self, sound_hash):

        if sound_hash in self.database:
            del self.database[sound_hash]
            self.save()
            return True
        return False

    def load(self):

        try:
            if self.db_path.exists():
                with open(self.db_path, 'r') as f:
                    self.database = json.load(f)
        except Exception as e:
            print(f"Warning: Failed to load sound database: {e}")
            self.database = {}

    def save(self):

        try:
            with open(self.db_path, 'w') as f:
                json.dump(self.database, f, indent=2)
        except Exception as e:
            print(f"Warning: Failed to save sound database: {e}")

    def export_to_file(self, export_path):

        export_path = Path(export_path)
        with open(export_path, 'w') as f:
            json.dump(self.database, f, indent=2)

    def import_from_file(self, import_path, merge=True):

        import_path = Path(import_path)

        with open(import_path, 'r') as f:
            imported_data = json.load(f)

        if merge:

            count = 0
            for sound_hash, info in imported_data.items():
                if sound_hash not in self.database:
                    count += 1
                self.database[sound_hash] = info
        else:

            count = len(imported_data)
            self.database = imported_data

        self.save()
        return count

    def get_stats(self):

        total_sounds = len(self.database)
        tagged_sounds = sum(1 for info in self.database.values() if info['tags'])
        total_tags = set()
        for info in self.database.values():
            total_tags.update(info['tags'])

        return {
            'total_sounds': total_sounds,
            'tagged_sounds': tagged_sounds,
            'total_unique_tags': len(total_tags),
            'all_tags': sorted(list(total_tags))
        }

    def get_all_tags(self):

        all_tags = set()
        for info in self.database.values():
            all_tags.update(info['tags'])
        return sorted(list(all_tags))
