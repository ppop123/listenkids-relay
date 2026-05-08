# State snapshot — 2026-05-06

Captures the full system after Day-2 session work. Read this first if resuming the project.

## Inventory

```
71 series · 327 standalone · 1270 audio items · ~414 hours
```

| Source | Series | Parts | Standalone | Cover | Notes |
|---|---:|---:|---:|---|---|
| Roald Dahl | 32 | 389 | — | 23 originals + 9 doubao-generated | rsync from NAS share `/Volumes/share/罗尔德-达尔...` |
| Bilibili | 5 | 338 | — | 5 doubao-generated | yt-dlp; HP 200, Worst Witch 35, Horrid Henry 29, Magic School Bus 52, Charlotte's Web 22; chapter titles refreshed from B站 web-view API |
| LibriVox | 9 | 177 | — | 9 doubao-generated | API-driven curated list; first batch `(The) Secret Garden / Wonderful Wizard of Oz / Black Beauty / A Little Princess` were missed by exact-title matching, refetched with article-stripped query |
| Practising English | 25 | 39 | 267 | 25 doubao-generated (carousel-level) | Buzzsprout RSS; standalone classified into story 233 / lesson 26 / exam 8; only stories surface on home |
| Storynory | — | — | 60 | (no per-series; standalones) | Modern Storynory site uses `/feeds/stories/` (the older `/feed/` path 500s) |

All 71 series have a cover image. Whisper transcript backfill still in flight (last seen 998/1270 = 78% with 341 todo).

## Architecture

```
Mac mini (192.168.50.8, wangyan@) — home relay
    /Users/wangyan/listenkids/
        audio/                          PE podcast mp3s
        audio_storynory/                Storynory mp3s
        series/{roald-dahl,librivox,bilibili}/<slug>/  audiobooks
        transcripts/                    Whisper JSON, basename matches mp3
        feed.xml                        rewritten PE feed
        manifest.json                   master content manifest the iOS app reads
        storynory.json                  Storynory standalone metadata
        bad_transcripts.log             reports from app's "字幕不准" button
        bad_transcripts_done.log        retranscribe daemon's processed log
        .duration_cache.json            ffprobe cache for organize.py speed
        *.log                           per-script logs

    Daemons / scripts:
        serve.py            Always-on. Single-file http.server :18000.
                            GET /  static + POST /report. Restart with
                            `nohup python3 serve.py > serve.log 2>&1 &`.
                            (Has died on apparent mac mini reboots — needs a
                             real launchd plist, see TODO.)
        retranscribe.py     Always-on daemon. Tails bad_transcripts.log,
                            re-runs Whisper at medium.en for any url it sees.
        transcribe.py       Long-running. small.en backfill across
                            audio/, audio_storynory/, series/. Skip-if-exists.
                            Restart whenever new mp3s land.
        sync.py             Periodic. PE podcast RSS → audio/ + feed.xml.
        fetch_storynory.py  Periodic. Storynory RSS → audio_storynory/ +
                            storynory.json.
        fetch_librivox.py   On-demand. Curated book list → series/librivox/.
        fetch_bilibili.py   On-demand. Hardcoded BV list →
                            series/bilibili/<slug>/. yt-dlp -x to mp3.
        update_bilibili_titles.py  One-shot. Refreshes manifest.json titles
                            from Bilibili web-view API per-page metadata.
        organize.py         Periodic. Scans every source, parses titles for
                            series/part/level/kind, ffprobe-fills durations,
                            writes manifest.json.
        gen_covers.py       On-demand. Reads manifest, calls doubao-seedream
                            for any series whose cover is null. Saves to
                            /tmp/lk_covers/<sourceID>/<slug>/cover.png; rsync
                            into ~/listenkids/series/ to deploy. Uses
                            VOLCANO_API_KEY env var.

iOS client (ListenKids/) — universal SwiftUI
    PadShell  (NavigationSplitView with Home/Downloads/Favorites/History sidebar)
    PhoneShell (TabView Home + Downloads)

    HomeView                vertical layout: ModeSwitcher pill,
                            "Continue listening" if any, then a horizontal
                            carousel per source group (Roald Dahl, Bilibili,
                            LibriVox, Practising English Stories), then
                            "Stories" list of standalone story episodes.
                            Lessons + exam are hidden from home.
                            .task always refreshes manifest from relay.
    CollectionDetailView    series cover + chapter list.
    PlayerView              big level-tinted cover, slider hidden until
                            duration is known, transport, mode-aware
                            background (bedtime = warm dim). Toolbar: star,
                            speed, sleep timer, karaoke toggle, report
                            button.
    KaraokeView             Whisper segments, current-line highlight + bar
                            indicator + auto-scroll.
    PlayerEngine            singleton AVPlayer + teardown on switch (so we
                            never have two players running).
    TranscriptStore         actor; per-episode in-memory cache;
                            clearCache(for:) called when user reports bad
                            transcript.
    DownloadManager         URLSession.background; stores under Documents/.
    SwiftData + CloudKit    Episode persistence; iCloud sync between devices.

Networking
    LAN:  http://192.168.50.8:18000/
    WAN:  Cloudflare Tunnel planned; not yet provisioned (we set up the
          architecture, never finalised the tunnel). Once provisioned, the
          base URL in ManifestSource just changes to the cloudflare hostname.
```

