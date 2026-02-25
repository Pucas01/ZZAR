

import os
import sys
import numpy as np
import platform
from pathlib import Path
from scipy import signal
from scipy.fft import dct
import subprocess
import tempfile

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


class AudioMatcher:

    def __init__(self, ffmpeg_path='ffmpeg'):
        self.ffmpeg_path = ffmpeg_path

    def extract_fingerprint(self, audio_path, sample_rate=22050, duration=None):

        audio_path = Path(audio_path)

        intermediate_wav = None
        if audio_path.suffix.lower() == '.wem':

            from ZZAR import get_temp_dir
            with tempfile.NamedTemporaryFile(suffix='_intermediate.wav', delete=False, dir=str(get_temp_dir())) as tmp:
                intermediate_wav = Path(tmp.name)

            try:
                subprocess.run(
                    ['vgmstream-cli', '-o', str(intermediate_wav), str(audio_path)],
                    capture_output=True,
                    check=True,
                    timeout=10,
                    **_subprocess_kwargs
                )
                input_file = intermediate_wav
            except:

                input_file = audio_path
        else:
            input_file = audio_path

        from ZZAR import get_temp_dir
        temp_wav = Path(tempfile.mktemp(suffix='.wav', dir=str(get_temp_dir())))

        cmd = [
            self.ffmpeg_path,
            '-i', str(input_file),
            '-ar', str(sample_rate),
            '-ac', '1',
            '-acodec', 'pcm_s16le',
        ]

        if duration:
            cmd.extend(['-t', str(duration)])

        cmd.extend(['-y', str(temp_wav)])

        try:
            subprocess.run(cmd, capture_output=True, check=True, timeout=15, **_subprocess_kwargs)
        except subprocess.CalledProcessError as e:

            if intermediate_wav and intermediate_wav.exists():
                try:
                    intermediate_wav.unlink()
                except:
                    pass
            raise Exception(f"Failed to process audio: {e.stderr.decode()}")
        except subprocess.TimeoutExpired:

            if intermediate_wav and intermediate_wav.exists():
                try:
                    intermediate_wav.unlink()
                except:
                    pass
            raise Exception(f"Audio processing timed out")

        audio_data = self._read_wav(temp_wav, sample_rate)
        temp_wav.unlink(missing_ok=True)

        if intermediate_wav and intermediate_wav.exists():
            try:
                intermediate_wav.unlink()
            except:
                pass

        if audio_data is None or len(audio_data) == 0:
            return None

        return self._build_fingerprint(audio_data, sample_rate)

    def extract_fingerprint_from_bytes(self, wem_bytes, sample_rate=22050, duration=None):

        from ZZAR import get_temp_dir
        temp_wem = Path(tempfile.mktemp(suffix='.wem', dir=str(get_temp_dir())))
        try:
            temp_wem.write_bytes(wem_bytes)
            return self.extract_fingerprint(temp_wem, sample_rate, duration)
        finally:
            temp_wem.unlink(missing_ok=True)

    def _build_fingerprint(self, audio_data, sample_rate):

        n_fft = 2048
        hop = 512
        f, t, Sxx = signal.spectrogram(
            audio_data, sample_rate, nperseg=n_fft, noverlap=n_fft - hop,
            window='hann', mode='magnitude'
        )

        power = Sxx ** 2

        fingerprint = {
            'mfcc': self._extract_mfcc(power, sample_rate, n_fft),
            'spectral_centroid': self._spectral_centroid(f, power),
            'energy': self._energy_profile(audio_data),
            'chroma': self._extract_chroma(f, power),
            'spectral_contrast': self._spectral_contrast(power, n_bands=6),
            'zero_crossing_rate': self._zero_crossing_rate(audio_data),
            'spectral_rolloff': self._spectral_rolloff(f, power),
            'spectral_flatness': self._spectral_flatness(power),
            'onset_strength': self._onset_strength(power),
            'duration': len(audio_data) / sample_rate,
            'sample_rate': sample_rate
        }

        return fingerprint

    def _read_wav(self, wav_path, expected_sample_rate):

        try:

            result = subprocess.run([
                self.ffmpeg_path,
                '-i', str(wav_path),
                '-f', 's16le',
                '-acodec', 'pcm_s16le',
                '-'
            ], capture_output=True, check=True, **_subprocess_kwargs)

            audio_data = np.frombuffer(result.stdout, dtype=np.int16)

            audio_data = audio_data.astype(np.float32) / 32768.0

            return audio_data
        except:
            return None

    def _extract_mfcc(self, power_spectrogram, sample_rate, n_fft, n_mfcc=13, n_mels=40):

        filterbank = _mel_filterbank(sample_rate, n_fft, n_mels)

        mel_spec = filterbank @ power_spectrogram
        mel_spec = np.log(mel_spec + 1e-10)

        mfcc = dct(mel_spec, type=2, axis=0, norm='ortho')[:n_mfcc, :]

        mfcc_mean = np.mean(mfcc, axis=1)
        mfcc_std = np.std(mfcc, axis=1)

        return {'mean': mfcc_mean.tolist(), 'std': mfcc_std.tolist()}

    def _spectral_centroid(self, f, power_spectrogram):

        centroid = np.sum(f[:, np.newaxis] * power_spectrogram, axis=0) / (np.sum(power_spectrogram, axis=0) + 1e-10)

        return {
            'mean': float(np.mean(centroid)),
            'std': float(np.std(centroid))
        }

    def _energy_profile(self, audio_data):

        chunk_size = 2048
        chunks = [audio_data[i:i+chunk_size] for i in range(0, len(audio_data), chunk_size)]
        energy = [np.sqrt(np.mean(chunk**2)) for chunk in chunks if len(chunk) > 0]

        return {
            'mean': float(np.mean(energy)),
            'std': float(np.std(energy)),
            'max': float(np.max(energy))
        }

    def _extract_chroma(self, f, power_spectrogram):

        chroma = np.zeros(12)
        for i, freq in enumerate(f):
            if 40.0 <= freq <= 4000.0:
                try:
                    pitch_class = int(12 * np.log2(freq / 440.0)) % 12
                    chroma[pitch_class] += np.mean(power_spectrogram[i, :])
                except (ValueError, OverflowError):
                    continue

        total = np.sum(chroma)
        if total > 0:
            chroma = chroma / total

        return chroma.tolist()

    def _spectral_contrast(self, power_spectrogram, n_bands=6):

        n_freq = power_spectrogram.shape[0]
        band_size = max(1, n_freq // n_bands)
        contrasts = []

        for i in range(n_bands):
            band_start = i * band_size
            band_end = min((i + 1) * band_size, n_freq)
            band_power = power_spectrogram[band_start:band_end, :]

            if band_power.size == 0:
                contrasts.append(0.0)
                continue

            peak = np.percentile(band_power, 90, axis=0)
            valley = np.percentile(band_power, 10, axis=0)
            contrast = np.mean(np.log10(peak + 1e-10) - np.log10(valley + 1e-10))
            contrasts.append(float(contrast))

        return contrasts

    def _zero_crossing_rate(self, audio_data):

        zero_crossings = np.sum(np.abs(np.diff(np.sign(audio_data)))) / 2
        zcr = zero_crossings / len(audio_data)
        return float(zcr)

    def _spectral_rolloff(self, f, power_spectrogram, rolloff_percent=0.85):

        total_energy = np.sum(power_spectrogram, axis=0)
        cumulative = np.cumsum(power_spectrogram, axis=0)
        threshold = rolloff_percent * total_energy

        rolloff_idx = np.argmax(cumulative >= threshold[np.newaxis, :], axis=0)
        rolloff_freq = f[np.clip(rolloff_idx, 0, len(f) - 1)]

        return {
            'mean': float(np.mean(rolloff_freq)),
            'std': float(np.std(rolloff_freq))
        }

    def _spectral_flatness(self, power_spectrogram):

        geo_mean = np.exp(np.mean(np.log(power_spectrogram + 1e-10), axis=0))
        arith_mean = np.mean(power_spectrogram, axis=0) + 1e-10
        flatness = geo_mean / arith_mean

        return {
            'mean': float(np.mean(flatness)),
            'std': float(np.std(flatness))
        }

    def _onset_strength(self, power_spectrogram):

        log_spec = np.log(power_spectrogram + 1e-10)

        diff = np.diff(log_spec, axis=1)
        diff = np.maximum(0, diff)

        onset = np.mean(diff, axis=0)

        if len(onset) == 0:
            return {'mean': 0.0, 'std': 0.0, 'max': 0.0}

        return {
            'mean': float(np.mean(onset)),
            'std': float(np.std(onset)),
            'max': float(np.max(onset))
        }

    def compare_fingerprints(self, fp1, fp2):

        if fp1 is None or fp2 is None:
            return 0.0

        scores = []

        # MFCC — strongest feature for timbral similarity
        mfcc1 = np.array(fp1['mfcc']['mean'])
        mfcc2 = np.array(fp2['mfcc']['mean'])
        mfcc_cos = self._cosine_similarity(mfcc1, mfcc2)
        mfcc_std1 = np.array(fp1['mfcc']['std'])
        mfcc_std2 = np.array(fp2['mfcc']['std'])
        mfcc_std_cos = self._cosine_similarity(mfcc_std1, mfcc_std2)
        mfcc_score = 100 * (0.7 * max(0, mfcc_cos) + 0.3 * max(0, mfcc_std_cos))
        scores.append(('mfcc', mfcc_score, 0.30))

        # Chroma — pitch class distribution
        chroma1 = np.array(fp1['chroma'])
        chroma2 = np.array(fp2['chroma'])
        chroma_cos = self._cosine_similarity(chroma1, chroma2)
        chroma_score = 100 * max(0, chroma_cos)
        scores.append(('chroma', chroma_score, 0.15))

        # Spectral contrast — tonal vs flat character
        contrast1 = np.array(fp1['spectral_contrast'])
        contrast2 = np.array(fp2['spectral_contrast'])
        contrast_cos = self._cosine_similarity(contrast1, contrast2)
        contrast_score = 100 * max(0, contrast_cos)
        scores.append(('contrast', contrast_score, 0.10))

        # Spectral centroid — brightness
        centroid_diff = abs(fp1['spectral_centroid']['mean'] - fp2['spectral_centroid']['mean'])
        max_centroid = max(fp1['spectral_centroid']['mean'], fp2['spectral_centroid']['mean'], 1.0)
        centroid_score = 100 * np.exp(-centroid_diff / (max_centroid * 0.3))
        scores.append(('centroid', centroid_score, 0.10))

        # Energy profile
        energy_mean_diff = abs(fp1['energy']['mean'] - fp2['energy']['mean'])
        max_energy = max(fp1['energy']['mean'], fp2['energy']['mean'], 0.001)
        energy_score = 100 * np.exp(-energy_mean_diff / (max_energy * 0.5))
        scores.append(('energy', energy_score, 0.05))

        # Zero crossing rate — noisy vs tonal
        zcr_diff = abs(fp1['zero_crossing_rate'] - fp2['zero_crossing_rate'])
        max_zcr = max(fp1['zero_crossing_rate'], fp2['zero_crossing_rate'], 0.001)
        zcr_score = 100 * np.exp(-zcr_diff / (max_zcr * 0.5))
        scores.append(('zcr', zcr_score, 0.05))

        # Spectral rolloff — brightness distribution
        rolloff_diff = abs(fp1['spectral_rolloff']['mean'] - fp2['spectral_rolloff']['mean'])
        max_rolloff = max(fp1['spectral_rolloff']['mean'], fp2['spectral_rolloff']['mean'], 1.0)
        rolloff_score = 100 * np.exp(-rolloff_diff / (max_rolloff * 0.3))
        scores.append(('rolloff', rolloff_score, 0.10))

        # Spectral flatness — noise vs tone
        flatness_diff = abs(fp1['spectral_flatness']['mean'] - fp2['spectral_flatness']['mean'])
        flatness_score = 100 * np.exp(-flatness_diff / 0.15)
        scores.append(('flatness', flatness_score, 0.05))

        # Onset strength — rhythmic character
        onset1 = fp1.get('onset_strength', {'mean': 0, 'std': 0})
        onset2 = fp2.get('onset_strength', {'mean': 0, 'std': 0})
        onset_mean_diff = abs(onset1['mean'] - onset2['mean'])
        max_onset = max(onset1['mean'], onset2['mean'], 0.001)
        onset_score = 100 * np.exp(-onset_mean_diff / (max_onset * 0.5))
        scores.append(('onset', onset_score, 0.10))

        # Weighted total
        total_score = sum(score * weight for _, score, weight in scores)

        # Duration penalty — applied as a soft multiplier
        dur1 = fp1['duration']
        dur2 = fp2['duration']
        if max(dur1, dur2) > 0:
            duration_ratio = min(dur1, dur2) / max(dur1, dur2)
        else:
            duration_ratio = 1.0

        if duration_ratio < 0.3:
            total_score *= 0.4
        elif duration_ratio < 0.5:
            total_score *= 0.6
        elif duration_ratio < 0.7:
            total_score *= 0.85

        return total_score

    @staticmethod
    def _cosine_similarity(a, b):
        norm_a = np.linalg.norm(a)
        norm_b = np.linalg.norm(b)
        if norm_a < 1e-10 or norm_b < 1e-10:
            return 0.0
        return float(np.dot(a, b) / (norm_a * norm_b))

    def find_matches(self, recording_fp, candidate_files, top_n=10, progress_callback=None, cancel_event=None):

        total = len(candidate_files)
        matches = []

        for idx, (wem_bytes, file_info) in enumerate(candidate_files):
            if cancel_event and cancel_event.is_set():
                break

            if progress_callback:
                progress_callback(idx + 1, total)

            try:
                candidate_fp = self.extract_fingerprint_from_bytes(wem_bytes, duration=30)
                if candidate_fp is None:
                    continue

                score = self.compare_fingerprints(recording_fp, candidate_fp)
                matches.append((score, file_info))
            except Exception as e:
                print(f"[AudioMatcher] Error processing {file_info.get('id', '?')}: {e}")

        matches.sort(key=lambda x: x[0], reverse=True)

        return matches[:top_n]
