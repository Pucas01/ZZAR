

import sys
from pathlib import Path
from PyQt5.QtCore import QObject, pyqtSignal, pyqtSlot, QThread

project_root = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(project_root))
sys.path.insert(0, str(project_root / "src"))

from src.audio_converter import AudioConverter

class ConversionWorker(QThread):


    progress = pyqtSignal(str)
    finished = pyqtSignal(bool, str)

    def __init__(self, mode, input_path, output_path, sample_rate, normalize=True):
        super().__init__()
        self.mode = mode
        self.input_path = input_path
        self.output_path = output_path
        self.sample_rate = sample_rate
        self.normalize = normalize
        self.converter = None

    def run(self):

        try:
            self.converter = AudioConverter()
            input_p = Path(self.input_path)
            output_p = Path(self.output_path) if self.output_path else None

            if self.mode == 0:

                if input_p.is_dir():
                    self.progress.emit("Converting WEM files in directory...")
                    result = self.converter.batch_convert_wem_to_wav(
                        str(input_p), str(output_p) if output_p else None
                    )
                    self.finished.emit(True, f"Converted {len(result)} WEM files to WAV")
                else:
                    self.progress.emit(f"Converting {input_p.name}...")

                    output_file = None
                    if output_p:
                        if output_p.is_dir():
                            output_file = str(output_p / input_p.with_suffix('.wav').name)
                        else:
                            output_file = str(output_p)
                    result = self.converter.wem_to_wav(str(input_p), output_file)
                    self.finished.emit(True, f"Converted to: {result}")

            elif self.mode == 1:

                if input_p.is_dir():
                    self.progress.emit("Converting audio files in directory...")
                    result = self.converter.batch_convert_to_wav(
                        str(input_p), str(output_p) if output_p else None,
                        normalize=self.normalize
                    )
                    self.finished.emit(True, f"Converted {len(result)} files to WAV")
                else:
                    self.progress.emit(f"Converting {input_p.name}...")

                    output_file = None
                    if output_p:
                        if output_p.is_dir():
                            output_file = str(output_p / input_p.with_suffix('.wav').name)
                        else:
                            output_file = str(output_p)
                    result = self.converter.any_to_wav(
                        str(input_p), output_file, sample_rate=self.sample_rate,
                        normalize=self.normalize
                    )
                    self.finished.emit(True, f"Converted to: {result}")

            else:

                if input_p.is_dir():
                    self.progress.emit("Converting WAV files to WEM...")
                    result = self.converter.batch_convert_wav_to_wem(
                        str(input_p), str(output_p) if output_p else None
                    )
                    self.finished.emit(True, f"Converted {len(result)} WAV files to WEM")
                else:
                    self.progress.emit(f"Converting {input_p.name}...")

                    output_file = None
                    if output_p:
                        if output_p.is_dir():
                            output_file = str(output_p / input_p.with_suffix('.wem').name)
                        else:
                            output_file = str(output_p)
                    result = self.converter.wav_to_wem(str(input_p), output_file)
                    self.finished.emit(True, f"Converted to: {result}")

        except Exception as e:
            error_msg = str(e)
            self.finished.emit(False, f"Conversion failed:\n{error_msg}")

class AudioConversionBridge(QObject):


    inputPathSelected = pyqtSignal(str)
    outputPathSelected = pyqtSignal(str)
    conversionStarted = pyqtSignal()
    conversionFinished = pyqtSignal()
    logMessage = pyqtSignal(str)
    errorOccurred = pyqtSignal(str, str)
    conversionSuccess = pyqtSignal(str, str)
    conversionErrorDialog = pyqtSignal(str, str)

    def __init__(self):
        super().__init__()
        self.worker = None

    @pyqtSlot(int, str, str, int, bool)
    def convertAudio(self, mode, input_path, output_path, sample_rate, normalize):

        print(f"[Audio Conversion] Starting conversion - Mode: {mode}, Input: {input_path}")

        if not input_path:
            self.errorOccurred.emit("Error", "Please select an input file or directory")
            return

        if not Path(input_path).exists():
            self.errorOccurred.emit("Error", f"Input path does not exist:\n{input_path}")
            return

        self.conversionStarted.emit()
        self.logMessage.emit(f"Input: {input_path}")
        self.logMessage.emit(f"Output: {output_path if output_path else 'Auto (same as input)'}")
        self.logMessage.emit(f"Mode: {['WEM → WAV', 'Audio → WAV', 'WAV → WEM'][mode]}")
        self.logMessage.emit(f"Normalize: {'On' if normalize else 'Off'}")
        self.logMessage.emit("Starting conversion...\n")

        self.worker = ConversionWorker(mode, input_path, output_path, sample_rate, normalize)
        self.worker.progress.connect(self._onProgress)
        self.worker.finished.connect(self._onFinished)
        self.worker.start()

    def _onProgress(self, message):

        print(f"[Audio Conversion] {message}")
        self.logMessage.emit(message)

    def _onFinished(self, success, message):

        print(f"[Audio Conversion] Finished - Success: {success}, Message: {message}")
        self.logMessage.emit("\n" + message)
        self.conversionFinished.emit()

        if success:
            self.conversionSuccess.emit("Conversion Complete", message)
        else:

            self.conversionErrorDialog.emit("Conversion Error", message)

        self.worker = None
