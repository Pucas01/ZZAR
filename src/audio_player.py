

import os
import sys
import tempfile
from src.app_config import FLATPAK_ENV_VAR, CONFIG_DIR_NAME
import platform
import subprocess
import shutil
import time
from pathlib import Path
from PyQt5.QtCore import pyqtSignal, QObject, QTimer

if os.environ.get(FLATPAK_ENV_VAR):
    _BASE_DIR = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share')) / CONFIG_DIR_NAME
elif hasattr(sys, '_MEIPASS'):
    _BASE_DIR = Path(sys.executable).parent.resolve()
else:
    _BASE_DIR = Path(__file__).resolve().parent.parent

_is_windows = platform.system() == "Windows"

if _is_windows:
    _si = subprocess.STARTUPINFO()
    _si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    _subprocess_kwargs = {"startupinfo": _si}
    if hasattr(sys, '_MEIPASS'):
        _clean_env = os.environ.copy()
        _meipass = sys._MEIPASS
        _clean_env["PATH"] = os.pathsep.join(
            p for p in _clean_env.get("PATH", "").split(os.pathsep)
            if not p.startswith(_meipass)
        )
        _subprocess_kwargs["env"] = _clean_env
else:
    _subprocess_kwargs = {}

if not _is_windows:
    from PyQt5.QtMultimedia import QMediaPlayer, QMediaContent
    from PyQt5.QtCore import QUrl

