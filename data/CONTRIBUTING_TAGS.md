# Contributing to the Sound Tag Database

The sound database helps everyone find specific sounds faster in the audio browser. Every tagged sound makes modding easier for the whole community.

## How It Works

When you tag a sound in ZZAR (right-click a WEM file > Tag Sound), it gets saved locally. You can export your tags and submit them to the official database so everyone benefits.

## What to Tag

Give sounds a short, clear **name** and relevant **tags**:

| Field | What to write | Example |
|-------|---------------|---------|
| Name | What the sound is | `Bardic needle background music` |
| Tags | Comma-separated keywords | `bardic needle, music, store` |
| Notes | Optional extra context | `Background song that plays in Bardic needle` |

### Good Tag Examples

- Character voices: `ellen, voice, skill, ultimate`
- Sound effects: `combat, ultimate, hit, EX`
- UI sounds: `ui, menu, click, confirm`
- Music: `music, battle, boss`
- Ambience: `ambience, city, crowd, daytime`

### Tips

- Use **lowercase** for tags
- Use the **character name** as a tag for voice lines (e.g. `ellen`, `wise`, `belle`)
- Be specific but not too wordy — `sword slash heavy` beats `the sound of a heavy sword slash attack`
- If a sound plays during a specific ability, mention it: `ellen, ultimate`

## How to Submit

1. Tag sounds in ZZAR as you browse
2. Export your local database (open location with in app button)
3. Open a PR adding your entries to `data/official_sound_database.json`

Or just share your `sound_database.json` file in a GitHub issue and we'll merge it in.

## Database Format

The JSON file maps sound hashes to their info:

```json
{
  "a1b2c3d4e5f6...": {
    "name": "Bardic needle background music",
    "tags": ["bardic needle", "music", "store"],
    "notes": "",
    "file_ids": [123456789],
    "date_added": "2025-06-15T10:30:00",
    "date_modified": "2025-06-15T10:30:00"
  }
}
```

The hash is a SHA256 of the raw WEM audio bytes — ZZAR computes this automatically, so you don't need to worry about it.

## Questions?

Open an issue on the repo.
