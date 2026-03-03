

import json
import re
import urllib.request
import urllib.error
import urllib.parse
from pathlib import Path
from PyQt5.QtCore import QObject, pyqtSlot, pyqtSignal, QThread

IMAGE_EXTENSIONS = ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg')
VIDEO_EXTENSIONS = ('.mp4', '.webm')

def extract_media_from_html(html_text):
    
    if not html_text:
        return '', [], []

    images = []
    videos = []

    for url in re.findall(r'<img[^>]+src=["\']([^"\']+)["\']', html_text, re.IGNORECASE):
        lower = url.lower().split('?')[0]
        if lower.endswith(IMAGE_EXTENSIONS):
            images.append(url)
        elif lower.endswith(VIDEO_EXTENSIONS):
            videos.append(url)

    for url in re.findall(r'<a[^>]+href=["\']([^"\']+)["\']', html_text, re.IGNORECASE):
        lower = url.lower().split('?')[0]
        if lower.endswith(IMAGE_EXTENSIONS) and url not in images:
            images.append(url)
        elif lower.endswith(VIDEO_EXTENSIONS) and url not in videos:
            videos.append(url)

    for url in re.findall(r'<(?:video|source)[^>]+src=["\']([^"\']+)["\']', html_text, re.IGNORECASE):
        lower = url.lower().split('?')[0]
        if lower.endswith(VIDEO_EXTENSIONS) and url not in videos:
            videos.append(url)

    for yt_id in re.findall(
        r'<iframe[^>]+src=["\']https?://(?:www\.)?youtube\.com/embed/([^"\'?/]+)',
        html_text, re.IGNORECASE
    ):
        yt_thumb = f"https://img.youtube.com/vi/{yt_id}/hqdefault.jpg"
        if yt_thumb not in images:
            images.append(yt_thumb)

    clean = re.sub(r'<img[^>]*/?>', '', html_text)
    clean = re.sub(r'<video[^>]*>.*?</video>', '', clean, flags=re.IGNORECASE | re.DOTALL)
    clean = re.sub(r'<video[^>]*/?>', '', clean, flags=re.IGNORECASE)

    return clean, images, videos

def is_visual_media(url):
    
    if not url:
        return False
    lower = url.lower().split('?')[0]
    return lower.endswith(IMAGE_EXTENSIONS + VIDEO_EXTENSIONS)

GAMEBANANA_API_BASE = "https://gamebanana.com/apiv11"
ZENLESS_ZONE_ZERO_GAME_ID = 19567

class FetchModsWorker(QThread):
    

    finished = pyqtSignal(bool, object)

    def __init__(self, page=1, per_page=20, sort="default", category=None):
        super().__init__()
        self.page = page
        self.per_page = per_page
        self.sort = sort
        self.category = category

    def run(self):
        try:

            filters = f"_aFilters[Generic_Game]={ZENLESS_ZONE_ZERO_GAME_ID}"

            params = {
                '_nPage': self.page,
                '_nPerpage': self.per_page,
            }

            if self.sort and self.sort != "default":
                params['_sOrderBy'] = self.sort

            if self.category:
                filters += f"&_aFilters[Generic_Category]={self.category}"

            url = f"{GAMEBANANA_API_BASE}/Sound/Index?{filters}&{urllib.parse.urlencode(params)}"

            print(f"[GameBanana] Fetching sound mods: {url}")

            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'ZZAR/1.1.0')

            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode('utf-8'))

                mods = []
                records = data.get('_aRecords', []) if isinstance(data, dict) else data

                if isinstance(records, list):
                    for mod_data in records:
                        try:
                            mod = self._parse_mod_data(mod_data)
                            if mod:
                                mods.append(mod)
                        except Exception as e:
                            print(f"[GameBanana] Error parsing mod: {e}")
                            continue

                print(f"[GameBanana] Parsed {len(mods)} mods from response")
                self.finished.emit(True, mods)

        except urllib.error.HTTPError as e:
            self.finished.emit(False, f"HTTP Error {e.code}: {e.reason}")
        except urllib.error.URLError as e:
            self.finished.emit(False, f"Network Error: {e.reason}")
        except Exception as e:
            import traceback
            self.finished.emit(False, f"Error: {str(e)}\n{traceback.format_exc()}")

    def _parse_mod_data(self, data):
        
        if not isinstance(data, dict):
            return None

        thumbnail = ''
        preview_media = data.get('_aPreviewMedia', {})
        if isinstance(preview_media, dict):
            images = preview_media.get('_aImages', [])
            if images and len(images) > 0:
                base_url = preview_media.get('_sBaseUrl', '')
                file_name = images[0].get('_sFile220', '') or images[0].get('_sFile', '')
                if base_url and file_name:
                    candidate = f"{base_url}/{file_name}"
                    if is_visual_media(candidate):
                        thumbnail = candidate

        submitter = data.get('_aSubmitter', {})
        author_name = submitter.get('_sName', 'Unknown') if isinstance(submitter, dict) else 'Unknown'
        author_id = submitter.get('_idRow', 0) if isinstance(submitter, dict) else 0

        root_category = data.get('_aRootCategory', {})
        category_name = root_category.get('_sName', 'Mod') if isinstance(root_category, dict) else 'Mod'

        raw_description = data.get('_sText', '')
        clean_description, desc_images, _desc_videos = extract_media_from_html(raw_description)

        if not desc_images:
            alt_description = data.get('_sDescription', '')
            if alt_description:
                _, alt_images, _ = extract_media_from_html(alt_description)
                if alt_images:
                    desc_images = alt_images

        if not thumbnail and desc_images:
            thumbnail = desc_images[0]

        return {
            'id': data.get('_idRow', 0),
            'name': data.get('_sName', 'Unknown'),
            'author': author_name,
            'author_id': author_id,
            'description': clean_description,
            'views': data.get('_nViewCount', 0),
            'downloads': data.get('_nDownloadCount', 0),
            'likes': data.get('_nLikeCount', 0),
            'date_added': data.get('_tsDateAdded', 0),
            'date_updated': data.get('_tsDateUpdated', 0),
            'thumbnail': thumbnail,
            'profile_url': data.get('_sProfileUrl', ''),
            'category': category_name,
        }

