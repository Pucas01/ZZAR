

import hashlib
import json
import os
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.fft import dct
from scipy.spatial.distance import pdist
from scipy.cluster.hierarchy import linkage, fcluster

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "src"))
sys.path.insert(0, str(PROJECT_ROOT))

from pck_indexer import PCKIndexer
from bnk_indexer import BNKIndexer
from sound_database import SoundDatabase

SAMPLE_RATE = 22050
N_FFT = 2048
HOP = 512
N_MELS = 40
N_MFCC = 13
FEATURE_DIM = 39
MIN_CLIP_DURATION = 0.5
MIN_VOICED_RATIO = 0.20
MIN_RMS_ENERGY = 0.005

VOICE_LANGUAGES = {"en": "En", "jp": "Jp", "cn": "Cn", "kr": "Kr"}
SPEAKER_PATTERN = re.compile(r"^Speaker \d+$")

_is_windows = platform.system() == "Windows"
_subprocess_kwargs = {}
if _is_windows:
    _si = subprocess.STARTUPINFO()
    _si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    _subprocess_kwargs["startupinfo"] = _si
    if hasattr(sys, "_MEIPASS"):
        _clean_env = os.environ.copy()
        _meipass = sys._MEIPASS
        _clean_env["PATH"] = os.pathsep.join(
            p for p in _clean_env.get("PATH", "").split(os.pathsep)
            if not p.startswith(_meipass)
        )
        _subprocess_kwargs["env"] = _clean_env

def _enable_ansi_windows():
    
    if not _is_windows:
        return
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except Exception:
        pass

def clear_screen():
    print("\033[2J\033[H", end="", flush=True)

def move_cursor(row, col):
    print(f"\033[{row};{col}H", end="", flush=True)

def hide_cursor():
    print("\033[?25l", end="", flush=True)

def show_cursor():
    print("\033[?25h", end="", flush=True)

class C:
    
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    CYAN = "\033[36m"
    RED = "\033[31m"
    MAGENTA = "\033[35m"
    WHITE = "\033[37m"
    BG_DARK = "\033[48;5;236m"

def colored(text, *codes):
    return "".join(codes) + str(text) + C.RESET

def read_key():
    
    if _is_windows:
        import msvcrt
        ch = msvcrt.getwch()
        if ch in ("\r", "\n"):
            return "enter"
        if ch == "\x1b":
            return "esc"
        if ch == "\t":
            return "tab"
        if ch == "\x00" or ch == "\xe0":
            ch2 = msvcrt.getwch()
            if ch2 == "H":
                return "up"
            if ch2 == "P":
                return "down"
            if ch2 == "K":
                return "left"
            if ch2 == "M":
                return "right"
            return "unknown"
        return ch
    else:
        import tty
        import termios
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
            if ch == "\r" or ch == "\n":
                return "enter"
            if ch == "\x1b":
                ch2 = sys.stdin.read(1)
                if ch2 == "[":
                    ch3 = sys.stdin.read(1)
                    if ch3 == "A":
                        return "up"
                    if ch3 == "B":
                        return "down"
                    if ch3 == "C":
                        return "right"
                    if ch3 == "D":
                        return "left"
                return "esc"
            if ch == "\t":
                return "tab"
            if ch == "\x03":
                raise KeyboardInterrupt
            return ch
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old)

def progress_bar(current, total, width=40, label=""):
    if total == 0:
        return ""
    pct = current / total
    filled = int(width * pct)
    bar = colored("█" * filled, C.GREEN) + colored("░" * (width - filled), C.DIM)
    pct_str = f"{pct * 100:5.1f}%"
    count_str = f"{current}/{total}"
    parts = [f"  {bar} {pct_str}  {count_str}"]
    if label:
        parts.append(f"  {label}")
    return "".join(parts)

def menu_select(title, options, allow_quit=True):
    
    selected = 0
    while True:
        clear_screen()
        print()
        print(colored(f"  {title}", C.BOLD, C.CYAN))
        print()
        for i, opt in enumerate(options):
            if i == selected:
                print(colored(f"  > {opt}", C.BOLD, C.GREEN))
            else:
                print(colored(f"    {opt}", C.DIM))
        print()
        if allow_quit:
            print(colored("  [q] Quit", C.DIM))
        print()

        key = read_key()
        if key == "up" and selected > 0:
            selected -= 1
        elif key == "down" and selected < len(options) - 1:
            selected += 1
        elif key == "enter":
            return selected
        elif key == "q" and allow_quit:
            return -1
        elif key == "esc" and allow_quit:
            return -1

