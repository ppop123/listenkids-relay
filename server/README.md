# Server side (Mac mini home relay)

Seven Python scripts that mirror content, transcribe it, build a manifest, and serve it to the iOS app. Designed for an Apple Silicon Mac mini left running at home. No external dependencies beyond `ffmpeg`, `mlx-whisper`, and Python 3.9+ stdlib.

## Scripts

| Script | What it does | Cadence |
|---|---|---|
| `sync.py` | Pull Practising English podcast RSS, download new mp3s into `~/listenkids/audio/`, rewrite enclosure URLs to point at this server. | Daily (Task Scheduler / `launchd`) |
| `fetch_storynory.py` | Mirror Storynory feed → `~/listenkids/audio_storynory/` + `storynory.json` metadata. | Daily |
| `fetch_librivox.py` | Walk a curated book list, query LibriVox API, download chapter mp3s into `~/listenkids/series/librivox/<slug>/` with per-book `manifest.json`. | One-shot per book add |
| `organize.py` | Scan all sources, parse PE titles for series + part + level + kind (story / lesson / exam), embed-probe Dahl mp3s for duration, write the master `~/listenkids/manifest.json` consumed by the iOS app. | Daily after fetches |
| `transcribe.py` | Walk every mp3 under `~/listenkids/`, skip files that already have a transcript JSON, and run `mlx-whisper` (default `small.en`). Outputs JSON with segment-level timestamps to `~/listenkids/transcripts/`. | Long-running; restart whenever new mp3s land |
| `retranscribe.py` | Daemon that tails `~/listenkids/bad_transcripts.log`. Each entry written by the iOS app's "subtitle out of sync" report triggers a re-run on that file with the heavier `medium.en` model. | Always-on |
| `serve.py` | Single-file `http.server`: GET serves `~/listenkids/` statics, POST `/report` appends an entry to `bad_transcripts.log` for the daemon to pick up. | Always-on |
| `gen_covers.py` | One-shot doubao-seedream image generator — creates a unified-style cover for every series in `manifest.json` that's missing one. Saves locally; `rsync` to mac mini after. | When a new series shows up without a cover |

## Layout on the relay

```
~/listenkids/
├── audio/                          ← Practising English podcast mp3s
├── audio_storynory/                ← Storynory mp3s
├── series/
│   ├── roald-dahl/<book folder>/   ← rsync'd from your NAS
│   └── librivox/<book-slug>/       ← fetched by fetch_librivox.py
├── transcripts/                    ← mlx-whisper output, basename matches mp3
├── feed.xml                        ← rewritten Practising English feed (audio→relay)
├── manifest.json                   ← master content manifest used by app
├── storynory.json                  ← Storynory metadata
├── bad_transcripts.log             ← user-reported sync issues
├── bad_transcripts_done.log        ← daemon's processed log
└── *.log                           ← per-script logs
```

## Environment

```
LK_PUBLIC          base URL the iOS app uses (default http://192.168.50.8:18000)
LK_REPAIR_MODEL    Whisper model for retranscribe daemon (default mlx-community/whisper-medium.en-mlx)
VOLCANO_API_KEY    only for gen_covers.py (doubao-seedream API)
```

## Suggested launchd plist

A boot-time `launchd` job for `serve.py` + `retranscribe.py` is the minimum to keep the relay healthy. `sync.py` / `transcribe.py` / `organize.py` can be cronned daily.

(See `docs/launchd/*.plist` — not yet checked in, planned.)

## Why no Docker / nginx / etc.

This is a relay for one family. `python3 -m http.server` handles the load (one or two clients streaming mp3 + JSON). `mlx-whisper` runs natively against the Mac mini's NPU. Adding orchestration would add operational debt for zero throughput gain.
