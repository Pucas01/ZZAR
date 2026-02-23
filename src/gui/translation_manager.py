from PyQt5.QtCore import QObject, pyqtSignal, pyqtSlot, pyqtProperty, QTranslator, QCoreApplication
from pathlib import Path


class TranslationManager(QObject):

    languageChanged = pyqtSignal()

    SUPPORTED_LANGUAGES = [
        {"code": "en", "name": "English"},
        {"code": "es", "name": "Español"},
    ]

    def __init__(self, engine, parent=None):
        super().__init__(parent)
        self._engine = engine
        self._translator = QTranslator(self)
        self._current_language = "en"
        self._translations_dir = Path(__file__).parent / "translations"

    @pyqtProperty("QVariantList", constant=True)
    def availableLanguages(self):
        return self.SUPPORTED_LANGUAGES

    @pyqtProperty(str, notify=languageChanged)
    def currentLanguage(self):
        return self._current_language

    @pyqtSlot(str)
    def changeLanguage(self, lang_code):
        if lang_code == self._current_language:
            return

        QCoreApplication.instance().removeTranslator(self._translator)

        if lang_code == "en":
            self._current_language = lang_code
            self.languageChanged.emit()
            self._engine.retranslate()
            return

        qm_file = self._translations_dir / f"zzar_{lang_code}.qm"
        if qm_file.exists() and self._translator.load(str(qm_file)):
            QCoreApplication.instance().installTranslator(self._translator)
            self._current_language = lang_code
            self.languageChanged.emit()
            self._engine.retranslate()
        else:
            print(f"[ZZAR] Failed to load translation: {qm_file}")
