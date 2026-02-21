

from struct import pack, unpack, error as struct_error
from collections import OrderedDict
from io import BytesIO
from pathlib import Path

def align16(x):

    return (16 - (x % 16)) % 16

class WEM:

    def __init__(self, data):
        self.data = data

    def __len__(self):
        return len(self.data)

    def getdata(self):
        return self.data

class BKHD:

    def __init__(self, data):
        self.data = data
        self.tag = b'BKHD'

    def __len__(self):
        return len(self.data.getvalue())

    def getdata(self):
        return self.tag + pack('<I', len(self)) + self.data.getvalue()

class DIDX:

    def __init__(self, data):
        self.tag = b'DIDX'
        self.data = data
        self.wem_sizes = OrderedDict()
        self.wem_offsets = OrderedDict()

        num_entries = int(len(self) / 0xC)
        for i in range(num_entries):
            wem_id = unpack('<I', self.data.read(4))[0]
            offset = unpack('<I', self.data.read(4))[0]
            size = unpack('<I', self.data.read(4))[0]
            self.wem_offsets[wem_id] = offset
            self.wem_sizes[wem_id] = size

    def __len__(self):
        return len(self.data.getvalue())

    def setdata(self, new_offsets):

        self.data = BytesIO()
        for wem_id in new_offsets:
            self.data.write(pack('<I', wem_id))
            self.data.write(pack('<I', new_offsets[wem_id][0]))
            self.data.write(pack('<I', new_offsets[wem_id][1]))
        self.data.seek(0)

    def getdata(self):
        return self.tag + pack('<I', len(self)) + self.data.getvalue()

class DATA:

    def __init__(self, data):
        self.tag = b'DATA'
        self.data = data
        self.wem_data = OrderedDict()
        self.start_pos = 0

    def __len__(self):
        return len(self.data.getvalue())

    def split(self, didx_data):

        for wem_id in didx_data.wem_sizes:
            self.data.seek(didx_data.wem_offsets[wem_id])
            wem_bytes = self.data.read(didx_data.wem_sizes[wem_id])
            self.wem_data[wem_id] = WEM(wem_bytes)

    def setdata(self):

        wem_offsets = OrderedDict()
        wems = list(self.wem_data.keys())
        self.data = BytesIO()
        curr_location = 0

        for i, wem_id in enumerate(wems):

            wem_offsets[wem_id] = (curr_location, len(self.wem_data[wem_id]))

            self.data.write(self.wem_data[wem_id].getdata())
            curr_location += len(self.wem_data[wem_id])

            if i == 0 and i != len(wems) - 1:

                file_padding = align16(len(self.wem_data[wem_id]) + self.start_pos)
            elif i != len(wems) - 1:

                file_padding = align16(len(self.wem_data[wem_id]))
            else:

                file_padding = 0

            if file_padding != 0:
                self.data.write(b'\x00' * file_padding)
            curr_location += file_padding

        return wem_offsets

    def getdata(self):
        return self.tag + pack('<I', len(self)) + self.data.getvalue()

class HIRC:

    def __init__(self, data):
        self.tag = b'HIRC'
        self.data = data
        self.entries = unpack('<I', data.read(4))[0]
        self.data = BytesIO(self.data.read())

    def __len__(self):
        return len(self.data.getvalue()) + 4

    def getdata(self):
        return self.tag + pack('<I', len(self)) + pack('<I', self.entries) + self.data.getvalue()

