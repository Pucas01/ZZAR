

import subprocess
import os
import sys
import platform
from pathlib import Path
import shutil

_is_windows = platform.system() == "Windows"
_subprocess_kwargs = {"creationflags": subprocess.CREATE_NO_WINDOW} if _is_windows else {}

if os.environ.get('ZZAR_FLATPAK'):
    _BASE_DIR = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / 'ZZAR'
elif hasattr(sys, '_MEIPASS'):
    _BASE_DIR = Path(sys.executable).parent.resolve()
else:
    _BASE_DIR = Path(__file__).resolve().parent.parent

try:
    from wwise_wrapper import WwiseConsole
    WWISE_AVAILABLE = True
except ImportError:
    WWISE_AVAILABLE = False

class AudioConverter:


    def __init__(self):

        self.ffmpeg_path = self._find_ffmpeg()
        self.vgmstream_path = self._find_vgmstream()
        self.wwise_console = WwiseConsole() if WWISE_AVAILABLE else None

    def _find_ffmpeg(self):


        if platform.system() == "Windows":

            possible_paths = [
                _BASE_DIR / "tools" / "audio" / "ffmpeg" / "ffmpeg-master-latest-win64-gpl" / "bin" / "ffmpeg.exe",
                _BASE_DIR / "tools" / "audio" / "ffmpeg" / "bin" / "ffmpeg.exe",
            ]

            for local_ffmpeg in possible_paths:
                if local_ffmpeg.exists():
                    return str(local_ffmpeg.resolve())

        ffmpeg = shutil.which('ffmpeg')
        if not ffmpeg:

            if platform.system() == "Windows":
                return None

            raise RuntimeError("FFmpeg not found! Please install: sudo pacman -S ffmpeg")
        return ffmpeg

    def _find_vgmstream(self):


        if platform.system() == "Windows":

            local_vgmstream = _BASE_DIR / "tools" / "audio" / "vgmstream" / "vgmstream-cli.exe"
            if local_vgmstream.exists():
                return str(local_vgmstream.resolve())

        vgmstream = shutil.which('vgmstream-cli')
        return vgmstream

    def wem_to_wav(self, wem_file, output_file=None):

        wem_file = Path(wem_file)
        if output_file is None:
            output_file = wem_file.with_suffix('.wav')
        else:
            output_file = Path(output_file)

        if not self.vgmstream_path and not self.ffmpeg_path:
            if platform.system() == "Windows":
                raise RuntimeError(
                    "Audio conversion tools not found.\n\n"
                    "Please install FFmpeg and vgmstream from the Settings page."
                )
            else:
                raise RuntimeError(
                    "Audio conversion tools not found.\n\n"
                    "Please install vgmstream-cli and ffmpeg:\n"
                    "  Arch Linux: sudo pacman -S vgmstream ffmpeg\n"
                    "  Ubuntu/Debian: sudo apt install vgmstream-cli ffmpeg"
                )

        if self.vgmstream_path:
            try:
                subprocess.run([
                    self.vgmstream_path,
                    '-o', str(output_file),
                    str(wem_file)
                ], check=True, capture_output=True, **_subprocess_kwargs)
                print(f"Converted (vgmstream): {wem_file.name} -> {output_file.name}")
                return output_file
            except subprocess.CalledProcessError as e:
                print(f"vgmstream failed, trying FFmpeg...")

        if self.ffmpeg_path:
            try:
                subprocess.run([
                    self.ffmpeg_path,
                    '-i', str(wem_file),
                    '-acodec', 'pcm_s16le',
                    '-ar', '48000',
                    '-y',
                    str(output_file)
                ], check=True, capture_output=True, text=True, **_subprocess_kwargs)
                print(f"Converted (ffmpeg): {wem_file.name} -> {output_file.name}")
                return output_file
            except subprocess.CalledProcessError as e:
                pass

        if platform.system() == "Windows":
            raise RuntimeError(
                f"\n=== Failed to convert {wem_file.name} ===\n"
                f"WEM files require vgmstream-cli for conversion.\n\n"
                f"Please install the audio tools from the Settings page.\n"
            )
        else:
            raise RuntimeError(
                f"\n=== Failed to convert {wem_file.name} ===\n"
                f"WEM files use a custom Wwise audio format that requires vgmstream-cli.\n\n"
                f"Install vgmstream-cli:\n"
                f"  Arch Linux (AUR): yay -S vgmstream-cli-bin\n"
                f"  Ubuntu/Debian:    sudo apt install vgmstream-cli\n"
                f"  Or build from:    https://github.com/vgmstream/vgmstream\n\n"
                f"FFmpeg cannot decode this WEM file format.\n"
            )

    def any_to_wav(self, input_file, output_file=None, sample_rate=48000, channels=2, normalize=True):

        input_file = Path(input_file)
        if output_file is None:
            output_file = input_file.with_suffix('.wav')
        else:
            output_file = Path(output_file)

        if not self.ffmpeg_path:
            if platform.system() == "Windows":
                raise RuntimeError(
                    "FFmpeg not found.\n\n"
                    "Please install the audio tools from the Settings page."
                )
            else:
                raise RuntimeError(
                    "FFmpeg not found.\n\n"
                    "Please install ffmpeg:\n"
                    "  Arch Linux: sudo pacman -S ffmpeg\n"
                    "  Ubuntu/Debian: sudo apt install ffmpeg"
                )

        try:
            cmd = [
                self.ffmpeg_path,
                '-i', str(input_file),
            ]
            if normalize:
                cmd.extend(['-af', 'loudnorm=I=-9:TP=-1.5:LRA=11'])
            cmd.extend([
                '-acodec', 'pcm_s16le',
                '-ar', str(sample_rate),
                '-ac', str(channels),
                '-y',
                str(output_file)
            ])

            subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **_subprocess_kwargs)
            norm_msg = " (normalized to -9 LUFS)" if normalize else ""
            print(f"Converted: {input_file.name} -> {output_file.name}{norm_msg}")
            return output_file
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to convert {input_file}: {e}")

    def wav_to_wem(self, wav_file, output_file=None, wwise_dir=None):

        wav_file = Path(wav_file)

        if not WWISE_AVAILABLE or not self.wwise_console:
            raise RuntimeError(
                "Wwise is not installed.\n\n"
                "Please install Wwise from the Settings page to convert WAV files to WEM format."
            )

        if wwise_dir:
            wwise = WwiseConsole(wwise_dir)
        else:
            wwise = self.wwise_console

        if not wwise.is_installed():
            raise RuntimeError(
                "Wwise is not installed.\n\n"
                "Please install Wwise from the Settings page to convert WAV files to WEM format."
            )

        if output_file is None:
            output_dir = wav_file.parent
        else:
            output_file = Path(output_file)
            output_dir = output_file.parent

        try:
            result_wem = wwise.convert_to_wem(wav_file, output_dir)

            if output_file and result_wem != output_file:
                result_wem.rename(output_file)
                return output_file

            return result_wem

        except Exception as e:
            raise RuntimeError(f"Failed to convert {wav_file.name} to .wem: {e}")

    def batch_convert_wem_to_wav(self, input_dir, output_dir=None):

        input_dir = Path(input_dir)
        if output_dir is None:
            output_dir = input_dir / 'wav'
        else:
            output_dir = Path(output_dir)

        output_dir.mkdir(parents=True, exist_ok=True)

        wem_files = list(input_dir.glob('*.wem'))
        converted = []

        print(f"\nConverting {len(wem_files)} .wem files to .wav...")

        for i, wem_file in enumerate(wem_files):
            try:
                output_file = output_dir / wem_file.with_suffix('.wav').name
                self.wem_to_wav(wem_file, output_file)
                converted.append(output_file)
            except Exception as e:
                print(f"[{i+1}/{len(wem_files)}] Error: {e}")

        print(f"\nConverted {len(converted)}/{len(wem_files)} files")
        return converted

    def batch_convert_to_wav(self, input_dir, output_dir=None, pattern='*', normalize=True):

        input_dir = Path(input_dir)
        if output_dir is None:
            output_dir = input_dir / 'wav'
        else:
            output_dir = Path(output_dir)

        output_dir.mkdir(parents=True, exist_ok=True)

        audio_extensions = ['.mp3', '.flac', '.ogg', '.m4a', '.aac', '.opus', '.wma']
        audio_files = []

        for ext in audio_extensions:
            audio_files.extend(input_dir.glob(f'*{ext}'))

        converted = []

        print(f"\nConverting {len(audio_files)} audio files to .wav...")

        for i, audio_file in enumerate(audio_files):
            try:
                output_file = output_dir / audio_file.with_suffix('.wav').name
                self.any_to_wav(audio_file, output_file, normalize=normalize)
                converted.append(output_file)
            except Exception as e:
                print(f"[{i+1}/{len(audio_files)}] Error: {e}")

        print(f"\nConverted {len(converted)}/{len(audio_files)} files")
        return converted

    def batch_convert_wav_to_wem(self, input_dir, output_dir=None):

        input_dir = Path(input_dir)
        if output_dir is None:
            output_dir = input_dir / 'wem'
        else:
            output_dir = Path(output_dir)

        output_dir.mkdir(parents=True, exist_ok=True)

        if not WWISE_AVAILABLE or not self.wwise_console or not self.wwise_console.is_installed():
            raise RuntimeError(
                "Wwise is not installed.\n\n"
                "Please install Wwise from the Settings page to convert WAV files to WEM format."
            )

        wav_files = list(input_dir.glob('*.wav'))

        if not wav_files:
            print(f"No .wav files found in {input_dir}")
            return []

        return self.wwise_console.batch_convert_to_wem(wav_files, output_dir)

