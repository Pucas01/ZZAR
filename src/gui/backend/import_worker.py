

import tempfile
import shutil
import zipfile
import json
from pathlib import Path
from datetime import datetime
from PyQt5.QtCore import QObject, QThread, pyqtSignal
from src.app_config import SOUNDBANK_PCK_PREFIX, STREAMED_PCK_PREFIX, MOD_FILE_EXT, MOD_FILE_EXT_UPPER

class ImportWorker(QThread):


    progress = pyqtSignal(str)
    progressPercent = pyqtSignal(int)
    finished = pyqtSignal(bool, str)

    def __init__(self, data, game_audio_dir, mod_package_manager):
        super().__init__()
        self.data = data
        self.game_audio_dir = game_audio_dir
        self.mod_package_manager = mod_package_manager

    def run(self):

        try:
            result = self._convert_mod()
            self.finished.emit(True, result)
        except Exception as e:
            self.finished.emit(False, str(e))

    def _convert_mod(self):

        from src.pck_extractor import PCKExtractor
        from src.pck_indexer import PCKIndexer
        from src.bnk_indexer import BNKIndexer
        from PIL import Image

        temp_dir = None

        try:

            from ZZAR import get_temp_dir
            temp_dir = Path(tempfile.mkdtemp(prefix='zzar_import_', dir=str(get_temp_dir())))

            wem_dir = temp_dir / 'wem_files'
            wem_dir.mkdir(parents=True, exist_ok=True)

            replacements = {}
            import_mode = self.data['import_mode']
            files = self.data['files']

            if import_mode in ['pck_file', 'pck_folder']:
                self.progress.emit("Extracting audio from PCK files...")
                self.progressPercent.emit(5)

                extracted_wem_ids = {}
                total_pcks_to_extract = len(files)
                for pck_idx, (pck_name, pck_info) in enumerate(files.items()):
                    pck_path = pck_info['path']

                    extractor = PCKExtractor(str(pck_path))
                    extract_result = extractor.extract_all(str(temp_dir / 'extracted'), extract_bnk=True)

                    extracted_path = temp_dir / 'extracted'

                    wem_files = list(extracted_path.rglob('*.wem'))

                    bnk_files = list(extracted_path.rglob('*.bnk'))
                    for bnk_file in bnk_files:
                        try:
                            bnk_bytes = bnk_file.read_bytes()
                            bnk_indexer = BNKIndexer(bnk_bytes)
                            bnk_indexer.parse_didx()

                            for wem in bnk_indexer.wem_list:
                                wem_id = str(wem['wem_id'])
                                wem_data = bnk_indexer.extract_wem(wem['wem_id'])
                                if wem_data:
                                    embedded_wem = extracted_path / 'bnk_embedded' / f"{wem_id}.wem"
                                    embedded_wem.parent.mkdir(parents=True, exist_ok=True)
                                    embedded_wem.write_bytes(wem_data)
                                    wem_files.append(embedded_wem)
                        except Exception as e:
                            self.progress.emit(f"Warning: Could not parse BNK {bnk_file.name}: {e}")

                    self.progress.emit(f"Found {len(wem_files)} audio files in {pck_name}")
                    pck_progress = int(5 + ((pck_idx + 1) / max(total_pcks_to_extract, 1)) * 25)
                    self.progressPercent.emit(pck_progress)

                    for wem_file in wem_files:
                        file_id = wem_file.stem
                        dest_wem = wem_dir / f"{file_id}.wem"
                        shutil.copy2(wem_file, dest_wem)
                        extracted_wem_ids[file_id] = dest_wem

                extracted_path = temp_dir / 'extracted'
                if extracted_path.exists():
                    shutil.rmtree(extracted_path)

                game_audio_dir = Path(self.game_audio_dir)
                if not game_audio_dir.exists():
                    raise Exception("Game audio directory not set. Please set it in Settings first.")

                input_pck_names = set(f"{name}.pck" if not name.endswith('.pck') else name for name in files.keys())
                self.progress.emit(f"Scanning matching game PCKs ({', '.join(input_pck_names)}) to locate {len(extracted_wem_ids)} extracted WEM file(s)...")
                self.progressPercent.emit(30)

                target_wem_ids = set(extracted_wem_ids.keys())
                file_id_to_pck = {}

                all_game_pcks = list(game_audio_dir.rglob('*.pck'))
                game_pck_files = [p for p in all_game_pcks if p.name in input_pck_names]
                total_game_pcks = len(game_pck_files)

                if total_game_pcks == 0:
                    self.progress.emit(f"Warning: No matching game PCKs found for {input_pck_names}. Searched {len(all_game_pcks)} game PCKs.")

                from ZZAR import get_temp_dir
                temp_bnk_dir = Path(tempfile.mkdtemp(prefix='zzar_bnk_scan_', dir=str(get_temp_dir())))

                for idx, game_pck_path in enumerate(game_pck_files):
                    scan_progress = int(30 + ((idx + 1) / max(total_game_pcks, 1)) * 25)
                    self.progressPercent.emit(scan_progress)

                    if idx % 5 == 0:
                        self.progress.emit(f"Scanning {game_pck_path.name} ({idx+1}/{total_game_pcks})...")

                    try:
                        indexer = PCKIndexer(str(game_pck_path))
                        indexer.build_index()

                        try:
                            game_pck_name = str(game_pck_path.relative_to(game_audio_dir)).replace("\\", "/")
                        except ValueError:
                            game_pck_name = game_pck_path.name
                        if game_pck_path.name.startswith(SOUNDBANK_PCK_PREFIX):
                            priority = 1
                        elif game_pck_path.name.startswith(STREAMED_PCK_PREFIX):
                            priority = 0
                        else:
                            priority = 0

                        for bnk_info in indexer.index_data['banks']:
                            bnk_id = bnk_info['id']
                            try:
                                bnk_bytes = indexer.extract_single_file(bnk_id, 'bnk', bnk_info['lang_id'])
                                bnk_indexer = BNKIndexer(bnk_bytes)
                                bnk_indexer.parse_didx()

                                for wem in bnk_indexer.wem_list:
                                    file_id = str(wem['wem_id'])
                                    if file_id in target_wem_ids:
                                        original_wem = bnk_indexer.extract_wem(wem['wem_id'])
                                        modded_wem = extracted_wem_ids[file_id].read_bytes()
                                        if original_wem == modded_wem:
                                            continue
                                        lang_id = bnk_info['lang_id']
                                        if file_id not in file_id_to_pck or priority >= file_id_to_pck[file_id][3]:
                                            file_id_to_pck[file_id] = (game_pck_name, bnk_id, lang_id, priority)
                            except:
                                pass

                        for wem_info in indexer.index_data['sounds'] + indexer.index_data['externals']:
                            file_id = str(wem_info['id'])
                            lang_id = wem_info['lang_id']
                            if file_id in target_wem_ids:
                                try:
                                    original_wem = indexer.extract_single_file(wem_info['id'], 'wem', lang_id)
                                    modded_wem = extracted_wem_ids[file_id].read_bytes()
                                    if original_wem == modded_wem:
                                        continue
                                except:
                                    pass
                                if file_id not in file_id_to_pck or priority >= file_id_to_pck[file_id][3]:
                                    file_id_to_pck[file_id] = (game_pck_name, None, lang_id, priority)

                    except Exception as e:
                        self.progress.emit(f"Warning: Could not scan {game_pck_path.name}: {e}")

                if temp_bnk_dir.exists():
                    shutil.rmtree(temp_bnk_dir)

                identical_count = len(extracted_wem_ids) - len(file_id_to_pck)
                self.progress.emit(f"Found {len(file_id_to_pck)} modified WEM file(s) ({identical_count} identical, skipped)")
                self.progressPercent.emit(58)

                for file_id in list(extracted_wem_ids.keys()):
                    if file_id not in file_id_to_pck:
                        wem_path = wem_dir / f"{file_id}.wem"
                        wem_path.unlink(missing_ok=True)

                for file_id in file_id_to_pck:
                    game_pck_name, bnk_id, lang_id, priority = file_id_to_pck[file_id]

                    if bnk_id:
                        sub_dir = wem_dir / str(bnk_id)
                        wem_relative = f'wem_files/{bnk_id}/{file_id}.wem'
                        bnk_key = f"{bnk_id}.bnk"
                    else:
                        sub_dir = wem_dir / 'direct'
                        wem_relative = f'wem_files/direct/{file_id}.wem'
                        bnk_key = 'direct'

                    sub_dir.mkdir(parents=True, exist_ok=True)
                    src = wem_dir / f"{file_id}.wem"
                    if src.exists():
                        shutil.move(str(src), str(sub_dir / f"{file_id}.wem"))

                    if game_pck_name not in replacements:
                        replacements[game_pck_name] = {}
                    if bnk_key not in replacements[game_pck_name]:
                        replacements[game_pck_name][bnk_key] = {}

                    replacements[game_pck_name][bnk_key][file_id] = {
                        'wem_file': wem_relative,
                        'sound_name': '',
                        'lang_id': lang_id,
                        'file_type': 'bnk' if bnk_id else 'wem'
                    }

                for pck_name, pck_files_map in replacements.items():
                    self.progress.emit(f"  {pck_name}: {len(pck_files_map)} file(s)")

            elif import_mode in ['wem_file', 'wem_folder']:

                self.progress.emit("Processing WEM files...")
                self.progressPercent.emit(5)

                game_audio_dir = Path(self.game_audio_dir)

                if not game_audio_dir.exists():
                    raise Exception("Game audio directory not set. Please set it in Settings first.")

                target_wem_ids = set(files.keys())
                # Build int→key mapping to match both decimal and hex string IDs
                target_id_to_key = {}
                for fid in files.keys():
                    try:
                        int_id = int(fid) if str(fid).isdigit() else int(str(fid), 16)
                        target_id_to_key[int_id] = fid
                    except (ValueError, TypeError):
                        pass
                self.progress.emit(f"Looking for {len(target_wem_ids)} WEM file(s) in game PCKs...")

                file_id_to_pck = {}

                pck_files = list(game_audio_dir.rglob('*.pck'))
                total_pcks = len(pck_files)

                from ZZAR import get_temp_dir
                temp_bnk_dir = Path(tempfile.mkdtemp(prefix='zzar_bnk_scan_', dir=str(get_temp_dir())))

                for idx, pck_path in enumerate(pck_files):
                    scan_progress = int(5 + ((idx + 1) / max(total_pcks, 1)) * 50)
                    self.progressPercent.emit(scan_progress)

                    if idx % 5 == 0:
                        self.progress.emit(f"Scanning {pck_path.name} ({idx+1}/{total_pcks})...")

                    try:

                        indexer = PCKIndexer(str(pck_path))
                        indexer.build_index()

                        try:
                            pck_name = str(pck_path.relative_to(game_audio_dir)).replace("\\", "/")
                        except ValueError:
                            pck_name = pck_path.name
                        if pck_path.name.startswith(SOUNDBANK_PCK_PREFIX):
                            priority = 1
                        elif pck_path.name.startswith(STREAMED_PCK_PREFIX):
                            priority = 0
                        else:
                            priority = 0

                        bnk_wems = 0
                        for bnk_info in indexer.index_data['banks']:
                            bnk_id = bnk_info['id']

                            try:
                                bnk_bytes = indexer.extract_single_file(bnk_id, 'bnk', bnk_info['lang_id'])
                                bnk_indexer = BNKIndexer(bnk_bytes)
                                bnk_indexer.parse_didx()

                                for wem in bnk_indexer.wem_list:
                                    wem_id = wem['wem_id']
                                    file_id = target_id_to_key.get(wem_id)

                                    if file_id is not None:
                                        lang_id = bnk_info['lang_id']

                                        if file_id not in file_id_to_pck or priority >= file_id_to_pck[file_id][3]:
                                            file_id_to_pck[file_id] = (pck_name, bnk_id, lang_id, priority)
                                        bnk_wems += 1
                            except:
                                pass

                        standalone_wems = 0
                        for wem_info in indexer.index_data['sounds'] + indexer.index_data['externals']:
                            wem_id = wem_info['id']
                            file_id = target_id_to_key.get(wem_id)
                            lang_id = wem_info['lang_id']

                            if file_id is not None:

                                if file_id not in file_id_to_pck or priority >= file_id_to_pck[file_id][3]:
                                    file_id_to_pck[file_id] = (pck_name, None, lang_id, priority)
                                standalone_wems += 1

                        if standalone_wems > 0 or bnk_wems > 0:
                            priority_label = "SoundBank" if priority == 1 else "Streamed"
                            self.progress.emit(f"  {pck_name} ({priority_label}): {standalone_wems} standalone + {bnk_wems} BNK-embedded")

                    except Exception as e:
                        self.progress.emit(f"Warning: Could not scan {pck_path.name}: {e}")

                if temp_bnk_dir.exists():
                    shutil.rmtree(temp_bnk_dir)

                self.progress.emit(f"Found {len(file_id_to_pck)} file IDs in {total_pcks} PCK files")
                self.progressPercent.emit(60)

                for file_id, wem_info in files.items():
                    wem_path = wem_info['path']

                    if file_id in file_id_to_pck:
                        pck_name, bnk_id, lang_id, priority = file_id_to_pck[file_id]
                        priority_str = " (SoundBank)" if priority == 1 else " (Streamed)"
                        location_str = f" in BNK {bnk_id}" if bnk_id else ""
                        self.progress.emit(f"File {file_id} -> {pck_name}{priority_str}{location_str} (lang {lang_id})")
                    else:
                        pck_name = "Unknown.pck"
                        bnk_id = None
                        lang_id = 0
                        self.progress.emit(f"Warning: File ID {file_id} not found in any game PCK")

                    if bnk_id:
                        sub_dir = wem_dir / str(bnk_id)
                        wem_relative = f'wem_files/{bnk_id}/{file_id}.wem'
                        bnk_key = f"{bnk_id}.bnk"
                    else:
                        sub_dir = wem_dir / 'direct'
                        wem_relative = f'wem_files/direct/{file_id}.wem'
                        bnk_key = 'direct'

                    sub_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(wem_path, sub_dir / f"{file_id}.wem")

                    if pck_name not in replacements:
                        replacements[pck_name] = {}
                    if bnk_key not in replacements[pck_name]:
                        replacements[pck_name][bnk_key] = {}

                    replacements[pck_name][bnk_key][file_id] = {
                        'wem_file': wem_relative,
                        'sound_name': '',
                        'lang_id': lang_id,
                        'file_type': 'bnk' if bnk_id else 'wem'
                    }

                self.progress.emit(f"Processed {len(files)} WEM files into {len(replacements)} PCK(s)")

                for pck_name, pck_files in replacements.items():
                    self.progress.emit(f"  {pck_name}: {len(pck_files)} file(s)")

            self.progress.emit(f"Creating {MOD_FILE_EXT} package...")
            self.progressPercent.emit(70)

            from ZZAR import __version__ as zzar_version
            metadata_content = {
                'format_version': '3.0',
                'name': self.data['metadata']['name'],
                'author': self.data['metadata']['author'],
                'version': self.data['metadata'].get('version', '1.0.0'),
                'description': self.data['metadata'].get('description', ''),
                'created_date': datetime.now().isoformat(),
                'replacements': replacements,
                'zzar_version': zzar_version
            }

            if self.data.get('thumbnail'):
                try:
                    img = Image.open(self.data['thumbnail'])
                    thumbnail_path = temp_dir / 'thumbnail.png'
                    img.save(thumbnail_path, 'PNG')
                    metadata_content['thumbnail'] = 'thumbnail.png'
                except Exception as e:
                    self.progress.emit(f"Warning: Could not process thumbnail: {e}")

            with open(temp_dir / 'metadata.json', 'w') as f:
                json.dump(metadata_content, f, indent=2)

            save_path = Path(self.data['save_path'])
            with zipfile.ZipFile(save_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                for file_path in temp_dir.rglob('*'):
                    if file_path.is_file():
                        arcname = file_path.relative_to(temp_dir)
                        zf.write(file_path, arcname)

            shutil.rmtree(temp_dir)
            temp_dir = None

            self.progress.emit(f"Created {MOD_FILE_EXT} package: {save_path.name}")
            self.progressPercent.emit(85)

            self.progress.emit("Installing mod...")
            install_result = self.mod_package_manager.install_mod(str(save_path))

            if install_result is None:
                return "Installation skipped: A newer version is already installed"

            mod_uuid = install_result['uuid']
            mod_name = install_result['mod_name']
            version = install_result['version']
            replaced = install_result['replaced']

            self.progressPercent.emit(100)

            if replaced:
                return f"Mod updated successfully!\n{mod_name} v{version}\nUUID: {mod_uuid}"
            else:
                return f"Mod imported and installed successfully!\n{mod_name} v{version}\nUUID: {mod_uuid}"

        except Exception as e:

            if temp_dir and temp_dir.exists():
                shutil.rmtree(temp_dir)
            raise Exception(f"Failed to convert mod: {e}")