def input_prompt(prompt_text, default=""):
    
    show_cursor()
    try:
        val = input(colored(f"  {prompt_text}", C.CYAN))
        return val.strip() or default
    except (EOFError, KeyboardInterrupt):
        return default
    finally:
        hide_cursor()

def _hz_to_mel(hz):
    return 2595.0 * np.log10(1.0 + hz / 700.0)

def _mel_to_hz(mel):
    return 700.0 * (10.0 ** (mel / 2595.0) - 1.0)

def _mel_filterbank(sample_rate, n_fft, n_mels=40):
    low_mel = _hz_to_mel(0)
    high_mel = _hz_to_mel(sample_rate / 2)
    mel_points = np.linspace(low_mel, high_mel, n_mels + 2)
    hz_points = _mel_to_hz(mel_points)
    bin_points = np.floor((n_fft + 1) * hz_points / sample_rate).astype(int)
    n_bins = n_fft // 2 + 1
    filterbank = np.zeros((n_mels, n_bins))
    for i in range(n_mels):
        left = bin_points[i]
        center = bin_points[i + 1]
        right = bin_points[i + 2]
        for j in range(left, center):
            if j < n_bins and center != left:
                filterbank[i, j] = (j - left) / (center - left)
        for j in range(center, right):
            if j < n_bins and right != center:
                filterbank[i, j] = (right - j) / (right - center)
    return filterbank

def find_ffmpeg():
    if _is_windows:
        for rel in [
            "tools/audio/ffmpeg/ffmpeg-master-latest-win64-gpl/bin/ffmpeg.exe",
            "tools/audio/ffmpeg/bin/ffmpeg.exe",
        ]:
            p = PROJECT_ROOT / rel
            if p.exists():
                return str(p.resolve())
    path = shutil.which("ffmpeg")
    if path:
        return path
    return None

def find_vgmstream():
    if _is_windows:
        p = PROJECT_ROOT / "tools/audio/vgmstream/vgmstream-cli.exe"
        if p.exists():
            return str(p.resolve())
    path = shutil.which("vgmstream-cli")
    return path

def wem_bytes_to_float32(wem_bytes, vgmstream_path, ffmpeg_path, max_duration=3.0):
    
    tmp_dir = tempfile.mkdtemp(prefix="zzar_sc_")
    tmp_wem = Path(tmp_dir) / "input.wem"
    tmp_wav = Path(tmp_dir) / "intermediate.wav"
    try:
        tmp_wem.write_bytes(wem_bytes)

        if vgmstream_path:
            try:
                subprocess.run(
                    [vgmstream_path, "-o", str(tmp_wav), str(tmp_wem)],
                    capture_output=True, check=True, timeout=10,
                    **_subprocess_kwargs,
                )
            except Exception:
                tmp_wav = tmp_wem
        else:
            tmp_wav = tmp_wem

        cmd = [
            ffmpeg_path,
            "-i", str(tmp_wav),
            "-ar", str(SAMPLE_RATE),
            "-ac", "1",
            "-f", "s16le",
            "-acodec", "pcm_s16le",
        ]
        if max_duration:
            cmd.extend(["-t", str(max_duration)])
        cmd.append("pipe:1")

        result = subprocess.run(
            cmd, capture_output=True, timeout=15, **_subprocess_kwargs,
        )
        if result.returncode != 0 or len(result.stdout) == 0:
            return None

        audio = np.frombuffer(result.stdout, dtype=np.int16).astype(np.float32) / 32768.0
        return audio

    except Exception:
        return None
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

def extract_mfcc(power_spec, sample_rate, n_fft, n_mfcc=13, n_mels=40):
    
    fb = _mel_filterbank(sample_rate, n_fft, n_mels)
    mel_spec = fb @ power_spec
    mel_spec = np.maximum(mel_spec, 1e-10)
    log_mel = np.log(mel_spec)
    mfcc = dct(log_mel, type=2, axis=0, norm="ortho")[:n_mfcc]
    return np.concatenate([mfcc.mean(axis=1), mfcc.std(axis=1)])

