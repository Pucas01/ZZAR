

import struct
from pathlib import Path

class PCKIndexer:


    MAGIC = b'AKPK'

    def __init__(self, pck_path):

        self.pck_path = Path(pck_path)
        self.index_data = {
            'banks': [],
            'sounds': [],
            'externals': []
        }

        self.lang_map = {
            0: 'sfx',
            1: 'english',
            2: 'chinese',
            3: 'japanese',
            4: 'korean'
        }

    def _read_uint32(self, f):

        return struct.unpack('<I', f.read(4))[0]

    def _read_uint64(self, f):

        return struct.unpack('<Q', f.read(8))[0]

    def _validate_header(self, f):

        magic = f.read(4)
        if magic != self.MAGIC:
            raise ValueError(f"Invalid PCK file: expected {self.MAGIC}, got {magic}")
        return True

    def _parse_file_table(self, f, section_size, use_8byte_id=False):

        files = []

        if section_size == 0:
            return files

        file_count = self._read_uint32(f)

        if file_count == 0:
            return files

        for i in range(file_count):

            if use_8byte_id:
                file_id = self._read_uint64(f)
            else:
                file_id = self._read_uint32(f)

            blocksize = self._read_uint32(f)
            size = self._read_uint32(f)
            offset_block = self._read_uint32(f)
            lang_id = self._read_uint32(f)

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

    def build_index(self):

        with open(self.pck_path, 'rb') as f:

            f.seek(0)
            self._validate_header(f)

            header_size = self._read_uint32(f)
            version = self._read_uint32(f)
            sec1_size = self._read_uint32(f)
            sec2_size = self._read_uint32(f)
            sec3_size = self._read_uint32(f)

            sec_sum = sec1_size + sec2_size + sec3_size + 0x10
            if sec_sum < header_size:
                sec4_size = self._read_uint32(f)
            else:
                sec4_size = 0

            strings_offset = f.tell()
            if sec1_size > 0:
                lang_count = self._read_uint32(f)

                lang_defs = []
                for i in range(lang_count):
                    lang_offset = self._read_uint32(f)
                    lang_id = self._read_uint32(f)
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
                        self.lang_map[lang_id] = lang_name.lower()

                    f.seek(current_pos)

            f.seek(strings_offset + sec1_size)

            banks = self._parse_file_table(f, sec2_size, use_8byte_id=False)

            sounds = self._parse_file_table(f, sec3_size, use_8byte_id=False)

            if sec4_size > 0:
                externals = self._parse_file_table(f, sec4_size, use_8byte_id=True)
            else:
                externals = []

            self.index_data['banks'] = banks
            self.index_data['sounds'] = sounds
            self.index_data['externals'] = externals

        return self.index_data

    def get_file_list(self, file_type='all'):

        if file_type == 'banks':
            return self.index_data['banks']
        elif file_type == 'sounds':
            return self.index_data['sounds']
        elif file_type == 'externals':
            return self.index_data['externals']
        elif file_type == 'all':
            return (self.index_data['banks'] +
                    self.index_data['sounds'] +
                    self.index_data['externals'])
        else:
            raise ValueError(f"Invalid file_type: {file_type}")

    def extract_single_file(self, file_id, file_type='wem', lang_id=None):


        file_info = None

        if file_type == 'bnk':
            search_lists = [self.index_data['banks']]
        else:
            search_lists = [self.index_data['sounds'], self.index_data['externals']]

        for file_list in search_lists:
            for info in file_list:
                if info['id'] == file_id:
                    if lang_id is None or info['lang_id'] == lang_id:
                        file_info = info
                        break
            if file_info:
                break

        if not file_info:
            raise KeyError(f"File {file_id} not found in PCK index")

        with open(self.pck_path, 'rb') as f:
            f.seek(file_info['offset'])
            data = f.read(file_info['size'])

        return data

    def get_file_count(self):

        return (len(self.index_data['banks']) +
                len(self.index_data['sounds']) +
                len(self.index_data['externals']))
