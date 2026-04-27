# ListenKids

> Family iOS app — English listening for a 12-year-old (post-PET, ≈B1) at meal-time and bedtime breaks.

Native SwiftUI universal (iPhone + iPad), no backend, content pulled directly from the [Practising English](https://www.practisingenglish.com/) podcast feed.

## Features

- **Library** — episodes auto-pulled from [feeds.buzzsprout.com/1783332.rss](https://feeds.buzzsprout.com/1783332.rss); difficulty (A2 / B1 / B2 / C1) parsed from each title
- **Filter bar** — by level, by length (Short ≤10min / Medium 10–20min / Long >20min)
- **Continue listening** — picks up where you stopped, on either device
- **Background audio** — lock-screen / control-center / AirPods skip ±15s, play/pause
- **Offline downloads** — `URLSession.background` keeps downloading even if the app closes
- **Transcript** — fetched from each episode's page on practisingenglish.com (SwiftSoup), shown in a large-font reading view; long-press any word for the system Look Up dictionary
- **Speed** — 0.8× / 1.0× / 1.2×
- **Sleep timer** — 10 / 20 / 30 / 45 min, fades out before pausing
- **Modes** — three states, persisted across launches:
  - **Free (∞)** — no filtering
  - **Meal (🍴)** — auto-filters episodes ≤15 min, screen stays awake during playback
  - **Bedtime (🌙)** — auto-filters episodes ≥15 min, opens with a 30-min sleep timer, dim warm background in player
- **Favorites + History** — swipe-right on any row to favorite; History lists everything you've started
- **iCloud sync** — progress / favorites travel between iPhone and iPad via SwiftData + CloudKit
- **i18n** — UI follows system language (English / 简体中文)

## Project layout

```
ListenKids/
├── App/                          # @main + DownloadManager bootstrap
├── Models/                       # Episode, Level, LengthBucket, AppMode
├── Sources/                      # ContentSource protocol + PractisingEnglish + RSS/Transcript fetchers
├── Player/                       # AVPlayer engine, audio session, lock-screen
├── Persistence/                  # SwiftData sync / dedupe
├── Downloads/                    # URLSession.background manager
├── Views/
│   ├── Home/                     # HomeView (filter + library + continue)
│   ├── Library/                  # FilterBar, FavoritesView, HistoryView
│   ├── Downloads/                # DownloadsView
│   ├── Player/                   # PlayerView, TranscriptView, SleepTimerSheet
│   ├── Common/                   # EpisodeRow, ModeSwitcher, CircularProgressView
│   └── ContentView.swift         # TabView root
└── Resources/
    └── Localizable.xcstrings     # en + zh-Hans
```

## Setup

```bash
brew install xcodegen   # if not already
xcodegen generate
open ListenKids.xcodeproj
```

In Xcode, open *Signing & Capabilities* and pick your paid Apple Developer team. The bundle identifier is `com.simiaowang.listenkids` and the iCloud container is `iCloud.com.simiaowang.listenkids` — both can be changed by editing `project.yml` and `ListenKids/ListenKids.entitlements`, then re-running `xcodegen generate`.

Then ⌘-R to run on a simulator, or pick your iPhone / iPad from the run-destination menu and ⌘-R to run on device. First launch on device will prompt for microphone-free background audio permission (granted automatically because of `UIBackgroundModes = audio`).

## Putting it on the kid's iPhone / iPad

Easiest: **TestFlight**.

1. In Xcode: *Product → Archive* → *Distribute App* → *App Store Connect* → *Upload*. Wait a few minutes for processing.
2. In [App Store Connect](https://appstoreconnect.apple.com), add the kid's Apple ID as an *Internal Tester* under TestFlight for ListenKids.
3. They install TestFlight on their device, accept the invite email, and tap *Install*.

Re-deploy by archiving and re-uploading; testers get the new build automatically.

For one-off device installs (no TestFlight account churn): Xcode → pick the connected device as run destination → ⌘-R. The app stays installed for 7 days (free profile) or 1 year (paid Developer account).

## Add another content source

The `ContentSource` protocol in [`Sources/ContentSource.swift`](ListenKids/Sources/ContentSource.swift) is one method:

```swift
protocol ContentSource: Sendable {
    var sourceID: String { get }
    var displayName: String { get }
    func fetchEpisodes() async throws -> [FetchedEpisode]
}
```

Implement it in a new file under `ListenKids/Sources/`, then call it from `EpisodeSync.refresh(...)` (currently hard-codes `PractisingEnglish()`). Each source's `sourceID` namespaces its episodes in SwiftData, so two sources with overlapping GUIDs won't collide.

If the next source isn't a podcast RSS feed (e.g. a JSON API), the protocol is intentionally minimal so you can fetch and shape into `FetchedEpisode` however you like. `PractisingEnglish.swift` is a working reference for the RSS + iTunes-namespace case.

## Plan

The full implementation plan, including milestones M1–M5 and out-of-scope decisions, lives in [docs/plans/2026-04-27-kids-listening-ios.md](docs/plans/2026-04-27-kids-listening-ios.md).