def estimate_f0(audio, sr, frame_len=2048, hop=512):
    
    f0_values = []
    for start in range(0, len(audio) - frame_len, hop):
        frame = audio[start : start + frame_len]
        rms = np.sqrt(np.mean(frame ** 2))
        if rms < 0.01:
            continue
        corr = np.correlate(frame, frame, mode="full")
        corr = corr[len(corr) // 2 :]
        min_lag = max(1, sr // 500)
        max_lag = min(len(corr) - 1, sr // 80)
        if max_lag <= min_lag:
            continue
        search = corr[min_lag : max_lag + 1]
        if len(search) == 0:
            continue
        peak_lag = np.argmax(search) + min_lag
        if corr[peak_lag] > 0.3 * corr[0]:
            f0_values.append(sr / peak_lag)

    if not f0_values:
        return np.array([0.0, 0.0, 0.0, 0.0]), 0.0

    f0 = np.array(f0_values)
    voiced_ratio = len(f0_values) / max(1, (len(audio) - frame_len) // hop)
    return np.array([f0.mean(), f0.std(), np.median(f0), f0.max() - f0.min()]), voiced_ratio

def compute_spectral_stats(freqs, power_spec):
    
    results = []

    total_power = power_spec.sum(axis=0) + 1e-10
    centroid = (freqs[:, None] * power_spec).sum(axis=0) / total_power
    results.extend([centroid.mean(), centroid.std()])

    cumsum = np.cumsum(power_spec, axis=0)
    threshold = 0.85 * total_power
    rolloff = np.zeros(power_spec.shape[1])
    for t in range(power_spec.shape[1]):
        idx = np.searchsorted(cumsum[:, t], threshold[t])
        rolloff[t] = freqs[min(idx, len(freqs) - 1)]
    results.extend([rolloff.mean(), rolloff.std()])

    geo_mean = np.exp(np.mean(np.log(power_spec + 1e-10), axis=0))
    arith_mean = np.mean(power_spec, axis=0) + 1e-10
    flatness = geo_mean / arith_mean
    results.extend([flatness.mean(), flatness.std()])

    return np.array(results)

def compute_ltas(freqs, power_spec):
    
    avg_power = power_spec.mean(axis=1)
    avg_power = np.maximum(avg_power, 1e-10)
    log_avg = np.log(avg_power)

    low_mask = freqs < 1000
    mid_mask = (freqs >= 1000) & (freqs < 4000)
    high_mask = freqs >= 4000

    low = log_avg[low_mask].mean() if low_mask.any() else 0.0
    mid = log_avg[mid_mask].mean() if mid_mask.any() else 0.0
    high = log_avg[high_mask].mean() if high_mask.any() else 0.0

    return np.array([low, mid, high])

def extract_speaker_features(audio, sr):
    
    freqs, times, Sxx = signal.spectrogram(
        audio, sr, nperseg=N_FFT, noverlap=N_FFT - HOP,
        window="hann", mode="magnitude",
    )
    power = Sxx ** 2

    mfcc = extract_mfcc(power, sr, N_FFT, N_MFCC, N_MELS)
    f0_stats, _ = estimate_f0(audio, sr)
    spectral = compute_spectral_stats(freqs, power)
    ltas = compute_ltas(freqs, power)

    return np.concatenate([mfcc, f0_stats, spectral, ltas])

def is_voice_clip(audio, sr):
    
    duration = len(audio) / sr
    if duration < MIN_CLIP_DURATION:
        return False

    rms = np.sqrt(np.mean(audio ** 2))
    if rms < MIN_RMS_ENERGY:
        return False

    _, voiced_ratio = estimate_f0(audio, sr)
    if voiced_ratio < MIN_VOICED_RATIO:
        return False

    return True

def find_audio_directory(game_dir, lang_code):
    
    lang_folder = VOICE_LANGUAGES.get(lang_code)
    if not lang_folder:
        return None

    game_path = Path(game_dir)

    candidates = [
        game_path / "StreamingAssets" / "Audio" / "Windows" / "Full" / lang_folder,
        game_path / "ZenlessZoneZero_Data" / "StreamingAssets" / "Audio" / "Windows" / "Full" / lang_folder,
        game_path / lang_folder,
        game_path,
    ]

    candidates.insert(2,
        game_path / "Persistent" / "Audio" / "Windows" / "Full" / lang_folder,
    )

    for candidate in candidates:
        if candidate.is_dir() and list(candidate.glob("SoundBank_*.pck")):
            return candidate

    return None

def scan_voice_clips(audio_dir):
    
    pck_files = sorted(Path(audio_dir).glob("SoundBank_*.pck"))

    for pck_file in pck_files:
        try:
            indexer = PCKIndexer(str(pck_file))
            indexer.build_index()
        except Exception:
            continue

        pck_name = pck_file.name

        for wem_info in indexer.index_data["sounds"] + indexer.index_data["externals"]:
            try:
                wem_bytes = indexer.extract_single_file(
                    wem_info["id"], "wem", wem_info.get("lang_id", 0)
                )
                yield wem_bytes, {
                    "wem_id": wem_info["id"],
                    "bnk_id": None,
                    "pck_file": pck_name,
                    "type": "wem",
                }
            except Exception:
                continue

        for bnk_info in indexer.index_data["banks"]:
            try:
                bnk_bytes = indexer.extract_single_file(
                    bnk_info["id"], "bnk", bnk_info.get("lang_id", 0)
                )
                bnk_indexer = BNKIndexer(bnk_bytes)
                wem_list = bnk_indexer.parse_didx()

                for wem_entry in wem_list:
                    try:
                        wem_bytes = bnk_indexer.extract_wem(wem_entry["wem_id"])
                        yield wem_bytes, {
                            "wem_id": wem_entry["wem_id"],
                            "bnk_id": bnk_info["id"],
                            "pck_file": pck_name,
                            "type": "wem_embedded",
                        }
                    except Exception:
                        continue
            except Exception:
                continue

class FeatureCache:

    def __init__(self, cache_dir):
        self.cache_dir = Path(cache_dir)
        self.features_path = self.cache_dir / "features.npy"
        self.metadata_path = self.cache_dir / "metadata.json"
        self.norm_path = self.cache_dir / "normalization.json"

        self.features = []
        self.metadata = []
        self.known_hashes = set()

    def load(self):
        
        if self.features_path.exists() and self.metadata_path.exists():
            self.features = list(np.load(self.features_path))
            with open(self.metadata_path, "r") as f:
                self.metadata = json.load(f)
            self.known_hashes = {m["hash"] for m in self.metadata}
            return True
        return False

    def has_hash(self, h):
        return h in self.known_hashes

    def add(self, feature_vec, meta_dict):
        self.features.append(feature_vec)
        self.metadata.append(meta_dict)
        self.known_hashes.add(meta_dict["hash"])

    def save(self):
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        if self.features:
            np.save(self.features_path, np.array(self.features, dtype=np.float32))
        with open(self.metadata_path, "w") as f:
            json.dump(self.metadata, f, indent=2)

    def get_feature_matrix(self):
        if not self.features:
            return None
        return np.array(self.features, dtype=np.float32)

def find_elbow_threshold(Z):
    
    merge_distances = Z[:, 2]
    if len(merge_distances) < 10:
        return 0.35

    diffs = np.diff(merge_distances)
    window = max(5, len(diffs) // 20)

    for i in range(window, len(diffs)):
        local_mean = diffs[max(0, i - window) : i].mean()
        local_std = diffs[max(0, i - window) : i].std()
        if diffs[i] > local_mean + 2.0 * local_std and local_std > 0:
            return merge_distances[i]

    return 0.35

def cluster_speakers(features, threshold=None, min_cluster_size=3):
    
    n = len(features)
    if n < 2:
        return [0] * n, 1

    mean = features.mean(axis=0)
    std = features.std(axis=0)
    std[std < 1e-8] = 1.0
    normed = (features - mean) / std

    distances = pdist(normed, metric="cosine")
    distances = np.nan_to_num(distances, nan=1.0)

    Z = linkage(distances, method="average")

    if threshold is None:
        threshold = find_elbow_threshold(Z)

    labels = fcluster(Z, t=threshold, criterion="distance")

    unique, counts = np.unique(labels, return_counts=True)
    size_map = dict(zip(unique, counts))

    final_labels = []
    for lbl in labels:
        if size_map[lbl] < min_cluster_size:
            final_labels.append(-1)
        else:
            final_labels.append(int(lbl))

    valid_labels = [l for l in final_labels if l != -1]
    if valid_labels:
        label_counts = {}
        for l in valid_labels:
            label_counts[l] = label_counts.get(l, 0) + 1
        sorted_labels = sorted(label_counts.keys(), key=lambda x: -label_counts[x])
        remap = {old: new + 1 for new, old in enumerate(sorted_labels)}
        final_labels = [remap.get(l, -1) for l in final_labels]
        n_speakers = len(sorted_labels)
    else:
        n_speakers = 0

    return final_labels, n_speakers

def build_cluster_output(labels, metadata, language, threshold):
    
    clusters = {}
    for label, meta in zip(labels, metadata):
        if label == -1:
            name = "Unclustered"
        else:
            name = f"Speaker {label}"
        clusters.setdefault(name, []).append(meta)

    sorted_names = sorted(clusters.keys(), key=lambda k: (-len(clusters[k]), k))

    output = {
        "_metadata": {
            "version": 1,
            "language": language,
            "total_clips": len(metadata),
            "total_speakers": sum(1 for n in sorted_names if n != "Unclustered"),
            "unclustered": len(clusters.get("Unclustered", [])),
            "threshold": round(float(threshold), 4),
            "created": datetime.now().isoformat(),
        }
    }

    for name in sorted_names:
        clips = clusters[name]
        output[name] = {
            "clip_count": len(clips),
            "clips": clips,
        }

    return output

def apply_clusters_to_db(clusters_data, audio_dir):
    
    db = SoundDatabase()
    applied_count = 0
    speaker_count = 0

    for speaker_name, group in clusters_data.items():
        if speaker_name == "_metadata":
            continue
        if speaker_name == "Unclustered":
            continue
        if SPEAKER_PATTERN.match(speaker_name):
            continue

        speaker_count += 1
        tag = speaker_name.lower()
        clips = group.get("clips", [])

        for clip in clips:
            try:

                pck_path = Path(audio_dir) / clip["pck_file"]
                if not pck_path.exists():
                    continue

                indexer = PCKIndexer(str(pck_path))
                indexer.build_index()

                wem_id = clip["wem_id"]
                bnk_id = clip.get("bnk_id")

                if bnk_id is not None:
                    bnk_bytes = indexer.extract_single_file(bnk_id, "bnk", 0)
                    bnk_indexer = BNKIndexer(bnk_bytes)
                    bnk_indexer.parse_didx()
                    wem_bytes = bnk_indexer.extract_wem(wem_id)
                else:
                    wem_bytes = indexer.extract_single_file(wem_id, "wem", 0)

                existing = db.get_sound_info(wem_bytes)
                if existing:
                    existing_tags = list(existing.get("tags", []))
                    if tag not in existing_tags:
                        existing_tags.append(tag)
                    db.add_sound(
                        wem_bytes,
                        name=existing.get("name", ""),
                        tags=existing_tags,
                        notes=existing.get("notes", ""),
                        file_id=wem_id,
                    )
                else:
                    db.add_sound(wem_bytes, name="", tags=[tag], notes="", file_id=wem_id)

                applied_count += 1

            except Exception:
                continue

    return speaker_count, applied_count

def screen_welcome(ffmpeg_ok, vgmstream_ok):
    clear_screen()
    print()
    print(colored("  ╔══════════════════════════════════════════╗", C.CYAN))
    print(colored("  ║     ZZAR Speaker Clustering Tool         ║", C.CYAN, C.BOLD))
    print(colored("  ╚══════════════════════════════════════════╝", C.CYAN))
    print()
    print(colored("  Identify voice characters in ZZZ audio banks", C.DIM))
    print()

    status_ok = colored("OK", C.GREEN, C.BOLD)
    status_missing = colored("MISSING", C.RED, C.BOLD)

    print(f"  ffmpeg:       {status_ok if ffmpeg_ok else status_missing}")
    print(f"  vgmstream:    {status_ok if vgmstream_ok else status_missing}")
    print()

    if not ffmpeg_ok:
        print(colored("  ffmpeg is required! Install it first.", C.RED))
        print()
        input_prompt("Press Enter to exit...")
        return False

    if not vgmstream_ok:
        print(colored("  Warning: vgmstream not found. Some WEM files may fail to decode.", C.YELLOW))
        print()

    return True

def screen_directory():
    clear_screen()
    print()
    print(colored("  Game Directory", C.BOLD, C.CYAN))
    print()
    print(colored("  Enter the path to your ZZZ game data folder.", C.DIM))
    print(colored("  (e.g. /path/to/ZenlessZoneZero_Data or the folder containing En/Jp/etc)", C.DIM))
    print()
    show_cursor()
    path = input(colored("  Path: ", C.CYAN))
    hide_cursor()
    return path.strip()

def screen_language(game_dir):
    
    available = []
    for code, folder_name in VOICE_LANGUAGES.items():
        audio_dir = find_audio_directory(game_dir, code)
        if audio_dir:
            pck_count = len(list(audio_dir.glob("SoundBank_*.pck")))
            available.append((code, folder_name, pck_count, str(audio_dir)))

    if not available:
        clear_screen()
        print()
        print(colored("  No voice folders found!", C.RED, C.BOLD))
        print(colored(f"  Searched in: {game_dir}", C.DIM))
        print()
        show_cursor()
        input("  Press Enter to go back...")
        hide_cursor()
        return None, None

    options = [f"{name} ({count} PCK files)" for _, name, count, _ in available]
    idx = menu_select("Select Language", options)
    if idx < 0:
        return None, None

    code, _, _, audio_dir = available[idx]
    return code, audio_dir

def screen_extract(audio_dir, cache_dir, ffmpeg_path, vgmstream_path):
    
    cache = FeatureCache(cache_dir)
    loaded_existing = cache.load()

    clear_screen()
    print()
    print(colored("  Feature Extraction", C.BOLD, C.CYAN))
    print()

    if loaded_existing:
        print(colored(f"  Found existing cache: {len(cache.metadata)} clips", C.GREEN))
        print(colored("  New clips will be added incrementally.", C.DIM))
    print()
    print(colored("  Scanning PCK files...", C.DIM))

    all_clips = list(scan_voice_clips(audio_dir))
    total = len(all_clips)

    print(f"  Found {colored(total, C.BOLD)} voice clips to process")
    print()

    processed = 0
    skipped_cached = 0
    skipped_filter = 0
    errors = 0
    new_clips = 0
    start_time = time.monotonic()

    for wem_bytes, meta in all_clips:
        wem_hash = hashlib.sha256(wem_bytes).hexdigest()

        if cache.has_hash(wem_hash):
            skipped_cached += 1
            processed += 1
            _print_extract_progress(processed, total, new_clips, skipped_filter, errors, start_time)
            continue

        try:
            audio = wem_bytes_to_float32(wem_bytes, vgmstream_path, ffmpeg_path, max_duration=3.0)
            if audio is None or len(audio) < int(SAMPLE_RATE * MIN_CLIP_DURATION):
                skipped_filter += 1
                processed += 1
                _print_extract_progress(processed, total, new_clips, skipped_filter, errors, start_time)
                continue

            if not is_voice_clip(audio, SAMPLE_RATE):
                skipped_filter += 1
                processed += 1
                _print_extract_progress(processed, total, new_clips, skipped_filter, errors, start_time)
                continue

            features = extract_speaker_features(audio, SAMPLE_RATE)
            meta["hash"] = wem_hash
            cache.add(features, meta)
            new_clips += 1

        except Exception:
            errors += 1

        processed += 1
        _print_extract_progress(processed, total, new_clips, skipped_filter, errors, start_time)

    cache.save()
    print()
    print()
    print(colored("  Extraction complete!", C.GREEN, C.BOLD))
    print(f"  Total cached:   {colored(len(cache.metadata), C.BOLD)}")
    print(f"  New this run:   {colored(new_clips, C.GREEN)}")
    print(f"  Already cached: {colored(skipped_cached, C.DIM)}")
    print(f"  Filtered out:   {colored(skipped_filter, C.DIM)}")
    print(f"  Errors:         {colored(errors, C.RED) if errors else colored(0, C.DIM)}")
    print()
    show_cursor()
    input("  Press Enter to continue...")
    hide_cursor()

    return cache

def _print_extract_progress(current, total, new_clips, filtered, errors, start_time):
    elapsed = time.monotonic() - start_time
    if current > 0 and elapsed > 0:
        rate = current / elapsed
        remaining = (total - current) / rate if rate > 0 else 0
        eta = _format_duration(remaining)
    else:
        eta = "..."

    bar = progress_bar(current, total, width=35)
    stats = f"  new:{colored(new_clips, C.GREEN)} skip:{filtered} err:{errors} ETA:{eta}"
    print(f"\r{bar}{stats}    ", end="", flush=True)

def _format_duration(seconds):
    if seconds < 60:
        return f"{int(seconds)}s"
    if seconds < 3600:
        return f"{int(seconds // 60)}m {int(seconds % 60)}s"
    return f"{int(seconds // 3600)}h {int((seconds % 3600) // 60)}m"

def screen_cluster(cache, min_cluster_size=3):
    
    clear_screen()
    print()
    print(colored("  Clustering Speakers", C.BOLD, C.CYAN))
    print()

    features = cache.get_feature_matrix()
    if features is None or len(features) < 2:
        print(colored("  Not enough clips to cluster (need at least 2).", C.RED))
        show_cursor()
        input("  Press Enter to go back...")
        hide_cursor()
        return None

    print(f"  Clustering {colored(len(features), C.BOLD)} voice clips...")
    print()

    labels, n_speakers = cluster_speakers(features, threshold=None, min_cluster_size=min_cluster_size)

    unclustered = sum(1 for l in labels if l == -1)
    print(colored(f"  Found {n_speakers} speaker groups", C.GREEN, C.BOLD))
    print(colored(f"  Unclustered clips: {unclustered}", C.DIM))
    print()
    show_cursor()
    input("  Press Enter to continue...")
    hide_cursor()

    return labels

def screen_rename(clusters_data):
    
    speaker_names = [k for k in clusters_data if k not in ("_metadata", "Unclustered")]
    if not speaker_names:
        return clusters_data

    renames = {}
    selected = 0
    page_size = 15
    scroll_offset = 0

    while True:
        clear_screen()
        print()
        print(colored("  Speaker Renaming", C.BOLD, C.CYAN))
        print(colored("  Arrow keys to navigate, Enter to rename, 'd' when done", C.DIM))
        print()

        renamed_count = sum(1 for n in renames.values() if n and not SPEAKER_PATTERN.match(n))
        total_speakers = len(speaker_names)
        print(f"  {colored(renamed_count, C.GREEN)}/{total_speakers} speakers named")
        print()

        visible_start = scroll_offset
        visible_end = min(scroll_offset + page_size, len(speaker_names))

        if selected < scroll_offset:
            scroll_offset = selected
            visible_start = scroll_offset
            visible_end = min(scroll_offset + page_size, len(speaker_names))
        elif selected >= visible_end:
            scroll_offset = selected - page_size + 1
            visible_start = scroll_offset
            visible_end = min(scroll_offset + page_size, len(speaker_names))

        for i in range(visible_start, visible_end):
            name = speaker_names[i]
            display_name = renames.get(name, name)
            clip_count = clusters_data[name]["clip_count"]
            is_renamed = name in renames and not SPEAKER_PATTERN.match(renames[name])

            prefix = "  > " if i == selected else "    "
            count_str = colored(f"({clip_count} clips)", C.DIM)

            if is_renamed:
                badge = colored(" (renamed)", C.GREEN)
                name_display = colored(display_name, C.GREEN, C.BOLD)
                orig = colored(f" [{name}]", C.DIM)
                line = f"{prefix}{name_display} {count_str}{badge}{orig}"
            elif i == selected:
                line = f"{prefix}{colored(display_name, C.BOLD, C.WHITE)} {count_str}"
            else:
                line = f"{prefix}{colored(display_name, C.DIM)} {count_str}"

            print(line)

        if len(speaker_names) > page_size:
            print()
            print(colored(f"  Showing {visible_start + 1}-{visible_end} of {len(speaker_names)}", C.DIM))

        unc = clusters_data.get("Unclustered", {}).get("clip_count", 0)
        if unc > 0:
            print()
            print(colored(f"  + {unc} unclustered clips (not shown)", C.DIM))

        print()
        print(colored("  [Enter] Rename  [d] Done  [q] Quit without applying", C.DIM))

        key = read_key()

        if key == "up" and selected > 0:
            selected -= 1
        elif key == "down" and selected < len(speaker_names) - 1:
            selected += 1
        elif key == "enter":
            name = speaker_names[i] if i == selected else speaker_names[selected]
            current = renames.get(name, "")
            show_cursor()
            print()
            new_name = input(colored(f"  Name for {name}: ", C.CYAN))
            hide_cursor()
            new_name = new_name.strip()
            if new_name:
                renames[name] = new_name
        elif key == "d":
            break
        elif key == "q" or key == "esc":
            return None

    new_data = {"_metadata": clusters_data["_metadata"]}
    for old_name, group in clusters_data.items():
        if old_name == "_metadata":
            continue
        new_name = renames.get(old_name, old_name)
        new_data[new_name] = group
    return new_data

def screen_apply(clusters_data, audio_dir):
    
    renamed = {
        k: v for k, v in clusters_data.items()
        if k not in ("_metadata", "Unclustered") and not SPEAKER_PATTERN.match(k)
    }

    clear_screen()
    print()
    print(colored("  Apply Speaker Tags", C.BOLD, C.CYAN))
    print()

    if not renamed:
        print(colored("  No speakers have been renamed. Nothing to apply.", C.YELLOW))
        print()
        show_cursor()
        input("  Press Enter to go back...")
        hide_cursor()
        return

    total_clips = sum(g["clip_count"] for g in renamed.values())
    print(f"  Will tag {colored(len(renamed), C.GREEN, C.BOLD)} speakers ({total_clips} clips total):")
    print()
    for name, group in renamed.items():
        print(f"    {colored(name, C.GREEN)}  ({group['clip_count']} clips)")
    print()

    choice = menu_select("Proceed?", ["Apply tags to database", "Cancel"], allow_quit=False)
    if choice != 0:
        return

    clear_screen()
    print()
    print(colored("  Applying tags...", C.CYAN))
    print()

    speaker_count, clip_count = apply_clusters_to_db(clusters_data, audio_dir)

    print()
    print(colored("  Done!", C.GREEN, C.BOLD))
    print(f"  Speakers tagged: {colored(speaker_count, C.GREEN)}")
    print(f"  Clips updated:   {colored(clip_count, C.GREEN)}")
    print()
    show_cursor()
    input("  Press Enter to finish...")
    hide_cursor()

def main():
    _enable_ansi_windows()
    hide_cursor()

    try:
        ffmpeg_path = find_ffmpeg()
        vgmstream_path = find_vgmstream()

        if not screen_welcome(ffmpeg_path is not None, vgmstream_path is not None):
            return

        while True:
            game_dir = screen_directory()
            if not game_dir:
                continue
            if not Path(game_dir).is_dir():
                clear_screen()
                print()
                print(colored(f"  Directory not found: {game_dir}", C.RED))
                print()
                show_cursor()
                input("  Press Enter to try again...")
                hide_cursor()
                continue
            break

        lang_code, audio_dir = screen_language(game_dir)
        if not lang_code:
            return

        cache_dir = Path(audio_dir).parent / f"speaker_cache_{lang_code}"

        while True:
            actions = ["Extract & Cluster", "Load cached + Re-cluster", "Quit"]
            if (cache_dir / "features.npy").exists():
                actions[0] = "Extract & Cluster (will update cache)"

            choice = menu_select(
                f"Speaker Clustering — {VOICE_LANGUAGES[lang_code]} ({audio_dir})",
                actions,
                allow_quit=False,
            )

            if choice == 2:
                return

            if choice == 0:
                cache = screen_extract(audio_dir, cache_dir, ffmpeg_path, vgmstream_path)
            elif choice == 1:
                cache = FeatureCache(cache_dir)
                if not cache.load():
                    clear_screen()
                    print()
                    print(colored("  No cache found. Run extraction first.", C.RED))
                    print()
                    show_cursor()
                    input("  Press Enter...")
                    hide_cursor()
                    continue

            if not cache.metadata:
                clear_screen()
                print()
                print(colored("  No voice clips found or cached.", C.RED))
                print()
                show_cursor()
                input("  Press Enter...")
                hide_cursor()
                continue

            labels = screen_cluster(cache)
            if labels is None:
                continue

            clusters_data = build_cluster_output(
                labels, cache.metadata, lang_code,
                threshold=0.35,
            )

            json_path = cache_dir / "speaker_clusters.json"
            with open(json_path, "w") as f:
                json.dump(clusters_data, f, indent=2)

            clusters_data = screen_rename(clusters_data)
            if clusters_data is None:
                continue

            with open(json_path, "w") as f:
                json.dump(clusters_data, f, indent=2)

            screen_apply(clusters_data, audio_dir)
            break

    except KeyboardInterrupt:
        pass
    finally:
        show_cursor()
        print()

if __name__ == "__main__":
    main()