class AudioPlayer(QObject):


    state_changed = pyqtSignal(str)
    position_changed = pyqtSignal('qint64')
    duration_changed = pyqtSignal('qint64')
    error_occurred = pyqtSignal(str)

    def __init__(self, audio_converter, cache_manager):
        super().__init__()
        self.audio_converter = audio_converter
        self.cache_manager = cache_manager
        self.current_file = None
        self.temp_files = []
        self._state = "stopped"

        if _is_windows:
            self._ffplay_process = None
            self._ffplay_path = self._find_ffplay()
            self._ffprobe_path = self._find_ffprobe()
            self._volume = 100
            self._duration_ms = 0
            self._play_start_time = 0
            self._pause_elapsed_ms = 0
            self._paused = False
            self._current_wav_path = None

            self._poll_timer = QTimer(self)
            self._poll_timer.setInterval(250)
            self._poll_timer.timeout.connect(self._poll_ffplay_status)
        else:
            self.player = QMediaPlayer()
            self.player.stateChanged.connect(self._on_state_changed)
            self.player.positionChanged.connect(self.position_changed)
            self.player.durationChanged.connect(self.duration_changed)
            self.player.error.connect(self._on_error)

    def refresh_tools(self):

        self.audio_converter.refresh_tools()
        if _is_windows:
            self._ffplay_path = self._find_ffplay()
            self._ffprobe_path = self._find_ffprobe()

    def _find_ffplay(self):

        possible_paths = [
            _BASE_DIR / "tools" / "audio" / "ffmpeg" / "ffmpeg-master-latest-win64-gpl" / "bin" / "ffplay.exe",
            _BASE_DIR / "tools" / "audio" / "ffmpeg" / "bin" / "ffplay.exe",
        ]
        for p in possible_paths:
            if p.exists():
                return str(p)
        found = shutil.which('ffplay')
        return found

    def _find_ffprobe(self):

        possible_paths = [
            _BASE_DIR / "tools" / "audio" / "ffmpeg" / "ffmpeg-master-latest-win64-gpl" / "bin" / "ffprobe.exe",
            _BASE_DIR / "tools" / "audio" / "ffmpeg" / "bin" / "ffprobe.exe",
        ]
        for p in possible_paths:
            if p.exists():
                return str(p)
        found = shutil.which('ffprobe')
        return found

    def _get_duration_ffprobe(self, filepath):

        if not self._ffprobe_path:
            return 0
        try:
            result = subprocess.run(
                [
                    self._ffprobe_path,
                    '-v', 'quiet',
                    '-show_entries', 'format=duration',
                    '-of', 'default=noprint_wrappers=1:nokey=1',
                    str(filepath)
                ],
                capture_output=True, text=True, timeout=5, **_subprocess_kwargs
            )
            if result.returncode == 0 and result.stdout.strip():
                return int(float(result.stdout.strip()) * 1000)
        except Exception:
            pass
        return 0

    def _poll_ffplay_status(self):

        if self._ffplay_process and self._ffplay_process.poll() is not None:

            self._ffplay_process = None
            self._state = "stopped"
            self._paused = False
            self._pause_elapsed_ms = 0
            self.state_changed.emit("stopped")
            self._poll_timer.stop()
            self.position_changed.emit(0)
            return

        if self._state == "playing" and self._play_start_time > 0:
            elapsed = self._pause_elapsed_ms + int((time.monotonic() - self._play_start_time) * 1000)
            if self._duration_ms > 0:
                elapsed = min(elapsed, self._duration_ms)
            self.position_changed.emit(elapsed)

    def _start_ffplay_at(self, position_ms):

        self._kill_ffplay_process()

        vol = max(0, min(100, self._volume))
        cmd = [
            self._ffplay_path,
            '-nodisp',
            '-autoexit',
            '-volume', str(vol),
            '-loglevel', 'quiet',
        ]
        if position_ms > 0:
            cmd.extend(['-ss', f'{position_ms / 1000:.3f}'])
        cmd.append(self._current_wav_path)

        self._ffplay_process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            **_subprocess_kwargs,
        )
        self._pause_elapsed_ms = position_ms
        self._paused = False
        self._play_start_time = time.monotonic()
        self._state = "playing"
        self.state_changed.emit("playing")
        self._poll_timer.start()

    def _kill_ffplay_process(self):

        if self._ffplay_process:
            try:
                self._ffplay_process.terminate()
                self._ffplay_process.wait(timeout=2)
            except Exception:
                try:
                    self._ffplay_process.kill()
                except Exception:
                    pass
            self._ffplay_process = None
        self._poll_timer.stop()

    def _stop_ffplay(self):

        self._kill_ffplay_process()
        self._play_start_time = 0
        self._pause_elapsed_ms = 0
        self._paused = False

    def play_wem(self, wem_bytes, cache_key):

        try:
            cached_wav = self.cache_manager.get_cached_path(cache_key)

            if not cached_wav:

                from ZZAR import get_temp_dir
                temp_wem = Path(tempfile.mktemp(suffix='.wem', dir=str(get_temp_dir())))
                temp_wem.write_bytes(wem_bytes)
                self.temp_files.append(temp_wem)

                wav_path = self.audio_converter.wem_to_wav(str(temp_wem))

                if isinstance(wav_path, str):
                    wav_path = Path(wav_path)

                if wav_path.exists():
                    wav_bytes = wav_path.read_bytes()
                    cached_wav = self.cache_manager.add_to_cache(
                        cache_key, wav_bytes, '.wav'
                    )
                    if temp_wem.exists():
                        temp_wem.unlink()
                    if wav_path.exists() and wav_path != cached_wav:
                        wav_path.unlink()
                else:
                    raise FileNotFoundError(f"WAV conversion failed: {wav_path}")

            self.current_file = cache_key

            if _is_windows:
                if not self._ffplay_path:
                    raise RuntimeError(
                        "ffplay not found. Please install the audio tools from the Settings page."
                    )
                self._stop_ffplay()

                self._current_wav_path = str(cached_wav)
                self._duration_ms = self._get_duration_ffprobe(cached_wav)
                if self._duration_ms > 0:
                    self.duration_changed.emit(self._duration_ms)

                self._start_ffplay_at(0)
            else:
                url = QUrl.fromLocalFile(str(cached_wav))
                self.player.setMedia(QMediaContent(url))
                self.player.play()

        except Exception as e:
            self.error_occurred.emit(str(e))
            raise

    def play_url(self, url_str):
        self.current_file = None
        if _is_windows:
            if not self._ffplay_path:
                raise RuntimeError("ffplay not found. Please install the audio tools from the Settings page.")
            self._stop_ffplay()
            self._current_wav_path = url_str
            self._duration_ms = 0
            self._start_ffplay_at(0)
        else:
            self.player.setMedia(QMediaContent(QUrl(url_str)))
            self.player.play()

    def play(self):

        if _is_windows:
            if self._paused and self._current_wav_path and self._ffplay_path:
                self._start_ffplay_at(self._pause_elapsed_ms)
            elif self._state == "playing":
                return
            elif self._current_wav_path and self._ffplay_path:
                self._start_ffplay_at(0)
        else:
            self.player.play()

    def pause(self):

        if _is_windows:
            if self._ffplay_process and self._ffplay_process.poll() is None and not self._paused:
                elapsed = int((time.monotonic() - self._play_start_time) * 1000)
                self._pause_elapsed_ms += elapsed
                self._kill_ffplay_process()
                self._paused = True
                self._play_start_time = 0
                self._state = "paused"
                self.state_changed.emit("paused")
        else:
            self.player.pause()

    def stop(self):

        if _is_windows:
            self._stop_ffplay()
            self._state = "stopped"
            self.state_changed.emit("stopped")
            self.position_changed.emit(0)
        else:
            self.player.stop()

    def set_volume(self, volume):

        if _is_windows:
            self._volume = volume
            if self._state == "playing" and self._current_wav_path and self._ffplay_path:
                elapsed = self._pause_elapsed_ms + int((time.monotonic() - self._play_start_time) * 1000)
                self._start_ffplay_at(elapsed)
        else:
            self.player.setVolume(volume)

    def set_position(self, position):

        if _is_windows:
            if self._current_wav_path and self._ffplay_path:
                self._start_ffplay_at(position)
        else:
            self.player.setPosition(position)

    def get_state(self):

        if _is_windows:
            return self._state
        else:
            state_map = {
                QMediaPlayer.PlayingState: "playing",
                QMediaPlayer.PausedState: "paused",
                QMediaPlayer.StoppedState: "stopped"
            }
            return state_map.get(self.player.state(), "stopped")

    def _on_state_changed(self, state):

        state_map = {
            QMediaPlayer.PlayingState: "playing",
            QMediaPlayer.PausedState: "paused",
            QMediaPlayer.StoppedState: "stopped"
        }
        self.state_changed.emit(state_map.get(state, "stopped"))

    def _on_error(self, error):

        if error != QMediaPlayer.NoError:
            error_msg = self.player.errorString()
            self.error_occurred.emit(error_msg)

    def cleanup(self):

        self.stop()
        for temp_file in self.temp_files:
            if temp_file.exists():
                try:
                    temp_file.unlink()
                except:
                    pass
        self.temp_files.clear()
