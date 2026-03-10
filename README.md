<p align="center">
  <img src="src/gui/assets/ZZAR-Logo2.svg" alt="ZZAR Logo" width="200"/>
</p>

<h1 align="center">ZZAR</h1>
<p align="center"><b>Zenless Zone Zero Audio Replacer</b></p>

<p align="center">
  Replace any sound in Zenless Zone Zero with your own audio.<br/>
  Built-in mod manager, audio browser, and format converter.
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-1.2.0-blue"/>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux-lightgrey"/>
  <img alt="Python" src="https://img.shields.io/badge/python-3.14-green"/>
  <img alt="License" src="https://img.shields.io/badge/status-Released-green"/>
</p>

---

## What is ZZAR?

ZZAR is 2 things, a **Mod Manager** and a **Mod Creator**

Want to just install mods? its as easy as clicking install, selecting your `.zzar` mod file and enabling it!

Are you a mod creator and want to port over your old mods? just click "Import Non-ZZAR Mod" select your loose wem files or your built pck file and export it as `.zzar`

You can also replace any audio in Zenless Zone Zero, character voice lines, sound effects, music, basicly everything. no command line stuff. Just pick the sound you want to change, select your replacement or mute it, and you're good to go, It handles all the annoying format conversion stuff and packages everything into installable `.zzar` files.

## Features

- **Mod Manager** - Install, enable/disable, and manage audio mods. Handles conflicts when multiple mods replace the same sound.
- **Audio Browser** - Browse every sound in the game, organized by type and language. Preview them, play them, replace them all right in the app. (you can even rename sounds and give them searchable tags)
- **Mod Creator / Converter** - Build your own `.zzar` mod packages or convert your old ones.
- **Audio Converter** - Convert between MP3, WAV, and WEM. ZZAR handles the Wwise encoding automatically.
- **Auto Updater** - Automaticly updates ZZAR when a new version is released
- **Cross-Platform** - Works on both Windows and Linux (with Wine for Wwise).

## Planned features
See all our [Planned features](FEATURES.md) here.

## Getting Started

### Option 1: Pre-built Release (Recommended)

Grab the latest release from the [Releases](../../releases) page.

### Option 2: Run from Source

```bash
# Clone the repo
git clone https://github.com/Pucas01/ZZAR.git
cd ZZAR

# Install dependencies
pip install -r requirements.txt

# Launch
python ZZAR.py
```

Or use the provided launcher scripts:
- **Windows:** `start_gui.bat`
- **Linux:** `start_gui.sh`

### First Launch

On first launch, ZZAR will try to auto-detect your ZenlessZoneZero install. If it can't find it, just point it to your ZenlesZoneZero_Data folder located in this folder HoYoPlay/games/ZenlessZoneZero Game/ZenlessZoneZero_Data.

You'll also be prompted to set up **Wwise** (needed for converting audio to the game's format) and **FFmpeg/vgmstream** (for general audio conversion). The app auto installs both.

## How It Works

ZZZ stores its audio inside `.pck` files. The sounds the game actually plays live inside `.bnk` SoundBank files, which are nested inside those `.pck` archives. ZZAR knows how to dig into that, pull out individual sounds, replace them with yours, and repack everything so the game loads it.

```
SoundBank_SFX_1.pck
└── 428903628.bnk
    ├── 134133939.wem    ← this is what the game plays (most of the time)
    ├── 18063035.wem
    └── ...
```

> **Heads up:** The game also has `Streamed_SFX_*.pck` files that contain the same sound IDs, but the game **doesn't always use those**. ZZAR targets the correct SoundBank files so your mods actually work.

## Requirements

(These only apply if running from source)

- **Python 3.14**
- **PyQT5**
- **FFmpeg** — for audio format conversion (Linux)
- **vgmstream** — for WEM playback and conversion (Linux)

ZZAR can set up FFmpeg, vgmstream, and Wwise for you through the built-in setup wizards.

## Contributing

Found a bug or have an idea? Open an issue! Pull requests are welcome too.

## Credits

- **failsafe65** - For making the original audio modding scripts.
- **mob159** - For improving on failsafe65's PCK extraction and packing scripts which have been used as reference.
- **Thoronium** - For making HAMM and for making the Wwise project file.
- **noirs_rf** - For making a free concept ZZZ design which this program's design is based on.
- **Retrotecho** - For making the first ZZAR logo design.
- **alver_418** - Maker of Zenless Tools, for making the Chat generator which assets of it were used.

### Testers

- **mob159** - For helping me out the most during development.
- **Marbles** - For helping me to do some testing and providing feedback.
- **Skysill** - For helping me test the linux build.

### Translators

- **Luafile_Gabriel** - Spanish translation.

## Disclaimer

ZZAR is a fan-made tool and is not affiliated with HoYoverse. Use at your own risk.