class BNKFile:


    def __init__(self, bnk_path=None, bnk_bytes=None):

        self.data = OrderedDict()

        if bnk_path:
            with open(bnk_path, 'rb') as f:
                self._parse_bnk(f)
        elif bnk_bytes:
            self._parse_bnk(BytesIO(bnk_bytes))

    def _parse_bnk(self, stream):


        magic = stream.read(4)
        if magic != b'BKHD':
            raise ValueError(f"Invalid BNK file: expected BKHD, got {magic}")

        stream.seek(0)

        while True:
            try:
                tag = stream.read(4)
                if len(tag) < 4:
                    break

                tag_str = tag.decode('ascii')
                size = unpack('<I', stream.read(4))[0]
                chunk_data = BytesIO(stream.read(size))

                if tag_str == 'BKHD':
                    self.data['BKHD'] = BKHD(chunk_data)
                elif tag_str == 'DIDX':
                    self.data['DIDX'] = DIDX(chunk_data)
                elif tag_str == 'DATA':
                    self.data['DATA'] = DATA(chunk_data)
                elif tag_str == 'HIRC':
                    self.data['HIRC'] = HIRC(chunk_data)
                else:

                    print(f"  Unknown BNK chunk: {tag_str} ({size} bytes)")

            except (struct_error, UnicodeDecodeError):
                break

        if 'DATA' in self.data and 'DIDX' in self.data:
            self.data['DATA'].split(self.data['DIDX'])

    def list_wems(self):

        if 'DATA' not in self.data or self.data['DATA'] is None:
            return []
        return list(self.data['DATA'].wem_data.keys())

    def extract_wem(self, wem_id, output_path=None):

        if 'DATA' not in self.data:
            raise ValueError("BNK has no DATA section")

        if wem_id not in self.data['DATA'].wem_data:
            raise KeyError(f"WEM ID {wem_id} not found in BNK")

        wem_data = self.data['DATA'].wem_data[wem_id].getdata()

        if output_path:
            with open(output_path, 'wb') as f:
                f.write(wem_data)

        return wem_data

    def replace_wem(self, wem_id, wem_path=None, wem_bytes=None):

        if 'DATA' not in self.data:
            raise ValueError("BNK has no DATA section")

        if wem_path:
            with open(wem_path, 'rb') as f:
                wem_bytes = f.read()
        elif wem_bytes is None:
            raise ValueError("Must provide either wem_path or wem_bytes")

        if wem_id not in self.data['DATA'].wem_data:
            raise KeyError(f"WEM ID {wem_id} not found in BNK. Available IDs: {self.list_wems()}")

        self.data['DATA'].wem_data[wem_id] = WEM(wem_bytes)

        self._correct_offsets()

        print(f"  Replaced WEM {wem_id} in BNK ({len(wem_bytes)} bytes)")

    def _correct_offsets(self):

        if self.data is None:
            return

        self.data['DATA'].start_pos = (
            8 + len(self.data['BKHD']) +
            8 + len(self.data['DIDX']) +
            8
        )

        new_wem_offsets = self.data['DATA'].setdata()

        self.data['DIDX'].setdata(new_wem_offsets)

    def save(self, output_path):

        with open(output_path, 'wb') as f:
            for section in self.data.values():
                f.write(section.getdata())

        print(f"  Saved BNK: {output_path}")

    def get_bytes(self):

        result = bytearray()
        for section in self.data.values():
            result.extend(section.getdata())
        return bytes(result)

def extract_bnk_wems(bnk_path, output_dir):

    bnk_path = Path(bnk_path)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    bnk = BNKFile(bnk_path)
    wem_ids = bnk.list_wems()

    print(f"\nExtracting {len(wem_ids)} WEMs from {bnk_path.name}...")

    for wem_id in wem_ids:
        output_file = output_dir / f"{wem_id}.wem"
        bnk.extract_wem(wem_id, output_file)
        print(f"  Extracted: {wem_id}.wem")

    print(f"\n✓ Extracted {len(wem_ids)} WEM files to {output_dir}")

def main():

    import sys

    if len(sys.argv) < 3:
        print("Usage: python bnk_handler.py <command> <bnk_file> [options]")
        print("")
        print("Commands:")
        print("  list <bnk_file>                    - List WEM IDs in BNK")
        print("  extract <bnk_file> <output_dir>    - Extract all WEMs from BNK")
        print("  replace <bnk_file> <wem_id> <wem_file> <output_bnk>  - Replace WEM in BNK")
        sys.exit(1)

    command = sys.argv[1]
    bnk_file = sys.argv[2]

    if command == 'list':
        bnk = BNKFile(bnk_file)
        wem_ids = bnk.list_wems()
        print(f"\nWEM files in {Path(bnk_file).name}:")
        for wem_id in wem_ids:
            print(f"  {wem_id}")
        print(f"\nTotal: {len(wem_ids)} WEM files")

    elif command == 'extract':
        if len(sys.argv) < 4:
            print("Error: extract requires <output_dir>")
            sys.exit(1)
        output_dir = sys.argv[3]
        extract_bnk_wems(bnk_file, output_dir)

    elif command == 'replace':
        if len(sys.argv) < 6:
            print("Error: replace requires <wem_id> <wem_file> <output_bnk>")
            sys.exit(1)
        wem_id = int(sys.argv[3])
        wem_file = sys.argv[4]
        output_bnk = sys.argv[5]

        bnk = BNKFile(bnk_file)
        bnk.replace_wem(wem_id, wem_file)
        bnk.save(output_bnk)
        print(f"\n✓ Created modified BNK: {output_bnk}")

    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
