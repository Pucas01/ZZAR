ZZAR Translations

.ts files are translation sources (XML), .qm files are compiled binaries loaded at runtime.

Adding a language:
  1. Copy zzar_en.ts to zzar_XX.ts (XX = language code, e.g. es, ja, zh)
  2. Update the language attribute in the new file: language="es_ES"
  3. Translate each <translation> tag and remove type="unfinished"
  4. Compile with: lrelease zzar_XX.ts
  5. Add the language to SUPPORTED_LANGUAGES in src/gui/translation_manager.py

Updating after code changes:
  lupdate src/gui/qml/ src/gui/components/ -ts src/gui/translations/zzar_en.ts

