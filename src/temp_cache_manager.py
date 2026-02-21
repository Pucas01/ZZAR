

import atexit
import tempfile
import shutil
from pathlib import Path
from collections import OrderedDict

class TempCacheManager:


    def __init__(self, max_cached_files=100):

        from ZZAR import get_temp_dir
        self.cache_dir = Path(tempfile.mkdtemp(prefix='zzar_audio_cache_', dir=str(get_temp_dir())))
        self.max_cached_files = max_cached_files
        self.cache_index = OrderedDict()

        atexit.register(self.cleanup)

    def get_cache_key(self, pck_path, file_id, file_type):

        pck_name = Path(pck_path).name
        return f"{pck_name}:{file_id}:{file_type}"

    def get_cached_path(self, cache_key):

        if cache_key in self.cache_index:

            self.cache_index.move_to_end(cache_key)
            cached_path = self.cache_index[cache_key]

            if cached_path.exists():
                return cached_path
            else:

                del self.cache_index[cache_key]
                return None

        return None

    def add_to_cache(self, cache_key, file_data, extension='.wav'):


        if len(self.cache_index) >= self.max_cached_files:
            oldest_key, oldest_path = self.cache_index.popitem(last=False)
            oldest_path.unlink(missing_ok=True)

        safe_key = cache_key.replace(':', '_').replace('/', '_')
        cache_file = self.cache_dir / f"{safe_key}{extension}"
        cache_file.write_bytes(file_data)

        self.cache_index[cache_key] = cache_file
        return cache_file

    def cleanup(self):

        if self.cache_dir.exists():
            try:
                shutil.rmtree(self.cache_dir, ignore_errors=True)
            except Exception:
                pass

    def get_cache_size(self):

        total_size = 0
        for cache_path in self.cache_index.values():
            if cache_path.exists():
                total_size += cache_path.stat().st_size
        return total_size

    def clear_cache(self):

        for cache_path in list(self.cache_index.values()):
            cache_path.unlink(missing_ok=True)
        self.cache_index.clear()

    def get_cache_info(self):

        file_count = len(self.cache_index)
        total_size = self.get_cache_size()
        total_size_mb = total_size / (1024 * 1024)

        return {
            'file_count': file_count,
            'total_size_bytes': total_size,
            'total_size_mb': round(total_size_mb, 2),
            'cache_dir': str(self.cache_dir),
            'max_files': self.max_cached_files
        }
