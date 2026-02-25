

import json
import hashlib
import threading
from pathlib import Path
from datetime import datetime

from src.config_manager import get_fingerprint_database_file

class FingerprintDatabase:
    

    FINGERPRINT_VERSION = "1.0"

    def __init__(self, db_path=None):

        if db_path is None:
            self.db_path = get_fingerprint_database_file()
        else:
            self.db_path = Path(db_path)

        self.database = {}
        self.lock = threading.Lock()
        self._pending_saves = 0
        self.load()

    def calculate_hash(self, file_bytes):

        return hashlib.sha256(file_bytes).hexdigest()

    def add_fingerprint(self, file_bytes, fingerprint):
        
        sound_hash = self.calculate_hash(file_bytes)
        with self.lock:
            self.database[sound_hash] = {
                'fingerprint': fingerprint,
                'version': self.FINGERPRINT_VERSION,
                'generated': datetime.now().isoformat()
            }
            self._pending_saves += 1

            if self._pending_saves >= 100:
                self._save_unlocked()
                self._pending_saves = 0

    def get_fingerprint(self, file_bytes):
        
        sound_hash = self.calculate_hash(file_bytes)

        entry = self.database.get(sound_hash)
        if entry and 'fingerprint' in entry:

            if entry.get('version') == self.FINGERPRINT_VERSION:
                return entry['fingerprint']
        return None

    def has_fingerprint(self, file_bytes):
        
        sound_hash = self.calculate_hash(file_bytes)
        entry = self.database.get(sound_hash)
        return entry is not None and entry.get('version') == self.FINGERPRINT_VERSION

    def load(self):
        
        try:
            if self.db_path.exists():
                with open(self.db_path, 'r') as f:
                    self.database = json.load(f)
        except Exception as e:
            print(f"[FingerprintDB] Failed to load: {e}")
            self.database = {}

    def _save_unlocked(self):
        
        try:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)

            db_snapshot = dict(self.database)
            with open(self.db_path, 'w') as f:
                json.dump(db_snapshot, f, indent=2)
        except Exception as e:
            print(f"[FingerprintDB] Failed to save: {e}")

    def save(self):
        
        with self.lock:
            self._save_unlocked()
            self._pending_saves = 0

    def get_stats(self):
        
        total = len(self.database)
        current_version = sum(1 for e in self.database.values()
                             if e.get('version') == self.FINGERPRINT_VERSION)

        return {
            'total_fingerprints': total,
            'current_version_count': current_version,
            'outdated_count': total - current_version
        }