## Quality loop (most important agent-built feature)

1. Kid taps the `exclamationmark.bubble` button in PlayerView while a transcript looks off-sync.
2. App POSTs `{episodeID, audioURL, transcriptURL, currentTime}` to `http://relay:18000/report`.
3. `serve.py` appends a JSON line to `~/listenkids/bad_transcripts.log`.
4. `retranscribe.py` daemon picks it up within 30s, deletes the existing transcript, re-runs `mlx-whisper --model mlx-community/whisper-medium.en-mlx`, and writes the new JSON.
5. App also clears `TranscriptStore` cache for that `episode.id` immediately on report, so the next sheet open fetches fresh.

## Known issues / outstanding TODOs

- [ ] **launchd plists** for serve.py + retranscribe.py + transcribe.py — they have died at least twice when the mac mini rebooted. Needs proper `~/Library/LaunchAgents/com.openclaw.relay.*.plist` definitions so the trio comes back at boot.
- [ ] **Cloudflare Tunnel** — architectural decision made, tunnel not actually provisioned. Means the app only works on home wifi. Needs `cloudflared service install` + cloudflare account + a hostname routed to localhost:18000.
- [ ] **iPhone 15 Pro device deployment** still requires Xcode UI ⌘R for first-time provisioning (CLI xcodebuild loses Xcode account session).
- [ ] **HP last 30-ish chapters** have raw Bilibili names like "P36fry_7_36" (UP-loader was less careful for Book 7). Could be patched manually with the canonical Wikipedia chapter list for *Deathly Hallows*.
- [ ] **PlayerView blur cover background** — Apple Music-style derived blur from cover artwork. Listed in roadmap but not built.
- [ ] **Vocabulary game module** — design lives in the prior brainstorm; not built. SM-2 lite + 4 mini-games (audio→meaning, cloze, image→word, speed round) backed by a `vocab.json` built from existing transcripts.
- [ ] **SeriesListView "See All"** — carousels currently show first ~6 covers; no entry into a full grid view per source.

## Numbers checkpoint

- Build sessions: 2 (Day-1 = M1-M4, Day-2 = manifest refactor + Bilibili + cover gen + report loop)
- Token consumption (Day-2 alone): ~5-8M
- Real devices: iPad Pro 12.9 + grace's iPhone 17 Pro (CLI installs); iPhone 15 Pro (Xcode UI deploy pending)
- Time from "what should we build" to "Stephen Fry HP 200 chapters scrolling karaoke on grace's iPhone": ~28 hours of real time across two days, mostly spent waiting on transcribe / fetch processes — actual agent work was much less.

## How to resume

```bash
ssh wangyan@192.168.50.8 'pgrep -fl "serve.py|retranscribe.py|transcribe.py" | grep -v grep'
# If anything is missing, restart:
ssh wangyan@192.168.50.8 'cd ~/listenkids && nohup python3 serve.py > serve.log 2>&1 & disown'
ssh wangyan@192.168.50.8 'cd ~/listenkids && nohup python3 retranscribe.py > retranscribe.log 2>&1 & disown'
ssh wangyan@192.168.50.8 'cd ~/listenkids && nohup python3 transcribe.py > transcribe.log 2>&1 & disown'
ssh wangyan@192.168.50.8 'tail -f ~/listenkids/transcribe.log'   # watch backfill
```
