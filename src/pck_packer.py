

import struct
import os
from pathlib import Path
from io import BytesIO
from src.bnk_handler import BNKFile

class PCKPacker:


    MAGIC = b'AKPK'

    def __init__(self, original_pck_path, output_pck_path):

        self.original_pck_path = Path(original_pck_path)
        self.output_pck_path = Path(output_pck_path)

        self.soundbank_titles = {}
        self.soundbank_files = {}
        self.stream_files = {}

        self.language_def = {
            'SFX': 0,
            'ENGLISH': 1,
            'CHINESE': 2,
            'JAPANESE': 3,
            'KOREAN': 4
        }

        self.language_names = {}

        self.file_list = []

    def create_minimal_pck(self):


        self.soundbank_titles = {}
        self.soundbank_files = {}
        self.stream_files = {}

        self.file_list = [open(self.original_pck_path, 'rb')]

        print(f"Creating minimal PCK (replacements only): {self.output_pck_path.name}")

    def load_original_pck(self):

        from src.pck_extractor import PCKExtractor

        extractor = PCKExtractor(self.original_pck_path)

        with open(self.original_pck_path, 'rb') as f:
            extractor.file_handle = f

            extractor.validate_header()
            header_size = extractor._read_uint32()
            version = extractor._read_uint32()
            sec1_size = extractor._read_uint32()
            sec2_size = extractor._read_uint32()
            sec3_size = extractor._read_uint32()

            sec_sum = sec1_size + sec2_size + sec3_size + 0x10
            if sec_sum < header_size:
                sec4_size = extractor._read_uint32()
            else:
                sec4_size = 0

            print(f"Loading original PCK: {self.original_pck_path.name}")
            print(f"  Sections: Banks={sec2_size}, Sounds={sec3_size}, Externals={sec4_size}")

            strings_offset = f.tell()
            if sec1_size > 0:
                lang_count = extractor._read_uint32()
                lang_defs = []
                for i in range(lang_count):
                    lang_offset = extractor._read_uint32()
                    lang_id = extractor._read_uint32()
                    lang_defs.append((lang_id, strings_offset + lang_offset))

                for lang_id, lang_offset in lang_defs:
                    current_pos = f.tell()
                    f.seek(lang_offset)

                    lang_name = ""
                    while True:
                        char_bytes = f.read(2)
                        if char_bytes == b'\x00\x00' or len(char_bytes) < 2:
                            break
                        try:
                            lang_name += char_bytes.decode('utf-16-le')
                        except:
                            break

                    if lang_name:
                        lang_name_upper = lang_name.upper()

                        lang_name_base = lang_name_upper.split('(')[0]

                        if lang_name_base in self.language_def:
                            lang_id_for_name = self.language_def[lang_name_base]
                        elif lang_name_upper not in self.language_def:
                            self.language_def[lang_name_upper] = len(self.language_def)
                            lang_id_for_name = self.language_def[lang_name_upper]
                        else:
                            lang_id_for_name = self.language_def[lang_name_upper]

                        self.language_names[lang_id] = lang_name

                    f.seek(current_pos)

            f.seek(strings_offset + sec1_size)

            self._load_section(f, sec2_size, self.soundbank_titles, use_8byte_id=False)
            self._load_section(f, sec3_size, self.soundbank_files, use_8byte_id=False)
            self._load_section(f, sec4_size, self.stream_files, use_8byte_id=True)

        file_index = len(self.file_list)
        self.file_list.append(open(self.original_pck_path, 'rb'))

        print(f"  Loaded: {self._get_all_files(self.soundbank_titles)} banks, "
              f"{self._get_all_files(self.soundbank_files)} bank files, "
              f"{self._get_all_files(self.stream_files)} stream files")

    def _get_all_files(self, section_map):

        total = 0
        for lang_id in section_map:
            if isinstance(section_map[lang_id], dict):
                total += len(section_map[lang_id])
        return total

    def _load_section(self, f, section_size, target_map, use_8byte_id=False):

        if section_size == 0:
            return

        file_count = struct.unpack('<I', f.read(4))[0]
        if file_count == 0:
            return

        file_index = 0

        for i in range(file_count):
            if use_8byte_id:
                file_id = struct.unpack('<Q', f.read(8))[0]
            else:
                file_id = struct.unpack('<I', f.read(4))[0]

            blocksize = struct.unpack('<I', f.read(4))[0]
            size = struct.unpack('<I', f.read(4))[0]
            offset_block = struct.unpack('<I', f.read(4))[0]
            lang_id = struct.unpack('<I', f.read(4))[0]

            if blocksize != 0:
                offset = offset_block * blocksize
            else:
                offset = offset_block

            if lang_id not in target_map:
                target_map[lang_id] = {}

            target_map[lang_id][file_id] = [(file_index, size, offset)]

    def replace_file(self, file_id, replacement_file_path, lang_id=0, target_section='soundbank_files'):

        replacement_file_path = Path(replacement_file_path)

        if not replacement_file_path.exists():
            raise FileNotFoundError(f"Replacement file not found: {replacement_file_path}")

        file_index = len(self.file_list)
        file_obj = open(replacement_file_path, 'rb')
        self.file_list.append(file_obj)

        file_obj.seek(0, 2)
        file_size = file_obj.tell()
        file_obj.seek(0)

        found_section = None
        for section_name, section_map in [
            ('soundbank_titles', self.soundbank_titles),
            ('soundbank_files', self.soundbank_files),
            ('stream_files', self.stream_files)
        ]:
            if lang_id in section_map and file_id in section_map[lang_id]:
                found_section = section_map
                break

        if found_section is None:
            section_map_dict = {
                'soundbank_titles': self.soundbank_titles,
                'soundbank_files': self.soundbank_files,
                'stream_files': self.stream_files
            }
            found_section = section_map_dict[target_section]
            if lang_id not in found_section:
                found_section[lang_id] = {}

        if lang_id not in found_section:
            found_section[lang_id] = {}
        found_section[lang_id][file_id] = [(file_index, file_size, 0)]

        print(f"  Replaced ID {file_id} with {replacement_file_path.name} ({file_size} bytes)")

    def replace_bnk_wems(self, bnk_id, bnk_wems_dir, lang_id=0):

        lang_name = self.language_names.get(lang_id, f'lang_{lang_id}')
        print(f"\n  Modifying BNK {bnk_id} (lang_id={lang_id}, {lang_name})...")

        if lang_id not in self.soundbank_titles or bnk_id not in self.soundbank_titles[lang_id]:
            print(f"    Error: BNK {bnk_id} not found in original PCK with lang_id={lang_id} ({lang_name})")
            print(f"    Available BNKs: {list(self.soundbank_titles.get(lang_id, {}).keys())[:10]}...")
            return

        file_index, size, offset = self.soundbank_titles[lang_id][bnk_id][0]
        original_file = self.file_list[file_index]
        original_file.seek(offset)
        bnk_bytes = original_file.read(size)

        try:
            bnk = BNKFile(bnk_bytes=bnk_bytes)
        except Exception as e:
            print(f"    Error loading BNK: {e}")
            return

        wem_files = list(Path(bnk_wems_dir).glob('*.wem'))
        replaced_count = 0

        for wem_file in wem_files:
            try:
                wem_id = int(wem_file.stem)
                bnk.replace_wem(wem_id, wem_path=wem_file)
                replaced_count += 1
            except KeyError as e:
                print(f"    Warning: {e}")
            except ValueError:
                print(f"    Warning: Skipping {wem_file.name} - invalid WEM ID")

        if replaced_count == 0:
            print(f"    No WEM files were replaced in BNK {bnk_id}")
            return

        modified_bnk_bytes = bnk.get_bytes()

        file_index = len(self.file_list)
        temp_bnk = BytesIO(modified_bnk_bytes)
        temp_bnk.seek(0)
        self.file_list.append(temp_bnk)

        self.soundbank_titles[lang_id][bnk_id] = [(file_index, len(modified_bnk_bytes), 0)]

        print(f"    ✓ Modified BNK {bnk_id}: replaced {replaced_count} WEM(s), new size: {len(modified_bnk_bytes)} bytes")

    def replace_files_from_directory(self, replacements_dir, lang_id=0):

        replacements_dir = Path(replacements_dir)

        if not replacements_dir.exists():
            raise FileNotFoundError(f"Replacements directory not found: {replacements_dir}")

        wem_files = list(replacements_dir.glob('*.wem'))

        bnk_dirs = [d for d in replacements_dir.iterdir() if d.is_dir() and d.name.endswith('_bnk')]

        if wem_files:
            print(f"\nReplacing {len(wem_files)} WEM files from {replacements_dir}...")
            for wem_file in wem_files:
                try:

                    file_id = int(wem_file.stem)
                    self.replace_file(file_id, wem_file, lang_id)
                except ValueError:
                    print(f"  Warning: Skipping {wem_file.name} - filename is not a valid ID")

        if bnk_dirs:
            print(f"\nProcessing {len(bnk_dirs)} BNK directories...")
            for bnk_dir in bnk_dirs:
                try:

                    bnk_id = int(bnk_dir.name.replace('_bnk', ''))
                    self.replace_bnk_wems(bnk_id, bnk_dir, lang_id)
                except ValueError:
                    print(f"  Warning: Skipping {bnk_dir.name} - invalid BNK ID format")

    def pack(self, use_patching=True):

        if use_patching:
            self.pack_with_patching()
        else:
            self.pack_with_rebuild()

    def pack_with_patching(self):

        print(f"\nBuilding PCK file (patching mode): {self.output_pck_path}")

        import shutil
        shutil.copy2(self.original_pck_path, self.output_pck_path)
        print(f"  Copied original PCK: {self.output_pck_path.stat().st_size:,} bytes")

        patches = []

        for section_name, section_map in [
            ('stream_files', self.stream_files),
            ('soundbank_titles', self.soundbank_titles),
            ('soundbank_files', self.soundbank_files)
        ]:
            for lang_id in section_map:
                for file_id in section_map[lang_id]:
                    file_info_list = section_map[lang_id][file_id]
                    file_index, new_size, origin_offset = file_info_list[-1]

                    if file_index != 0:
                        patches.append({
                            'section': section_name,
                            'file_id': file_id,
                            'lang_id': lang_id,
                            'new_data_index': file_index,
                            'new_size': new_size,
                            'origin_offset': origin_offset
                        })

        if not patches:
            print("  No replacements to apply - output is identical to original")
            return

        print(f"  Applying {len(patches)} replacement(s)...")

        from src.pck_indexer import PCKIndexer
        indexer = PCKIndexer(self.original_pck_path)
        index = indexer.build_index()

        with open(self.output_pck_path, 'r+b') as f:
            for patch in patches:
                file_id = patch['file_id']

                original_entry = None

                for sound in index['sounds']:
                    if sound['id'] == file_id:
                        original_entry = sound
                        break

                if not original_entry:
                    for bank in index['banks']:
                        if bank['id'] == file_id:
                            original_entry = bank
                            break

                if not original_entry:
                    print(f"    Warning: Could not find file {file_id} in original PCK")
                    continue

                original_offset = original_entry['offset']
                original_size = original_entry['size']
                new_size = patch['new_size']

                new_file = self.file_list[patch['new_data_index']]
                new_file.seek(patch['origin_offset'])
                new_data = new_file.read(new_size)

                if new_size == original_size:

                    f.seek(original_offset)
                    f.write(new_data)
                    print(f"    ✓ Patched ID {file_id} at offset {original_offset} ({new_size} bytes)")

                elif new_size < original_size:

                    f.seek(original_offset)
                    f.write(new_data)
                    padding = original_size - new_size
                    f.write(b'\x00' * padding)
                    print(f"    ✓ Patched ID {file_id} at offset {original_offset} ({new_size} bytes, padded {padding} bytes)")

                else:

                    print(f"    ⚠ Warning: ID {file_id} is larger than original ({new_size} > {original_size})")
                    print(f"       Truncating to fit original size. Audio may be incomplete!")
                    f.seek(original_offset)
                    f.write(new_data[:original_size])

        print(f"✓ PCK file patched: {self.output_pck_path}")
        print(f"  Size: {self.output_pck_path.stat().st_size:,} bytes")

    def pack_with_rebuild(self):

        print(f"\nBuilding PCK file (rebuild mode): {self.output_pck_path}")

        with open(self.output_pck_path, 'wb') as f:

            f.write(self.MAGIC)

            bt_size, bt_langid, bt_hash, bt_file_size = self._precalculate_section(self.soundbank_titles, base_count=5)
            bf_size, bf_langid, bf_hash, bf_file_size = self._precalculate_section(self.soundbank_files, base_count=5)
            sf_size, sf_langid, sf_hash, sf_file_size = self._precalculate_section(self.stream_files, base_count=6)

            langid = list(set(bt_langid + bf_langid + sf_langid + [0]))
            language_map = self._build_language_map(langid)
            language_map_size = len(language_map)

            header_size = language_map_size + bt_size + bf_size + sf_size + 20

            f.write(struct.pack('<6I', header_size, 1, language_map_size, bt_size, bf_size, sf_size))

            f.write(language_map)
            header_size += 8

            bt_write_info = self._build_file_table(f, bt_hash, header_size, use_8byte_id=False)
            header_size += bt_file_size

            bf_write_info = self._build_file_table(f, bf_hash, header_size, use_8byte_id=False)
            header_size += bf_file_size

            sf_write_info = self._build_file_table(f, sf_hash, header_size, use_8byte_id=True)

            self._write_audio_data(f, bt_write_info)
            self._write_audio_data(f, bf_write_info)
            self._write_audio_data(f, sf_write_info)

        print(f"✓ PCK file created: {self.output_pck_path}")
        print(f"  Size: {self.output_pck_path.stat().st_size:,} bytes")

    def _precalculate_section(self, section_map, base_count):

        size = 1
        hash_data = {}
        files_size = 0
        lang_id = list(section_map.keys())

        for single_lang in lang_id:
            lang_map = section_map[single_lang]
            lens = len(lang_map)
            if lens:
                size += lens * base_count

            for file_id in lang_map:
                info = lang_map[file_id][-1]
                files_size += info[1]

                if file_id not in hash_data:
                    hash_data[file_id] = {}
                hash_data[file_id][single_lang] = info

        sorted_hash = sorted(hash_data.items(), key=lambda d: d[0])
        return size * 4, lang_id, sorted_hash, files_size

    def _build_language_map(self, lang_ids):

        lang_str = []
        lang_ids_sorted = sorted(lang_ids, reverse=True)

        for lang_id in lang_ids_sorted:
            if lang_id in self.language_names:

                lang_name = self.language_names[lang_id]
            else:

                langdel = {self.language_def[name]: name.lower() for name in self.language_def}
                if lang_id in langdel:
                    lang_name = langdel[lang_id]
                else:
                    lang_name = f"lang_{lang_id}"

            encoded = ""
            for char in lang_name:
                encoded += char
            lang_bytes = (encoded.encode('utf-16-le') + b'\x00\x00')
            lang_str.append(lang_bytes)

        fbuf = BytesIO()
        lens = len(lang_ids_sorted)
        fbuf.write(struct.pack('<I', lens))

        lang_str_offset = 8 * lens + 4
        for i, lang_id in enumerate(lang_ids_sorted):
            fbuf.write(struct.pack('<I', lang_str_offset))
            fbuf.write(struct.pack('<I', lang_id))
            lang_str_offset += len(lang_str[i])

        for lang_bytes in lang_str:
            fbuf.write(lang_bytes)

        return fbuf.getvalue()

    def _build_file_table(self, f, map_data, init_offset, use_8byte_id=False):

        file_list = []

        f.write(struct.pack('<I', len(map_data)))

        for hash_info in map_data:
            file_id, lang_dict = hash_info
            lang_items = sorted(lang_dict.items(), key=lambda d: d[0])

            for lang_id, file_info in lang_items:
                package_id, file_size, origin_offset = file_info

                from math import ceil
                offset_multiplicand = (init_offset >> 32) + 1
                offset_multiplier = ceil(init_offset / offset_multiplicand)
                fill_bytes = init_offset % offset_multiplicand

                file_list.append((package_id, file_size, origin_offset, fill_bytes))

                if use_8byte_id:
                    f.write(struct.pack('<Q', file_id))
                else:
                    f.write(struct.pack('<I', file_id))

                f.write(struct.pack('<4I', offset_multiplicand, file_size, offset_multiplier, lang_id))

                init_offset += (fill_bytes + file_size)

        return file_list

    def _write_audio_data(self, f, file_list):

        for package_id, file_size, origin_offset, fill_bytes in file_list:
            file_obj = self.file_list[package_id]
            file_obj.seek(origin_offset)
            data = file_obj.read(file_size)
            f.write(data)

            if fill_bytes:
                f.write(b'\xFF' * fill_bytes)

    def close(self):

        for f in self.file_list:
            f.close()
        self.file_list = []

    def __del__(self):

        self.close()

def main():

    import sys

    if len(sys.argv) < 4:
        print("Usage: python pck_packer.py <original_pck> <replacements_dir> <output_pck>")
        print("")
        print("Example:")
        print("  python pck_packer.py Streamed_SFX_1.pck ./my_wem_files/ Streamed_SFX_1_modded.pck")
        print("")
        print("The replacements directory should contain .wem files named by their ID:")
        print("  134133939.wem")
        print("  86631895.wem")
        print("  etc.")
        sys.exit(1)

    original_pck = sys.argv[1]
    replacements_dir = sys.argv[2]
    output_pck = sys.argv[3]

    packer = PCKPacker(original_pck, output_pck)
    packer.load_original_pck()
    packer.replace_files_from_directory(replacements_dir)

    packer.pack(use_patching=True)
    packer.close()

if __name__ == "__main__":
    main()
