# openclaw-relay

> A home-server media relay + iOS client for English-listening practice, end-to-end built by Claude Code in a single 24h session.
>
> 给家里 12 岁孩子（PET → FCE 区间）做磨耳朵的家用 relay：本地 NAS / Mac mini 当内容枢纽，iOS app 当客户端。

---

## What it does

- Pulls long-form story audio from multiple sources — **Practising English** podcast (RSS), **Roald Dahl** audiobooks (rsync from NAS), **Storynory** (RSS), **LibriVox** public-domain classics (API) — into a single library on a home Mac mini.
- Auto-classifies every item by **CEFR level (A2 / B1 / B2 / C1)** and **kind (story / lesson / exam)**. The iOS home screen surfaces only narrative listening; tutorial podcasts are tucked away.
- Auto-transcribes every mp3 to **segment-level timestamps** via `mlx-whisper`, driving a karaoke-style scrolling subtitle in-app.
- One-tap *"subtitle out of sync"* report from the iOS app → daemon picks the file up and retranscribes it with a heavier model → next launch shows the fix. Quality loop fully driven by the kid using the app.
- Generates missing cover art via `doubao-seedream`. Unified cozy hand-drawn style across all sources.
- iPhone + iPad **universal SwiftUI app**, mode-aware (Free / Meal / Bedtime), karaoke transcripts, sleep timer, offline downloads, iCloud progress sync between devices.
- Reachable from outside the house via Cloudflare Tunnel — same URL whether on home Wi-Fi or cellular.

## Why

Off-the-shelf podcast clients are content-agnostic and have no concept of CEFR difficulty or "story vs lesson". Off-the-shelf English-learning apps are grammar-heavy and bad at narrative listening. A 12-year-old working PET → FCE wants real stories during meals or before sleep, with a safety net when an unfamiliar word lands.

This is the kind of hyperpersonalized "app for my one kid" project that's economically nonviable as a SaaS — but trivial when an LLM agent does the labor end-to-end.

## Architecture

```
                     ┌────────────────────────────────────┐
                     │       Mac mini (home relay)        │
   PE Podcast RSS ─▶ │ sync.py        ─┐                  │
   Roald Dahl rsync ▶│ fetch_storynory  │                  │
   Storynory   RSS ▶ │ fetch_librivox   │                  │
   LibriVox    API ▶ │                  ▼                  │
                     │             ~/listenkids/           │
                     │              ├ audio/               │
                     │              ├ audio_storynory/     │
                     │              ├ series/{dahl,librivox}│
                     │              └ transcripts/         │
                     │                                     │
                     │ mlx-whisper (small.en / medium.en)  │
                     │   ─▶ JSON segments + timestamps     │
                     │                                     │
                     │ organize.py ─▶ manifest.json        │
                     │   (level + kind + series grouping)  │
                     │                                     │
                     │ serve.py (port 18000)               │
                     │   ├ GET   /  static files           │
                     │   └ POST  /report  bad transcript   │
                     │                                     │
                     │ retranscribe.py daemon              │
                     │   tails bad_transcripts.log         │
                     │   re-runs Whisper with bigger model │
                     └─────────────────┬───────────────────┘
                                       │ HTTP (LAN)  /
                                       │ Cloudflare Tunnel (anywhere)
                                       ▼
                     ┌────────────────────────────────────┐
                     │      iOS app  (SwiftUI · iOS 17+)   │
                     │                                     │
                     │   HomeView   carousels by source    │
                     │   CollectionDetailView              │
                     │   PlayerView + KaraokeView          │
                     │   DownloadsView (offline)           │
                     │   FavoritesView · HistoryView       │
                     │                                     │
                     │   PlayerEngine  singleton AVPlayer  │
                     │   SwiftData + CloudKit progress     │
                     │   AVAudioSession bg audio           │
                     │   MPNowPlayingInfoCenter lock screen│
                     └────────────────────────────────────┘
```

