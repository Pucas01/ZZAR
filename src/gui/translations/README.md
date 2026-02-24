ZZAR Translations

.ts files are translation sources (XML), .qm files are compiled binaries loaded at runtime.

Adding a language:
  1. Copy zzar_en.ts to zzar_XX.ts (XX = language code, e.g. es, ja, zh)
  2. Update the language attribute in the new file: language="es_ES"
  3. Translate each <translation> tag and remove type="unfinished"
  4. Compile with: lrelease zzar_XX.ts
  5. Add the language to SUPPORTED_LANGUAGES in src/gui/translation_manager.py

Updating .ts files after code changes:
  When you add new qsTr() strings in QML, run lupdate to automatically extract
  them into all .ts files at once:

  Run da script

  lrelease zzar_es.ts

  This scans all QML files for qsTr() calls and adds any new strings as
  <message> entries with type="unfinished". Existing translations are preserved.
  After running lupdate, translate the new entries and recompile with lrelease.
