

import struct
import os
from pathlib import Path

class PCKExtractor:


    MAGIC = b'AKPK'

    def __init__(self, pck_path):

        self.pck_path = Path(pck_path)
        self.file_handle = None
        self.files_info = []
        self.banks_info = []

        self.lang_map = {
            0: 'sfx',
            1: 'english',
            2: 'chinese',
            3: 'japanese',
            4: 'korean'
        }

    def _read_uint32(self):

        return struct.unpack('<I', self.file_handle.read(4))[0]

    def _read_uint64(self):

        return struct.unpack('<Q', self.file_handle.read(8))[0]

    def validate_header(self):

        magic = self.file_handle.read(4)
        if magic != self.MAGIC:
            raise ValueError(f"Invalid PCK file: expected {self.MAGIC}, got {magic}")
        return True

    def _parse_file_table(self, section_size, use_8byte_id=False):

        files = []

        if section_size == 0:
            return files

        file_count = self._read_uint32()

        if file_count == 0:
            return files

        entry_size = (section_size - 4) / file_count

        for i in range(file_count):

            if use_8byte_id:
                file_id = self._read_uint64()
            else:
                file_id = self._read_uint32()

            blocksize = self._read_uint32()
            size = self._read_uint32()
            offset_block = self._read_uint32()
            lang_id = self._read_uint32()

            if blocksize != 0:
                offset = offset_block * blocksize
            else:
                offset = offset_block

            lang_name = self.lang_map.get(lang_id, f'lang_{lang_id}')

            files.append({
                'id': file_id,
                'offset': offset,
                'size': size,
                'lang_id': lang_id,
                'lang_name': lang_name
            })

        return files

    def parse_header(self):

        self.file_handle.seek(0)
        self.validate_header()

        header_size = self._read_uint32()
        version = self._read_uint32()
        sec1_size = self._read_uint32()
        sec2_size = self._read_uint32()
        sec3_size = self._read_uint32()

        sec_sum = sec1_size + sec2_size + sec3_size + 0x10
        if sec_sum < header_size:
            sec4_size = self._read_uint32()
        else:
            sec4_size = 0

        print(f"PCK Format: AKPK v{version}")
        print(f"Header size: {header_size} bytes (0x{header_size:x})")
        print(f"Sections: Languages={sec1_size}, Banks={sec2_size}, Sounds={sec3_size}, Externals={sec4_size}")

        strings_offset = self.file_handle.tell()
        if sec1_size > 0:
            lang_count = self._read_uint32()

            lang_defs = []
            for i in range(lang_count):
                lang_offset = self._read_uint32()
                lang_id = self._read_uint32()
                lang_defs.append((lang_id, strings_offset + lang_offset))

            for lang_id, lang_offset in lang_defs:
                current_pos = self.file_handle.tell()
                self.file_handle.seek(lang_offset)

                lang_name = ""
                while True:
                    char_bytes = self.file_handle.read(2)
                    if char_bytes == b'\x00\x00' or len(char_bytes) < 2:
                        break
                    try:
                        lang_name += char_bytes.decode('utf-16-le')
                    except:
                        break

                if lang_name:
                    self.lang_map[lang_id] = lang_name.lower()
                    print(f"  Language {lang_id}: {lang_name}")

                self.file_handle.seek(current_pos)

        self.file_handle.seek(strings_offset + sec1_size)

        print(f"\nParsing Banks section...")
        banks = self._parse_file_table(sec2_size, use_8byte_id=False)
        print(f"  Found {len(banks)} bank files")

        print(f"\nParsing Sounds section...")
        sounds = self._parse_file_table(sec3_size, use_8byte_id=False)
        print(f"  Found {len(sounds)} sound files")

        if sec4_size > 0:
            print(f"\nParsing Externals section...")
            externals = self._parse_file_table(sec4_size, use_8byte_id=True)
            print(f"  Found {len(externals)} external files")
        else:
            externals = []

        self.banks_info = banks

        self.files_info = sounds + externals

        print(f"\n✓ Total WEM files: {len(self.files_info)}")
        print(f"✓ Total BNK files: {len(self.banks_info)}")
        return self.files_info

    def extract_file(self, file_info, output_dir, file_extension='.wem'):

        output_dir = Path(output_dir)

        lang_dir = output_dir / file_info['lang_name']
        lang_dir.mkdir(parents=True, exist_ok=True)

        self.file_handle.seek(file_info['offset'])
        file_data = self.file_handle.read(file_info['size'])

        output_file = lang_dir / f"{file_info['id']}{file_extension}"
        with open(output_file, 'wb') as f:
            f.write(file_data)

        return output_file

    def extract_all(self, output_dir, extract_bnk=False):

        with open(self.pck_path, 'rb') as f:
            self.file_handle = f
            self.parse_header()

            if self.files_info:
                print(f"\nExtracting {len(self.files_info)} WEM files to {output_dir}/...")

                for i, file_info in enumerate(self.files_info):
                    try:
                        output_file = self.extract_file(file_info, output_dir, '.wem')
                        if (i + 1) % 100 == 0:
                            print(f"  [{i+1}/{len(self.files_info)}] {output_file.relative_to(output_dir)}")
                    except Exception as e:
                        print(f"  [{i+1}/{len(self.files_info)}] Error extracting WEM {file_info['id']}: {e}")

                print(f"\n✓ Extracted {len(self.files_info)} WEM files")

            if extract_bnk and self.banks_info:
                print(f"\nExtracting {len(self.banks_info)} BNK files to {output_dir}/...")

                for i, bank_info in enumerate(self.banks_info):
                    try:
                        output_file = self.extract_file(bank_info, output_dir, '.bnk')
                        if (i + 1) % 100 == 0:
                            print(f"  [{i+1}/{len(self.banks_info)}] {output_file.relative_to(output_dir)}")
                    except Exception as e:
                        print(f"  [{i+1}/{len(self.banks_info)}] Error extracting BNK {bank_info['id']}: {e}")

                print(f"\n✓ Extracted {len(self.banks_info)} BNK files")

            if not self.files_info and not (extract_bnk and self.banks_info):
                print("\n⚠️  No files extracted!")

            print(f"\n✓ Extraction complete! Files saved to: {output_dir}")

def main():

    import sys

    if len(sys.argv) < 2:
        print("Usage: python pck_extractor.py <pck_file> [output_dir] [--bnk]")
        print("")
        print("Examples:")
        print("  python pck_extractor.py Streamed_SFX_1.pck ./extracted")
        print("  python pck_extractor.py SoundBank_SFX_1.pck ./extracted --bnk")
        print("")
        print("Options:")
        print("  --bnk    Also extract .bnk files (for SoundBank PCKs)")
        sys.exit(1)

    pck_file = sys.argv[1]
    output_dir = "./extracted"
    extract_bnk = False

    for arg in sys.argv[2:]:
        if arg == '--bnk':
            extract_bnk = True
        elif not arg.startswith('--'):
            output_dir = arg

    extractor = PCKExtractor(pck_file)
    extractor.extract_all(output_dir, extract_bnk=extract_bnk)

if __name__ == "__main__":
    main()
