
import sys
import os
from pathlib import Path

if sys.platform.startswith('linux') and 'QT_QPA_PLATFORM' not in os.environ:
    os.environ['QT_QPA_PLATFORM'] = 'wayland;xcb'

if sys.platform == 'win32':
    os.environ.setdefault('QT_SCALE_FACTOR_ROUNDING_POLICY', 'PassThrough')

os.environ['QT_LOGGING_RULES'] = '*.debug=false;qt.gui.icc=false;qt.text.font.db=false;qt.network.ssl=false'

__version__ = "1.2.2"
DEV_MODE = False 

def get_base_path():

    if hasattr(sys, '_MEIPASS'):

        return Path(sys._MEIPASS)
    return Path(__file__).parent

def get_temp_dir():
    if os.environ.get('ZZAR_FLATPAK'):
        base = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / 'ZZAR'
    elif hasattr(sys, '_MEIPASS'):
        base = Path(sys.executable).parent.resolve()
    else:
        base = Path(__file__).parent
    temp = base / 'temp'
    temp.mkdir(parents=True, exist_ok=True)
    return temp

base_dir = get_base_path()

src_path = base_dir / 'src'
sys.path.insert(0, str(src_path))

try:
    from gui.main_qml import Application
except ModuleNotFoundError as e:
    print(f"Error: Could not find modules in {src_path}")
    print(f"Current sys.path: {sys.path}")
    raise e

def main():
    app = Application(version=__version__)
    sys.exit(app.run())

if __name__ == '__main__':
    main()