## Numbers (current state)

| | |
|---|---|
| Audio files mirrored | **1 270** |
| Total runtime | **~414 hours** |
| Series (Dahl + Bilibili + LibriVox + PE) | **71** (32 + 5 + 9 + 25) |
| Standalone story episodes | **327** (267 PE + 60 Storynory) |
| Series with cover art | **71 / 71** (23 originals + 48 doubao-generated) |
| Real devices auto-deployed | **3** (iPad Pro · iPhone 17 Pro · iPhone 15 Pro) |
| Sources connected | **5** (Practising English, Roald Dahl, Storynory, LibriVox, Bilibili) |
| Time from empty repo to multi-source device | **~28h** across two Claude Code sessions |

The Bilibili source uses `yt-dlp` to extract audio-only from anthology
videos — Stephen Fry's full 7-book Harry Potter (200 chapters), Charlotte's
Web, Magic School Bus 52 episodes, Horrid Henry, and The Worst Witch — and
refreshes chapter titles from Bilibili's web-view API so the UI shows real
chapter names instead of `p1 / p2 / ...`.

## Why it's interesting (the agent angle)

Everything here was assembled by **[Claude Code](https://www.anthropic.com/claude/code)** — Swift / SwiftUI / SwiftData iOS code, Python relay scripts, mlx-whisper ASR pipeline, doubao-seedream image generation, xcodegen + xcodebuild + devicectl real-device sign-and-install — all in one continuous session.

- **Long-chain reasoning across stacks** — debugging Xcode signing while restarting transcription daemons while regenerating cover art, all in the same loop.
- **Multi-agent collaboration** — Claude Code as the orchestrator, calling `mlx-whisper`, `doubao-seedream`, dictionary APIs, etc., as specialized subagents.
- **Honest user-driven quality loop** — the user (a kid) reports "字幕不准" through a `exclamationmark.bubble` button; the server retranscribes; the client invalidates cache. No ML-ops engineer in the middle.

## Repository layout

```
.
├── README.md                          ← this file
├── project.yml                        ← xcodegen project definition
├── ListenKids/                        ← iOS app source (SwiftUI)
│   ├── App/
│   ├── Models/
│   ├── Sources/                       ← ContentSource protocol + ManifestSource
│   ├── Player/                        ← AVPlayer wrapper, audio session, lock screen
│   ├── Persistence/
│   ├── Downloads/
│   ├── Views/                         ← Home / Player / Library / Downloads / Common
│   └── Resources/Localizable.xcstrings
├── server/                            ← Mac mini relay scripts
│   ├── sync.py                        ← Practising English podcast RSS → audio + feed.xml
│   ├── fetch_storynory.py             ← Storynory RSS → audio_storynory/
│   ├── fetch_librivox.py              ← LibriVox API → series/librivox/<book>/
│   ├── fetch_bilibili.py              ← yt-dlp Bilibili audio → series/bilibili/<slug>/
│   ├── update_bilibili_titles.py      ← refresh chapter titles from B站 web-view API
│   ├── organize.py                    ← scans everything → manifest.json (with level + kind)
│   ├── transcribe.py                  ← mlx-whisper backfill (small.en default)
│   ├── retranscribe.py                ← daemon: medium.en repair driven by app reports
│   ├── serve.py                       ← Python http.server + POST /report
│   ├── gen_covers.py                  ← doubao-seedream cover generator
│   └── README.md                      ← server-side quick start
├── docs/
│   ├── STATE.md                       ← current full-system state snapshot
│   └── plans/                         ← planning docs
└── docs/plans/                        ← planning docs
```

## Quick start

```bash
# 1. Home server (Mac mini with Apple Silicon recommended for mlx-whisper)
git clone https://github.com/ppop123/openclaw-relay
cd openclaw-relay/server

# Install once (assumes Homebrew + Python 3.9+; mlx-whisper needs Apple Silicon):
brew install ffmpeg
python3 -m pip install mlx-whisper

python3 sync.py             # pull Practising English podcast + mp3
python3 fetch_storynory.py  # pull Storynory
python3 fetch_librivox.py   # pull selected LibriVox classics
# rsync your Roald Dahl audiobooks into ~/listenkids/series/roald-dahl/

python3 transcribe.py &           # mlx-whisper backfill (small.en)
python3 serve.py        &         # static + /report endpoint
python3 retranscribe.py &         # quality-repair daemon
python3 organize.py               # build manifest.json (run after fetches)

# Optional: cloudflared tunnel to expose port 18000 to a public hostname.

# 2. iOS app (any Mac with Xcode 15+)
cd ../
brew install xcodegen
xcodegen generate
open ListenKids.xcodeproj
# Edit ListenKids/Sources/ManifestSource.swift if your relay isn't 192.168.50.8
# Pick your team in Signing & Capabilities, ⌘R to run on device.
```

## Configuration

Hardcoded values you'll likely want to edit before running:

- `ListenKids/Sources/ManifestSource.swift` — `baseURL` (default `http://192.168.50.8:18000`)
- `project.yml` — `PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`
- `server/*.py` — `LK_PUBLIC` env var (default `http://192.168.50.8:18000`)
- `server/gen_covers.py` — `VOLCANO_API_KEY` env var (only needed if you want to regenerate covers)

## Tech stack

- **iOS** — Swift 6 / SwiftUI / SwiftData / AVFoundation / iOS 17+ / xcodegen
- **Server** — Python 3, [mlx-whisper](https://github.com/ml-explore/mlx-examples) (Apple Silicon), ffmpeg, stdlib `http.server` (no nginx needed for one-family scale)
- **AI** — mlx-whisper (`small.en` / `medium.en`), doubao-seedream-5 (cover art)
- **Distribution** — LAN HTTP for in-house, Cloudflare Tunnel for anywhere
- **Built by** — [Claude Code](https://www.anthropic.com/claude/code), Anthropic's coding agent

## Roadmap

- [x] Multi-source content aggregation
- [x] Whisper-driven karaoke subtitles + user-reported repair loop
- [x] iPhone + iPad universal UI with NavigationSplitView on iPad
- [x] Offline downloads + iCloud progress sync
- [x] Auto cover-art generation for missing series
- [x] Bilibili source via yt-dlp (Stephen Fry HP, Charlotte's Web, Magic School Bus, Horrid Henry, Worst Witch)
- [x] Story-vs-lesson classification — only narrative listening surfaces on home
- [ ] launchd plists so serve / retranscribe / transcribe survive Mac mini reboots
- [ ] Cloudflare Tunnel for outside-the-house access
- [ ] Vocabulary game module (words from listened transcripts → SM-2 spaced repetition + 4 mini-game modes)
- [ ] PlayerView blur cover background (Apple Music style)
- [ ] Parent dashboard — listening minutes, words mastered, level progression
- [ ] Backfill missing HP Book-7 chapter names (Bilibili UP labelled them `fry_7_NN`)

## License

MIT.

## Acknowledgments

- [Practising English](https://www.practisingenglish.com/) — Mike Bilbrough's free B1-B2 ESL podcast
- [Storynory](https://www.storynory.com/) — free audio stories for kids
- [LibriVox](https://librivox.org/) — public-domain audiobooks
- The Roald Dahl audiobook narrators — Eric Idle, Geoffrey Palmer, Stephen Fry, Hugh Laurie, Andrew Sachs, Timothy West, June Whitfield, Miriam Margolyes, Simon Callow, Alan Cumming
- [mlx-whisper](https://github.com/ml-explore/mlx-examples), [Anthropic Claude Code](https://www.anthropic.com/claude/code), [doubao-seedream](https://www.volcengine.com/)
