

import json
import uuid
import shutil
import zipfile
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from src.config_manager import get_mod_library_dir, get_mod_config_file


class InvalidModPackageError(Exception):

    pass

class ModApplicationError(Exception):

    pass

class ModPackageManager:


    def __init__(self, mod_library_path=None, persistent_mod_manager=None):

        self.mod_library_path = Path(mod_library_path) if mod_library_path else get_mod_library_dir()
        self.mods_dir = self.mod_library_path / 'mods'
        self.config_path = get_mod_config_file()
        self.persistent_mod_manager = persistent_mod_manager
        self.mod_config = {}

        self.mods_dir.mkdir(parents=True, exist_ok=True)

        self._migrate_old_config()

        self.load_config()

    def _migrate_old_config(self):

        old_config = Path.home() / '.zzar_mod_config.json'
        old_library = Path.home() / '.zzar_mod_library'

        if old_config.exists() and not self.config_path.exists():
            try:
                shutil.copy2(old_config, self.config_path)
                print(f"Migrated mod config: {old_config} -> {self.config_path}")
            except Exception as e:
                print(f"Warning: Failed to migrate mod config: {e}")

        if old_library.exists() and not self.mod_library_path.exists():
            try:
                shutil.copytree(old_library, self.mod_library_path)
                print(f"Migrated mod library: {old_library} -> {self.mod_library_path}")
            except Exception as e:
                print(f"Warning: Failed to migrate mod library: {e}")

    def load_config(self):

        try:
            if self.config_path.exists():
                with open(self.config_path, 'r') as f:
                    self.mod_config = json.load(f)
            else:
                self.mod_config = {
                    'installed_mods': {},
                    'load_order': []
                }
        except Exception as e:
            print(f"Warning: Failed to load mod config: {e}")
            self.mod_config = {
                'installed_mods': {},
                'load_order': []
            }

    def save_config(self):

        try:
            with open(self.config_path, 'w') as f:
                json.dump(self.mod_config, f, indent=2)
        except Exception as e:
            print(f"Warning: Failed to save mod config: {e}")

    def _normalize_metadata_replacements(self, metadata):
        """Convert v1.0 or v2.0 replacements to flat internal format:
        {pck_name: {file_id_str: {wem_file, sound_name, lang_id, bnk_id, file_type}}}
        v1.0: {pck: {file_id: {bnk_id, ...}}}   (already flat)
        v2.0: {pck: {"bnk_id.bnk" | "direct": {file_id: {...}}}}
        """
        format_version = metadata.get('format_version', '1.0')
        replacements = metadata.get('replacements', {})

        if format_version not in ('2.0', '3.0'):
            return replacements

        normalized = {}
        for pck_name, bnk_entries in replacements.items():
            normalized[pck_name] = {}
            for bnk_key, files in bnk_entries.items():
                if bnk_key == 'direct':
                    bnk_id = None
                else:
                    try:
                        bnk_id = int(bnk_key.replace('.bnk', ''))
                    except ValueError:
                        bnk_id = None
                for file_id, file_info in files.items():
                    # Use compound key for BNK entries so the same WEM ID in
                    # multiple BNKs doesn't overwrite itself in the flat dict.
                    internal_key = f"{bnk_id}|{file_id}" if bnk_id is not None else file_id
                    normalized[pck_name][internal_key] = {
                        'wem_file': file_info.get('wem_file', ''),
                        'sound_name': file_info.get('sound_name', ''),
                        'lang_id': file_info.get('lang_id', 0),
                        'bnk_id': bnk_id,
                        'file_type': file_info.get('file_type', 'wem'),
                        'file_id': file_id,
                    }
        return normalized

    def validate_mod_package(self, zzar_path):

        zzar_path = Path(zzar_path)

        if not zzar_path.exists():
            raise InvalidModPackageError(f"File not found: {zzar_path}")

        if not zipfile.is_zipfile(zzar_path):
            raise InvalidModPackageError(f"Not a valid ZIP file: {zzar_path}")

        try:
            with zipfile.ZipFile(zzar_path, 'r') as zf:

                if 'metadata.json' not in zf.namelist():
                    raise InvalidModPackageError("Missing metadata.json at root of archive")

                metadata_content = zf.read('metadata.json').decode('utf-8')
                metadata = json.loads(metadata_content)

                required_fields = ['name', 'author', 'version', 'replacements']
                for field in required_fields:
                    if field not in metadata:
                        raise InvalidModPackageError(f"Missing required field in metadata: {field}")

                if 'format_version' not in metadata:
                    metadata['format_version'] = '1.0'

                file_list = zf.namelist()
                format_version = metadata.get('format_version', '1.0')

                if format_version in ('2.0', '3.0'):
                    for pck_name, bnk_entries in metadata['replacements'].items():
                        for bnk_key, files in bnk_entries.items():
                            for file_id, file_info in files.items():
                                wem_file = file_info.get('wem_file', '')
                                if wem_file and wem_file not in file_list:
                                    raise InvalidModPackageError(
                                        f"Referenced WEM file not found in archive: {wem_file}"
                                    )
                else:
                    for pck_name, files in metadata['replacements'].items():
                        for file_id, file_info in files.items():
                            wem_file = file_info.get('wem_file', '')
                            if wem_file and wem_file not in file_list:
                                raise InvalidModPackageError(
                                    f"Referenced WEM file not found in archive: {wem_file}"
                                )

                return metadata

        except zipfile.BadZipFile:
            raise InvalidModPackageError("Corrupted ZIP file")
        except json.JSONDecodeError as e:
            raise InvalidModPackageError(f"Invalid JSON in metadata.json: {e}")

    def _compare_versions(self, version1, version2):

        try:

            v1_parts = [int(x) for x in str(version1).split('.')]
            v2_parts = [int(x) for x in str(version2).split('.')]

            max_len = max(len(v1_parts), len(v2_parts))
            v1_parts += [0] * (max_len - len(v1_parts))
            v2_parts += [0] * (max_len - len(v2_parts))

            for p1, p2 in zip(v1_parts, v2_parts):
                if p1 > p2:
                    return 1
                elif p1 < p2:
                    return -1

            return 0
        except (ValueError, AttributeError):

            return 0

    def install_mod(self, zzar_path):


        metadata = self.validate_mod_package(zzar_path)

        mod_name = metadata.get('name', '')
        new_version = metadata.get('version', '1.0.0')
        existing_uuid = None
        replaced = False

        for uuid_key, mod_info in self.mod_config.get('installed_mods', {}).items():
            existing_metadata = mod_info.get('metadata', {})
            if existing_metadata.get('name', '') == mod_name:
                existing_version = existing_metadata.get('version', '1.0.0')

                version_cmp = self._compare_versions(new_version, existing_version)

                if version_cmp > 0:

                    print(f"[Mod Manager] Found existing mod '{mod_name}' v{existing_version}, replacing with v{new_version}")
                    existing_uuid = uuid_key
                    replaced = True
                    break
                elif version_cmp == 0:

                    print(f"[Mod Manager] Found existing mod '{mod_name}' v{existing_version}, replacing with same version")
                    existing_uuid = uuid_key
                    replaced = True
                    break
                else:

                    print(f"[Mod Manager] Warning: Existing mod '{mod_name}' v{existing_version} is newer than v{new_version}, skipping installation")
                    return None

        if existing_uuid:
            self.remove_mod(existing_uuid)

        mod_uuid = str(uuid.uuid4())

        mod_dir = self.mods_dir / mod_uuid
        mod_dir.mkdir(parents=True, exist_ok=True)

        try:
            with zipfile.ZipFile(zzar_path, 'r') as zf:
                zf.extractall(mod_dir)
        except Exception as e:

            if mod_dir.exists():
                shutil.rmtree(mod_dir)
            raise InvalidModPackageError(f"Failed to extract mod package: {e}")

        self.mod_config['installed_mods'][mod_uuid] = {
            'enabled': False,
            'priority': len(self.mod_config['load_order']),
            'install_date': datetime.now().isoformat(),
            'metadata': metadata
        }

        self.mod_config['load_order'].append(mod_uuid)

        self.save_config()

        return {
            'uuid': mod_uuid,
            'replaced': replaced,
            'mod_name': mod_name,
            'version': new_version
        }

    def get_installed_mods(self):

        mods = []

        for idx, mod_uuid in enumerate(self.mod_config.get('load_order', [])):
            if mod_uuid not in self.mod_config['installed_mods']:
                continue

            mod_info = self.mod_config['installed_mods'][mod_uuid]
            mod_dir = self.mods_dir / mod_uuid

            if not mod_dir.exists():
                continue

            thumbnail_path = None
            if 'thumbnail' in mod_info['metadata']:
                thumb_file = mod_dir / mod_info['metadata']['thumbnail']
                if thumb_file.exists():
                    thumbnail_path = thumb_file

            mods.append({
                'uuid': mod_uuid,
                'enabled': mod_info.get('enabled', False),
                'priority': idx,
                'metadata': mod_info['metadata'],
                'install_date': mod_info.get('install_date', ''),
                'thumbnail_path': thumbnail_path
            })

        return mods

    def set_mod_enabled(self, mod_uuid, enabled):

        if mod_uuid in self.mod_config['installed_mods']:
            self.mod_config['installed_mods'][mod_uuid]['enabled'] = enabled
            self.save_config()

    def remove_mod(self, mod_uuid):


        if mod_uuid in self.mod_config['installed_mods']:
            del self.mod_config['installed_mods'][mod_uuid]

        if mod_uuid in self.mod_config['load_order']:
            self.mod_config['load_order'].remove(mod_uuid)

        mod_dir = self.mods_dir / mod_uuid
        if mod_dir.exists():
            shutil.rmtree(mod_dir)

        self.save_config()

    def update_load_order(self, ordered_uuids):


        for mod_uuid in ordered_uuids:
            if mod_uuid not in self.mod_config['installed_mods']:
                raise ValueError(f"Unknown mod UUID: {mod_uuid}")

        self.mod_config['load_order'] = ordered_uuids

        for idx, mod_uuid in enumerate(ordered_uuids):
            self.mod_config['installed_mods'][mod_uuid]['priority'] = idx

        self.save_config()

    def resolve_conflicts(self, preferences=None):

        preferences = preferences or {}
        resolved = {}
        conflicts_tracker = defaultdict(lambda: defaultdict(list))

        all_replacements = defaultdict(lambda: defaultdict(dict))

        orphaned = [uuid for uuid in list(self.mod_config.get('load_order', []))
                    if uuid in self.mod_config['installed_mods']
                    and not (self.mods_dir / uuid).exists()]
        for mod_uuid in orphaned:
            mod_name = self.mod_config['installed_mods'][mod_uuid].get('metadata', {}).get('name', mod_uuid)
            print(f"[Mod Manager] Mod directory missing for '{mod_name}' ({mod_uuid}), removing from config...")
            del self.mod_config['installed_mods'][mod_uuid]
            if mod_uuid in self.mod_config['load_order']:
                self.mod_config['load_order'].remove(mod_uuid)
        if orphaned:
            self.save_config()

        for mod_uuid in self.mod_config.get('load_order', []):
            if mod_uuid not in self.mod_config['installed_mods']:
                continue

            mod_info = self.mod_config['installed_mods'][mod_uuid]

            if not mod_info.get('enabled', False):
                continue

            metadata = mod_info['metadata']
            mod_name = metadata.get('name', 'Unknown')

            mod_dir = self.mods_dir / mod_uuid

            normalized_replacements = self._normalize_metadata_replacements(metadata)
            for pck_name, files in normalized_replacements.items():
                if pck_name not in resolved:
                    resolved[pck_name] = {}

                for file_id, file_info in files.items():

                    wem_file = file_info.get('wem_file', '')
                    wem_path = mod_dir / wem_file if wem_file else None

                    bnk_id = file_info.get('bnk_id')
                    actual_wem_id = file_info.get('file_id') or file_id
                    # Normalize conflict key to "bnk_id|wem_id" (or plain wem_id for direct)
                    # so v1.0 and v2.0 mods targeting the same sound share the same key
                    conflict_key = f"{bnk_id}|{actual_wem_id}" if bnk_id is not None else str(actual_wem_id)

                    replacement_info = {
                        'wem_path': str(wem_path) if wem_path else '',
                        'mod_uuid': mod_uuid,
                        'mod_name': mod_name,
                        'lang_id': file_info.get('lang_id', 0),
                        'bnk_id': bnk_id,
                        'file_type': file_info.get('file_type', 'wem'),
                        'sound_name': file_info.get('sound_name', ''),
                        'file_id': file_info.get('file_id'),
                        'conflicts_with': []
                    }

                    all_replacements[pck_name][conflict_key][mod_name] = replacement_info

                    if conflict_key in resolved[pck_name]:

                        prev_uuid = resolved[pck_name][conflict_key]['mod_uuid']
                        conflicts_tracker[pck_name][conflict_key].append(prev_uuid)

                    resolved[pck_name][conflict_key] = replacement_info

        for pref_key, preferred_mod in preferences.items():
            try:
                pck_name, file_id = pref_key.split(':', 1)
                if pck_name in all_replacements and file_id in all_replacements[pck_name]:
                    if preferred_mod in all_replacements[pck_name][file_id]:

                        resolved[pck_name][file_id] = all_replacements[pck_name][file_id][preferred_mod]
                        print(f"[Conflict Resolution] Applied preference: {pref_key} -> {preferred_mod}")
            except ValueError:
                print(f"[Conflict Resolution] Invalid preference key: {pref_key}")

        for pck_name, files in conflicts_tracker.items():
            for file_id, conflicting_uuids in files.items():
                if file_id in resolved.get(pck_name, {}):
                    resolved[pck_name][file_id]['conflicts_with'] = conflicting_uuids

        return resolved

    def get_conflicts_summary(self):

        resolved = self.resolve_conflicts()

        total_replacements = sum(len(files) for files in resolved.values())
        affected_pcks = list(resolved.keys())
        conflicts = []

        for pck_name, files in resolved.items():
            for file_id, file_info in files.items():
                if file_info.get('conflicts_with'):

                    loser_names = []
                    for loser_uuid in file_info['conflicts_with']:
                        if loser_uuid in self.mod_config['installed_mods']:
                            loser_name = self.mod_config['installed_mods'][loser_uuid]['metadata'].get('name', 'Unknown')
                            loser_names.append(loser_name)

                    conflicts.append({
                        'pck': pck_name,
                        'file_id': file_id,
                        'sound_name': file_info.get('sound_name', f'File {file_id}'),
                        'winner_mod': file_info['mod_name'],
                        'loser_mods': loser_names
                    })

        return {
            'total_replacements': total_replacements,
            'affected_pcks': affected_pcks,
            'conflicts': conflicts
        }

    def get_mod_conflicts_summary(self):

        summary = self.get_conflicts_summary()
        if not summary['conflicts']:
            return summary

        mod_pairs = {}
        for conflict in summary['conflicts']:
            winner = conflict['winner_mod']
            for loser in conflict['loser_mods']:
                pair_key = tuple(sorted([winner, loser]))
                if pair_key not in mod_pairs:
                    mod_pairs[pair_key] = {
                        'mods': list(pair_key),
                        'winner_mod': winner,
                        'conflict_count': 0,
                        'files': []
                    }
                mod_pairs[pair_key]['conflict_count'] += 1
                mod_pairs[pair_key]['files'].append({
                    'pck': conflict['pck'],
                    'file_id': conflict['file_id'],
                })

        mod_conflicts = list(mod_pairs.values())

        return {
            'total_replacements': summary['total_replacements'],
            'affected_pcks': summary['affected_pcks'],
            'conflicts': summary['conflicts'],
            'mod_conflicts': mod_conflicts,
        }

    def apply_mods(self, game_audio_dir, persistent_audio_dir, progress_callback=None, conflict_preferences=None):

        import tempfile

        try:

            try:
                from src.pck_packer import PCKPacker
                from src.bnk_mod_helper import prepare_bnk_structure
            except ImportError:
                from pck_packer import PCKPacker
                from bnk_mod_helper import prepare_bnk_structure
        except ImportError as e:
            raise ModApplicationError(f"Failed to import required modules: {e}")

        game_audio_dir = Path(game_audio_dir)
        persistent_audio_dir = Path(persistent_audio_dir)

        if not game_audio_dir.exists():
            raise ModApplicationError(f"Game audio directory not found: {game_audio_dir}")

        persistent_audio_dir.mkdir(parents=True, exist_ok=True)

        if progress_callback:
            progress_callback("Resolving mod conflicts...", 0, 1)

        resolved = self.resolve_conflicts(preferences=conflict_preferences)

        if self.persistent_mod_manager:
            old_replacements = self.persistent_mod_manager.get_all_replacements()
            self.persistent_mod_manager.clear_all_replacements()
        else:
            old_replacements = {}

        if not resolved:
            if progress_callback:
                progress_callback("No mods enabled - cleaning up...", 0, 1)

            deleted_count = 0
            for pck_name in old_replacements.keys():
                pck_path = persistent_audio_dir / pck_name
                if pck_path.exists():
                    try:

                        pck_path.chmod(0o644)
                        pck_path.unlink()
                        deleted_count += 1
                        print(f"Deleted {pck_name} from Persistent folder")
                    except Exception as e:
                        print(f"Warning: Failed to delete {pck_name}: {e}")

            if progress_callback:
                progress_callback(f"Cleaned up {deleted_count} PCK file(s)", 1, 1)

            return

        pcks_to_remove = set(old_replacements.keys()) - set(resolved.keys())
        if pcks_to_remove:
            if progress_callback:
                progress_callback(f"Removing {len(pcks_to_remove)} PCK file(s) from disabled mods...", 0, 1)

            for pck_name in pcks_to_remove:
                pck_path = persistent_audio_dir / pck_name
                if pck_path.exists():
                    try:

                        pck_path.chmod(0o644)
                        pck_path.unlink()
                        print(f"Deleted {pck_name} from Persistent folder (mod disabled)")
                    except Exception as e:
                        print(f"Warning: Failed to delete {pck_name}: {e}")

        pck_list = list(resolved.keys())
        total_pcks = len(pck_list)

        for idx, pck_name in enumerate(pck_list):
            if progress_callback:
                progress_callback(f"Processing {pck_name}...", idx, total_pcks)

            original_pck = None

            if (game_audio_dir / pck_name).exists():
                original_pck = game_audio_dir / pck_name
                output_pck = persistent_audio_dir / pck_name
                output_pck.parent.mkdir(parents=True, exist_ok=True)
            else:

                candidates = []
                for subdir in sorted(game_audio_dir.iterdir()):
                    if subdir.is_dir():
                        candidate = subdir / pck_name
                        if candidate.exists():
                            candidates.append((subdir, candidate))

                if candidates:
                    target_int_ids = set()
                    for key, file_info in resolved[pck_name].items():
                        raw = file_info.get('file_id') or (str(key).split('|')[-1] if '|' in str(key) else key)
                        try:
                            target_int_ids.add(int(raw))
                        except (ValueError, TypeError):
                            pass

                    chosen_subdir, chosen_candidate = candidates[0]
                    if target_int_ids and len(candidates) > 1:
                        from src.pck_indexer import PCKIndexer
                        for subdir, candidate in candidates:
                            try:
                                idx = PCKIndexer(str(candidate))
                                data = idx.build_index()
                                pck_ids = {e['id'] for e in data['banks'] + data['sounds'] + data['externals']}
                                if target_int_ids & pck_ids:
                                    chosen_subdir, chosen_candidate = subdir, candidate
                                    break
                            except Exception:
                                pass

                    original_pck = chosen_candidate
                    persistent_subdir = persistent_audio_dir / chosen_subdir.name
                    persistent_subdir.mkdir(parents=True, exist_ok=True)
                    output_pck = persistent_subdir / pck_name

            if not original_pck or not original_pck.exists():
                print(f"Warning: Original PCK not found: {pck_name}, skipping...")
                continue

            if output_pck.exists():
                try:
                    output_pck.chmod(0o644)
                except Exception as e:
                    print(f"Warning: Failed to remove read-only from {output_pck}: {e}")

            from ZZAR import get_temp_dir
            temp_dir = Path(tempfile.mkdtemp(prefix='zzar_apply_', dir=str(get_temp_dir())))

            try:

                packer = PCKPacker(str(original_pck), str(output_pck))
                packer.load_original_pck()

                direct_wems = {}   # {wem_id: (wem_path, lang_id)}
                bnk_wems = defaultdict(dict)
                bnk_lang_ids = {}  # {bnk_id: lang_id} for fallback

                for key, file_info in resolved[pck_name].items():
                    wem_path = file_info['wem_path']

                    if not Path(wem_path).exists():
                        print(f"Warning: WEM file not found: {wem_path}, skipping...")
                        continue

                    # key is always compound "bnk_id|wem_id" now; file_info['file_id'] has plain wem_id for v2.0
                    raw_id = file_info.get('file_id') or (str(key).split('|')[-1] if '|' in str(key) else key)
                    actual_wem_id = int(raw_id)
                    lang_id = file_info.get('lang_id', 0)

                    if file_info.get('bnk_id'):
                        bnk_id = file_info['bnk_id']
                        bnk_wems[bnk_id][actual_wem_id] = wem_path
                        bnk_lang_ids[bnk_id] = lang_id
                    else:
                        direct_wems[actual_wem_id] = (wem_path, lang_id)

                for wem_id, (wem_path, lang_id) in direct_wems.items():
                    packer.replace_file(wem_id, wem_path, lang_id=lang_id)

                for bnk_id, wem_map in bnk_wems.items():

                    bnk_dir = temp_dir / str(bnk_id)
                    bnk_dir.mkdir(parents=True, exist_ok=True)

                    for wem_id, wem_path in wem_map.items():
                        dest_path = bnk_dir / f"{wem_id}.wem"
                        shutil.copy2(wem_path, dest_path)

                    # Auto-detect the correct lang_id for this BNK in the target PCK
                    lang_id = None
                    for search_lang_id, bnks in packer.soundbank_titles.items():
                        if bnk_id in bnks:
                            lang_id = search_lang_id
                            break

                    if lang_id is None:
                        # Fallback to stored lang_id if BNK not found
                        lang_id = bnk_lang_ids.get(bnk_id, 0)
                        print(f"Warning: BNK {bnk_id} not found in PCK, using stored lang_id={lang_id}")

                    packer.replace_bnk_wems(bnk_id, str(bnk_dir), lang_id=lang_id)

                packer.pack(use_patching=False)

                output_pck.chmod(0o444)

            except Exception as e:
                raise ModApplicationError(f"Failed to process {pck_name}: {e}")
            finally:

                if temp_dir.exists():
                    shutil.rmtree(temp_dir)

        if self.persistent_mod_manager:

            persistent_format = {}
            for pck_name, files in resolved.items():
                persistent_format[pck_name] = {}
                for key, file_info in files.items():
                    actual_wem_id = file_info.get('file_id', key)
                    persistent_format[pck_name][actual_wem_id] = {
                        'wem_path': file_info['wem_path'],
                        'file_type': file_info.get('file_type', 'wem'),
                        'lang_id': file_info.get('lang_id', 0),
                        'bnk_id': file_info.get('bnk_id'),
                        'date_modified': datetime.now().isoformat(),
                        'source': 'mod_manager'
                    }

            self.persistent_mod_manager.import_replacements_from_mods(persistent_format)

        if progress_callback:
            progress_callback(f"Applied {total_pcks} PCK(s) successfully", total_pcks, total_pcks)

    def create_mod_package(self, output_path, metadata, current_replacements, thumbnail_path=None):

        import tempfile
        from PIL import Image

        output_path = Path(output_path)

        from ZZAR import get_temp_dir, __version__ as zzar_version
        temp_dir = Path(tempfile.mkdtemp(prefix='zzar_mod_', dir=str(get_temp_dir())))

        try:
            wem_dir = temp_dir / 'wem_files'
            wem_dir.mkdir(parents=True, exist_ok=True)

            replacements_data = {}

            for pck_name, files in current_replacements.items():
                replacements_data[pck_name] = {}

                for tracker_key, file_info in files.items():
                    wem_path = Path(file_info['wem_path'])

                    if not wem_path.exists():
                        print(f"Warning: WEM file not found: {wem_path}, skipping...")
                        continue

                    # tracker_key may be "bnk_id|wem_id" or plain "wem_id"
                    actual_file_id = str(tracker_key).split('|')[1] if '|' in str(tracker_key) else str(tracker_key)

                    bnk_id = file_info.get('bnk_id')
                    if bnk_id:
                        bnk_key = f"{bnk_id}.bnk"
                        sub_dir = wem_dir / str(bnk_id)
                        wem_relative = f'wem_files/{bnk_id}/{actual_file_id}.wem'
                    else:
                        bnk_key = 'direct'
                        sub_dir = wem_dir / 'direct'
                        wem_relative = f'wem_files/direct/{actual_file_id}.wem'

                    sub_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(wem_path, sub_dir / f"{actual_file_id}.wem")

                    if bnk_key not in replacements_data[pck_name]:
                        replacements_data[pck_name][bnk_key] = {}

                    replacements_data[pck_name][bnk_key][actual_file_id] = {
                        'wem_file': wem_relative,
                        'sound_name': file_info.get('sound_name', ''),
                        'lang_id': file_info.get('lang_id', 0),
                        'file_type': file_info.get('file_type', 'wem')
                    }

            thumbnail_filename = None
            if thumbnail_path and Path(thumbnail_path).exists():
                try:

                    img = Image.open(thumbnail_path)
                    thumbnail_filename = 'thumbnail.png'
                    img.save(temp_dir / thumbnail_filename, 'PNG')
                except Exception as e:
                    print(f"Warning: Failed to process thumbnail: {e}")

            metadata_content = {
                'format_version': '3.0',
                'name': metadata['name'],
                'author': metadata['author'],
                'version': metadata.get('version', '1.0.0'),
                'description': metadata.get('description', ''),
                'created_date': datetime.now().isoformat(),
                'replacements': replacements_data,
                'zzar_version': zzar_version
            }

            if thumbnail_filename:
                metadata_content['thumbnail'] = thumbnail_filename

            with open(temp_dir / 'metadata.json', 'w') as f:
                json.dump(metadata_content, f, indent=2)

            with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                for file_path in temp_dir.rglob('*'):
                    if file_path.is_file():
                        arcname = file_path.relative_to(temp_dir)
                        zf.write(file_path, arcname)

            return output_path

        finally:

            if temp_dir.exists():
                shutil.rmtree(temp_dir)