class FetchModDetailsWorker(QThread):
    

    finished = pyqtSignal(bool, object)

    def __init__(self, mod_id):
        super().__init__()
        self.mod_id = mod_id

    def run(self):
        try:

            fields = "name,Owner().name,text,description,views,likes,date,Files().aFiles(),Preview().sPreviewUrl()"
            url = f"https://api.gamebanana.com/Core/Item/Data?itemtype=Sound&itemid={self.mod_id}&fields={fields}"

            print(f"[GameBanana] Fetching sound details: {url}")

            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'ZZAR/1.1.0')

            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode('utf-8'))

                mod_details = self._parse_mod_details(data)

                # Also check ZZAR support for the detail view
                zzar_supported = self._check_zzar_support(mod_details)
                if mod_details:
                    mod_details['zzar_supported'] = zzar_supported

                self.finished.emit(True, mod_details)

        except urllib.error.HTTPError as e:
            self.finished.emit(False, f"HTTP Error {e.code}: {e.reason}")
        except urllib.error.URLError as e:
            self.finished.emit(False, f"Network Error: {e.reason}")
        except Exception as e:
            import traceback
            self.finished.emit(False, f"Error: {str(e)}\n{traceback.format_exc()}")

    def _parse_mod_details(self, data):
        

        if not isinstance(data, list) or len(data) < 9:
            print(f"[GameBanana] Invalid data format: {type(data)}, length: {len(data) if isinstance(data, list) else 'N/A'}")
            return None

        name = data[0] if len(data) > 0 else 'Unknown'
        owner_name = data[1] if len(data) > 1 else 'Unknown'
        text = data[2] if len(data) > 2 else ''
        description = data[3] if len(data) > 3 else ''
        views = data[4] if len(data) > 4 else 0
        likes = data[5] if len(data) > 5 else 0
        date = data[6] if len(data) > 6 else 0
        files_data = data[7] if len(data) > 7 else []
        preview_url = data[8] if len(data) > 8 else ''

        author_name = owner_name if owner_name else 'Unknown'
        author_avatar = ''

        files = []
        if isinstance(files_data, dict):
            for file_id, file_info in files_data.items():
                if isinstance(file_info, dict):
                    files.append({
                        'id': file_id,
                        'name': file_info.get('_sFile', 'Unknown'),
                        'description': file_info.get('_sDescription', ''),
                        'size': file_info.get('_nFilesize', 0),
                        'download_url': file_info.get('_sDownloadUrl', ''),
                        'downloads': file_info.get('_nDownloadCount', 0),
                    })

        raw_text = text if text else description
        clean_description, desc_images, desc_videos = extract_media_from_html(raw_text)

        thumbnail_url = preview_url if is_visual_media(preview_url) else ''
        if not thumbnail_url and desc_images:
            thumbnail_url = desc_images[0]

        return {
            'id': self.mod_id,
            'name': name,
            'author': author_name,
            'author_id': 0,
            'author_avatar': author_avatar,
            'description': clean_description,
            'description_images': desc_images,
            'description_videos': desc_videos,
            'views': views,
            'downloads': sum(f.get('downloads', 0) for f in files),
            'likes': likes,
            'date_added': date,
            'date_updated': date,
            'thumbnail': thumbnail_url,
            'profile_url': f"https://gamebanana.com/sounds/{self.mod_id}",
            'category': 'Sound',
            'files': files,
            'zzar_supported': False,
        }

    def _check_zzar_support(self, mod_details):
        if not mod_details:
            return False

        # Check file archive contents for .zzar files
        files = mod_details.get('files', [])
        for f in files:
            file_id = f.get('id', '')
            if file_id:
                try:
                    url = f"https://gamebanana.com/apiv11/File/{file_id}"
                    req = urllib.request.Request(url, headers={'User-Agent': 'ZZAR/1.1.0'})
                    with urllib.request.urlopen(req, timeout=8) as response:
                        data = json.loads(response.read().decode('utf-8'))
                    tree = data.get('_aArchiveFileTree', []) if isinstance(data, dict) else []
                    if self._tree_has_zzar(tree):
                        return True
                except Exception:
                    pass

        # Check requirements from v11 ProfilePage
        try:
            url = f"https://gamebanana.com/apiv11/Sound/{self.mod_id}/ProfilePage"
            req = urllib.request.Request(url, headers={'User-Agent': 'ZZAR/1.1.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode('utf-8'))
            requirements = data.get('_aRequirements', []) if isinstance(data, dict) else []
            for req_item in requirements:
                if isinstance(req_item, list) and len(req_item) > 0:
                    if req_item[0].lower() == 'zzar':
                        return True
        except Exception:
            pass

        return False

    def _tree_has_zzar(self, tree):
        if isinstance(tree, list):
            for item in tree:
                if isinstance(item, str) and item.lower().endswith('.zzar'):
                    return True
                elif isinstance(item, (dict, list)):
                    if self._tree_has_zzar(item):
                        return True
        elif isinstance(tree, dict):
            for key, value in tree.items():
                if isinstance(key, str) and key.lower().endswith('.zzar'):
                    return True
                if self._tree_has_zzar(value):
                    return True
        return False

class FetchThumbnailsWorker(QThread):
    

    thumbnailReady = pyqtSignal(int, str)

    CONCURRENT_REQUESTS = 5

    def __init__(self, mod_ids):
        super().__init__()
        self.mod_ids = mod_ids

    def _fetch_one(self, mod_id):
        
        try:
            url = f"https://api.gamebanana.com/Core/Item/Data?itemtype=Sound&itemid={mod_id}&fields=text"
            req = urllib.request.Request(url, headers={'User-Agent': 'ZZAR/1.1.0'})
            with urllib.request.urlopen(req, timeout=8) as response:
                data = json.loads(response.read().decode('utf-8'))

            text = data[0] if isinstance(data, list) and data else ''
            if text:
                _, images, _ = extract_media_from_html(text)
                if images:
                    return (mod_id, images[0])
        except Exception:
            pass
        return None

    def run(self):
        from concurrent.futures import ThreadPoolExecutor, as_completed

        with ThreadPoolExecutor(max_workers=self.CONCURRENT_REQUESTS) as pool:
            futures = {pool.submit(self._fetch_one, mid): mid for mid in self.mod_ids}
            for future in as_completed(futures):
                result = future.result()
                if result:
                    self.thumbnailReady.emit(result[0], result[1])

class FetchDownloadCountsWorker(QThread):

    downloadCountReady = pyqtSignal(int, int)

    CONCURRENT_REQUESTS = 5

    def __init__(self, mod_ids):
        super().__init__()
        self.mod_ids = mod_ids

    def _fetch_one(self, mod_id):
        try:
            url = f"https://api.gamebanana.com/Core/Item/Data?itemtype=Sound&itemid={mod_id}&fields=downloads"
            req = urllib.request.Request(url, headers={'User-Agent': 'ZZAR/1.1.0'})
            with urllib.request.urlopen(req, timeout=8) as response:
                data = json.loads(response.read().decode('utf-8'))

            downloads = data[0] if isinstance(data, list) and data else 0
            return (mod_id, int(downloads))
        except Exception:
            pass
        return None

    def run(self):
        from concurrent.futures import ThreadPoolExecutor, as_completed

        with ThreadPoolExecutor(max_workers=self.CONCURRENT_REQUESTS) as pool:
            futures = {pool.submit(self._fetch_one, mid): mid for mid in self.mod_ids}
            for future in as_completed(futures):
                result = future.result()
                if result:
                    self.downloadCountReady.emit(result[0], result[1])

class FetchZZARSupportWorker(QThread):

    zzarSupportReady = pyqtSignal(int, bool)

    CONCURRENT_REQUESTS = 5

    def __init__(self, mod_ids):
        super().__init__()
        self.mod_ids = mod_ids

    def _check_one(self, mod_id):
        try:
            # Check requirements from v11 ProfilePage
            url = f"https://gamebanana.com/apiv11/Sound/{mod_id}/ProfilePage"
            req = urllib.request.Request(url, headers={'User-Agent': 'ZZAR/1.1.0'})
            with urllib.request.urlopen(req, timeout=10) as response:
                data = json.loads(response.read().decode('utf-8'))

            # Check _aRequirements for ZZAR
            requirements = data.get('_aRequirements', []) if isinstance(data, dict) else []
            for req_item in requirements:
                if isinstance(req_item, list) and len(req_item) > 0:
                    if req_item[0].lower() == 'zzar':
                        return (mod_id, True)

            # Check file archive contents for .zzar files
            files_data = data.get('_aFiles', []) if isinstance(data, dict) else []
            if isinstance(files_data, list):
                for file_entry in files_data:
                    if isinstance(file_entry, dict):
                        file_id = file_entry.get('_idRow', 0)
                        if file_id:
                            if self._check_file_contents(file_id):
                                return (mod_id, True)
        except Exception as e:
            print(f"[GameBanana] Error checking ZZAR support for {mod_id}: {e}")
        return (mod_id, False)

    def _check_file_contents(self, file_id):
        try:
            url = f"https://gamebanana.com/apiv11/File/{file_id}"
            req = urllib.request.Request(url, headers={'User-Agent': 'ZZAR/1.1.0'})
            with urllib.request.urlopen(req, timeout=8) as response:
                data = json.loads(response.read().decode('utf-8'))

            tree = data.get('_aArchiveFileTree', []) if isinstance(data, dict) else []
            return self._tree_has_zzar(tree)
        except Exception:
            return False

    def _tree_has_zzar(self, tree):
        if isinstance(tree, list):
            for item in tree:
                if isinstance(item, str) and item.lower().endswith('.zzar'):
                    return True
                elif isinstance(item, (dict, list)):
                    if self._tree_has_zzar(item):
                        return True
        elif isinstance(tree, dict):
            for key, value in tree.items():
                if isinstance(key, str) and key.lower().endswith('.zzar'):
                    return True
                if self._tree_has_zzar(value):
                    return True
        return False

    def run(self):
        from concurrent.futures import ThreadPoolExecutor, as_completed

        with ThreadPoolExecutor(max_workers=self.CONCURRENT_REQUESTS) as pool:
            futures = {pool.submit(self._check_one, mid): mid for mid in self.mod_ids}
            for future in as_completed(futures):
                result = future.result()
                if result:
                    self.zzarSupportReady.emit(result[0], result[1])

class DownloadModWorker(QThread):
    

    progress = pyqtSignal(int)
    finished = pyqtSignal(bool, str)

    def __init__(self, download_url, save_path):
        super().__init__()
        self.download_url = download_url
        self.save_path = Path(save_path)

    def run(self):
        try:
            print(f"[GameBanana] Downloading: {self.download_url}")

            req = urllib.request.Request(self.download_url)
            req.add_header('User-Agent', 'ZZAR/1.1.0')

            with urllib.request.urlopen(req, timeout=30) as response:
                total_size = int(response.headers.get('Content-Length', 0))
                downloaded = 0

                self.save_path.parent.mkdir(parents=True, exist_ok=True)

                with open(self.save_path, 'wb') as f:
                    while True:
                        chunk = response.read(8192)
                        if not chunk:
                            break

                        f.write(chunk)
                        downloaded += len(chunk)

                        if total_size > 0:
                            progress = int((downloaded / total_size) * 100)
                            self.progress.emit(progress)

            print(f"[GameBanana] Download complete: {self.save_path}")
            self.finished.emit(True, str(self.save_path))

        except Exception as e:
            import traceback
            self.finished.emit(False, f"Download failed: {str(e)}\n{traceback.format_exc()}")

class GameBananaBridge(QObject):
    

    modsLoaded = pyqtSignal('QVariantList')
    modDetailsLoaded = pyqtSignal('QVariant')
    downloadProgress = pyqtSignal(int)
    downloadComplete = pyqtSignal(str)
    errorOccurred = pyqtSignal(str, str)
    loadingStateChanged = pyqtSignal(bool)
    thumbnailUpdated = pyqtSignal(int, str)
    downloadCountUpdated = pyqtSignal(int, int)
    zzarSupportUpdated = pyqtSignal(int, bool)

    def __init__(self):
        super().__init__()
        self.fetch_worker = None
        self.details_worker = None
        self.download_worker = None
        self.thumbnail_worker = None
        self.download_counts_worker = None
        self.zzar_support_worker = None
        self.current_page = 1
        self.current_sort = "default"
        self.cached_mods = []

    @pyqtSlot(int, str)
    def fetchMods(self, page=1, sort="default"):
        
        if self.fetch_worker and self.fetch_worker.isRunning():
            print("[GameBanana] Already fetching mods")
            return

        self.current_page = page
        self.current_sort = sort
        self.loadingStateChanged.emit(True)

        self.fetch_worker = FetchModsWorker(page, per_page=20, sort=sort)
        self.fetch_worker.finished.connect(self._on_mods_fetched)
        self.fetch_worker.start()

    def _on_mods_fetched(self, success, data):
        
        self.loadingStateChanged.emit(False)

        if success:
            self.cached_mods = data
            self.modsLoaded.emit(data)
            print(f"[GameBanana] Loaded {len(data)} mods")

            ids_needing_thumbs = [m['id'] for m in data if not m.get('thumbnail')]
            if ids_needing_thumbs:
                if self.thumbnail_worker and self.thumbnail_worker.isRunning():
                    self.thumbnail_worker.terminate()
                self.thumbnail_worker = FetchThumbnailsWorker(ids_needing_thumbs)
                self.thumbnail_worker.thumbnailReady.connect(self.thumbnailUpdated.emit)
                self.thumbnail_worker.start()

            all_ids = [m['id'] for m in data]
            if all_ids:
                if self.download_counts_worker and self.download_counts_worker.isRunning():
                    self.download_counts_worker.terminate()
                self.download_counts_worker = FetchDownloadCountsWorker(all_ids)
                self.download_counts_worker.downloadCountReady.connect(self.downloadCountUpdated.emit)
                self.download_counts_worker.start()

            if all_ids:
                if self.zzar_support_worker and self.zzar_support_worker.isRunning():
                    self.zzar_support_worker.terminate()
                self.zzar_support_worker = FetchZZARSupportWorker(all_ids)
                self.zzar_support_worker.zzarSupportReady.connect(self.zzarSupportUpdated.emit)
                self.zzar_support_worker.start()
        else:
            self.errorOccurred.emit("Failed to Load Mods", str(data))
            print(f"[GameBanana] Error: {data}")

    @pyqtSlot(int)
    def fetchModDetails(self, mod_id):
        
        if self.details_worker and self.details_worker.isRunning():
            print("[GameBanana] Already fetching details")
            return

        self.loadingStateChanged.emit(True)

        self.details_worker = FetchModDetailsWorker(mod_id)
        self.details_worker.finished.connect(self._on_details_fetched)
        self.details_worker.start()

    def _on_details_fetched(self, success, data):
        
        self.loadingStateChanged.emit(False)

        if success:
            self.modDetailsLoaded.emit(data)
            print(f"[GameBanana] Loaded details for mod: {data.get('name', 'Unknown')}")
        else:
            self.errorOccurred.emit("Failed to Load Mod Details", str(data))
            print(f"[GameBanana] Error: {data}")

    @pyqtSlot(str, str, str)
    def downloadMod(self, download_url, filename, mod_name):
        
        if self.download_worker and self.download_worker.isRunning():
            self.errorOccurred.emit("Download in Progress", "Please wait for the current download to complete")
            return

        from ZZAR import get_temp_dir
        temp_dir = get_temp_dir() / "gamebanana_downloads"
        save_path = temp_dir / filename

        self.download_worker = DownloadModWorker(download_url, save_path)
        self.download_worker.progress.connect(self.downloadProgress.emit)
        self.download_worker.finished.connect(self._on_download_finished)
        self.download_worker.start()

        print(f"[GameBanana] Starting download: {mod_name}")

    def _on_download_finished(self, success, result):
        
        if success:
            self.downloadComplete.emit(result)
            print(f"[GameBanana] Download complete: {result}")
        else:
            self.errorOccurred.emit("Download Failed", result)
            print(f"[GameBanana] Download error: {result}")

    @pyqtSlot()
    def refresh(self):
        
        self.fetchMods(self.current_page, self.current_sort)
