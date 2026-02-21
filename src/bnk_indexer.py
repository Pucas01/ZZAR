

from struct import unpack
from io import BytesIO
from collections import OrderedDict

class BNKIndexer:


    def __init__(self, bnk_bytes):

        self.bnk_bytes = bnk_bytes
        self.wem_list = []
        self.data_offset = 0

    def parse_didx(self):

        stream = BytesIO(self.bnk_bytes)

        didx_found = False
        data_found = False
        didx_offsets = OrderedDict()
        didx_sizes = OrderedDict()

        while True:
            tag = stream.read(4)
            if len(tag) < 4:
                break

            size = unpack('<I', stream.read(4))[0]
            chunk_start = stream.tell()

            if tag == b'DIDX':

                num_entries = size // 12
                for i in range(num_entries):
                    wem_id = unpack('<I', stream.read(4))[0]
                    offset = unpack('<I', stream.read(4))[0]
                    wem_size = unpack('<I', stream.read(4))[0]
                    didx_offsets[wem_id] = offset
                    didx_sizes[wem_id] = wem_size

                didx_found = True

            elif tag == b'DATA':

                self.data_offset = chunk_start
                data_found = True

                stream.seek(chunk_start + size)

            else:

                stream.seek(chunk_start + size)

            if didx_found and data_found:
                break

        for wem_id in didx_offsets:
            self.wem_list.append({
                'wem_id': wem_id,
                'offset': didx_offsets[wem_id],
                'size': didx_sizes[wem_id]
            })

        return self.wem_list

    def extract_wem(self, wem_id):


        wem_info = None
        for wem in self.wem_list:
            if wem['wem_id'] == wem_id:
                wem_info = wem
                break

        if not wem_info:
            raise KeyError(f"WEM {wem_id} not found in BNK")

        absolute_offset = self.data_offset + wem_info['offset']
        wem_bytes = self.bnk_bytes[absolute_offset:absolute_offset + wem_info['size']]

        return wem_bytes

    def get_wem_count(self):

        return len(self.wem_list)

    def get_wem_ids(self):

        return [wem['wem_id'] for wem in self.wem_list]
