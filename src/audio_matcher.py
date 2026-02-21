

import numpy as np
from pathlib import Path
from scipy import signal
from scipy.fft import fft
import subprocess
import tempfile
from multiprocessing import Pool, cpu_count
from functools import partial

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
                    timeout=10
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
            subprocess.run(cmd, capture_output=True, check=True, timeout=15)
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
        temp_wav.unlink()

        if intermediate_wav and intermediate_wav.exists():
            try:
                intermediate_wav.unlink()
            except:
                pass

        if audio_data is None or len(audio_data) == 0:
            return None

        fingerprint = {
            'mfcc': self._extract_mfcc(audio_data, sample_rate),
            'spectral_centroid': self._spectral_centroid(audio_data, sample_rate),
            'energy': self._energy_profile(audio_data),
            'chroma': self._extract_chroma(audio_data, sample_rate),
            'spectral_contrast': self._spectral_contrast(audio_data, sample_rate),
            'zero_crossing_rate': self._zero_crossing_rate(audio_data),
            'tempo': self._estimate_tempo(audio_data, sample_rate),
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
            ], capture_output=True, check=True)

            audio_data = np.frombuffer(result.stdout, dtype=np.int16)

            audio_data = audio_data.astype(np.float32) / 32768.0

            return audio_data
        except:
            return None

    def _extract_mfcc(self, audio_data, sample_rate, n_mfcc=13):


        f, t, Sxx = signal.spectrogram(audio_data, sample_rate, nperseg=2048)

        Sxx_log = np.log10(Sxx + 1e-10)

        mfcc = np.mean(Sxx_log, axis=1)[:n_mfcc]

        return mfcc

    def _spectral_centroid(self, audio_data, sample_rate):

        f, t, Sxx = signal.spectrogram(audio_data, sample_rate, nperseg=2048)

        centroid = np.sum(f[:, np.newaxis] * Sxx, axis=0) / (np.sum(Sxx, axis=0) + 1e-10)

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

    def _extract_chroma(self, audio_data, sample_rate):


        f, t, Sxx = signal.spectrogram(audio_data, sample_rate, nperseg=4096)

        chroma = np.zeros(12)
        for i, freq in enumerate(f):

            if 40.0 <= freq <= 4000.0:
                try:

                    pitch_class = int(12 * np.log2(freq / 440.0)) % 12
                    chroma[pitch_class] += np.mean(Sxx[i, :])
                except (ValueError, OverflowError):

                    continue

        chroma = chroma / (np.sum(chroma) + 1e-10)

        return chroma.tolist()

    def _spectral_contrast(self, audio_data, sample_rate):

        f, t, Sxx = signal.spectrogram(audio_data, sample_rate, nperseg=2048)

        n_bands = 6
        band_size = len(f) // n_bands
        contrasts = []

        for i in range(n_bands):
            band_start = i * band_size
            band_end = (i + 1) * band_size
            band_power = Sxx[band_start:band_end, :]

            peak = np.percentile(band_power, 90, axis=0)
            valley = np.percentile(band_power, 10, axis=0)
            contrast = np.mean(peak - valley)
            contrasts.append(float(contrast))

        return contrasts

    def _zero_crossing_rate(self, audio_data):

        zero_crossings = np.sum(np.abs(np.diff(np.sign(audio_data)))) / 2
        zcr = zero_crossings / len(audio_data)
        return float(zcr)

    def _estimate_tempo(self, audio_data, sample_rate):


        chunk_size = 512
        hop_length = 256
        envelope = []

        for i in range(0, len(audio_data) - chunk_size, hop_length):
            chunk = audio_data[i:i+chunk_size]
            envelope.append(np.sum(np.abs(chunk)))

        envelope = np.array(envelope)

        if len(envelope) > 0:
            autocorr = np.correlate(envelope, envelope, mode='full')
            autocorr = autocorr[len(autocorr)//2:]

            if len(autocorr) > 10:
                peaks = []
                for i in range(1, min(len(autocorr)-1, 200)):
                    if autocorr[i] > autocorr[i-1] and autocorr[i] > autocorr[i+1]:
                        peaks.append((i, autocorr[i]))

                if peaks and sample_rate > 0:

                    dominant_peak = max(peaks, key=lambda x: x[1])
                    peak_time = dominant_peak[0] * hop_length / sample_rate
                    if peak_time > 0:
                        tempo = 60.0 / peak_time

                        if 20 <= tempo <= 300:
                            return float(tempo)

        return 0.0

    def compare_fingerprints(self, fp1, fp2, debug=False):

        if fp1 is None or fp2 is None:
            return 0.0

        scores = []
        penalties = []

        mfcc_dist = np.linalg.norm(np.array(fp1['mfcc']) - np.array(fp2['mfcc']))

        mfcc_score = 100 * np.exp(-mfcc_dist / 5.0)
        scores.append(('mfcc', mfcc_score, 0.25))

        chroma_dist = np.linalg.norm(np.array(fp1['chroma']) - np.array(fp2['chroma']))

        chroma_score = 100 * np.exp(-chroma_dist / 0.3)
        scores.append(('chroma', chroma_score, 0.30))

        contrast_dist = np.linalg.norm(
            np.array(fp1['spectral_contrast']) - np.array(fp2['spectral_contrast'])
        )

        contrast_score = 100 * np.exp(-contrast_dist / 50.0)
        scores.append(('contrast', contrast_score, 0.20))

        centroid_diff = abs(fp1['spectral_centroid']['mean'] - fp2['spectral_centroid']['mean'])
        centroid_std_diff = abs(fp1['spectral_centroid']['std'] - fp2['spectral_centroid']['std'])

        centroid_score = 100 * np.exp(-(centroid_diff / 2000.0 + centroid_std_diff / 1000.0))
        scores.append(('centroid', centroid_score, 0.15))

        energy_mean_diff = abs(fp1['energy']['mean'] - fp2['energy']['mean'])
        energy_std_diff = abs(fp1['energy']['std'] - fp2['energy']['std'])
        energy_score = 100 * np.exp(-(energy_mean_diff / 0.5 + energy_std_diff / 0.5))
        scores.append(('energy', energy_score, 0.10))

        duration_ratio = min(fp1['duration'], fp2['duration']) / max(fp1['duration'], fp2['duration'])
        if duration_ratio < 0.5:

            penalties.append(('duration', 0.5))
        elif duration_ratio < 0.7:
            penalties.append(('duration', 0.8))

        total_score = sum(score * weight for _, score, weight in scores)

        for penalty_name, penalty_factor in penalties:
            total_score *= penalty_factor

        all_low = all(score < 30 for _, score, _ in scores)
        if all_low:
            total_score *= 0.5

        if debug:
            print(f"  MFCC dist: {mfcc_dist:.2f} -> score: {mfcc_score:.1f}%")
            print(f"  Chroma dist: {chroma_dist:.4f} -> score: {chroma_score:.1f}%")
            print(f"  Contrast dist: {contrast_dist:.4f} -> score: {contrast_score:.1f}%")
            print(f"  Centroid diff: {centroid_diff:.2f} -> score: {centroid_score:.1f}%")
            print(f"  Energy diff: {energy_mean_diff:.4f} -> score: {energy_score:.1f}%")
            print(f"  Duration ratio: {duration_ratio:.2f}")
            if penalties:
                print(f"  Penalties: {penalties}")
            print(f"  Total: {total_score:.1f}%")

        return total_score

    def find_matches(self, recording_path, candidate_files, top_n=10, progress_callback=None, num_threads=None):


        recording_fp = self.extract_fingerprint(recording_path, duration=30)

        if recording_fp is None:
            raise Exception("Failed to process recording")

        if num_threads is None:
            num_threads = max(1, cpu_count() - 1)

        total = len(candidate_files)
        matches = []

        batch_size = max(1, total // (num_threads * 4))

        if num_threads == 1 or total < 10:

            for idx, (file_path, file_info) in enumerate(candidate_files):
                if progress_callback:
                    progress_callback(idx + 1, total, file_info.get('id', 'unknown'))

                result = self._process_candidate(file_path, file_info, recording_fp)
                if result:
                    matches.append(result)
        else:

            processed = 0

            worker_func = partial(self._process_candidate_worker, recording_fp=recording_fp)

            with Pool(processes=num_threads) as pool:
                for i in range(0, total, batch_size):
                    batch = candidate_files[i:i+batch_size]

                    batch_results = pool.map(worker_func, batch)

                    for result in batch_results:
                        if result:
                            matches.append(result)

                    processed += len(batch)
                    if progress_callback:
                        progress_callback(
                            min(processed, total),
                            total,
                            f"batch {i//batch_size + 1}"
                        )

        matches.sort(key=lambda x: x[0], reverse=True)

        return matches[:top_n]

    def _process_candidate(self, file_path, file_info, recording_fp, debug_first_n=3):

        try:
            candidate_fp = self.extract_fingerprint(file_path, duration=30)
            if candidate_fp is None:
                print(f"Failed to extract fingerprint for {file_info.get('id', 'unknown')}")
                return None

            file_id = file_info.get('id', '')
            try:
                debug = len(str(file_id)) > 0 and int(str(file_id)[-1]) < debug_first_n
            except (ValueError, TypeError):
                debug = False

            if debug:
                print(f"\n=== Comparing ID {file_info.get('id', 'unknown')} ===")

            score = self.compare_fingerprints(recording_fp, candidate_fp, debug=debug)
            return (score, file_info)
        except Exception as e:
            print(f"Error processing {file_info.get('id', 'unknown')}: {e}")
            return None

    @staticmethod
    def _process_candidate_worker(candidate_tuple, recording_fp):

        file_path, file_info = candidate_tuple
        try:

            matcher = AudioMatcher()
            candidate_fp = matcher.extract_fingerprint(file_path, duration=30)
            if candidate_fp is None:
                print(f"Worker: Failed to extract fingerprint for {file_info.get('id', 'unknown')}")
                return None
            score = matcher.compare_fingerprints(recording_fp, candidate_fp)
            return (score, file_info)
        except Exception as e:
            print(f"Worker: Error processing {file_info.get('id', 'unknown')}: {e}")
            import traceback
            traceback.print_exc()
            return None