def main():

    import sys

    if len(sys.argv) < 2:
        print("Usage: python audio_converter.py <input_file_or_dir> [output] [--mode=MODE]")
        print("")
        print("Modes:")
        print("  wem2wav  - Convert .wem to .wav (default)")
        print("  any2wav  - Convert any audio format to .wav")
        print("  wav2wem  - Convert .wav to .wem (requires Wwise)")
        print("")
        print("Examples:")
        print("  python audio_converter.py extracted/")
        print("  python audio_converter.py my_audio.mp3 output.wav")
        print("  python audio_converter.py music_folder/ ./wav --mode=any2wav")
        print("  python audio_converter.py audio.wav --mode=wav2wem")
        print("  python audio_converter.py wav_folder/ ./wem --mode=wav2wem")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else None

    mode = 'wem2wav'
    for arg in sys.argv:
        if arg.startswith('--mode='):
            mode = arg.split('=')[1]

    converter = AudioConverter()

    try:
        if input_path.is_dir():
            if mode == 'wav2wem':
                converter.batch_convert_wav_to_wem(input_path, output_path)
            elif mode in ['any2wav', 'mp32wav']:
                converter.batch_convert_to_wav(input_path, output_path)
            else:
                converter.batch_convert_wem_to_wav(input_path, output_path)
        else:

            if mode == 'wav2wem' or input_path.suffix == '.wav':
                converter.wav_to_wem(input_path, output_path)
            elif input_path.suffix == '.wem':
                converter.wem_to_wav(input_path, output_path)
            else:
                converter.any_to_wav(input_path, output_path)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
