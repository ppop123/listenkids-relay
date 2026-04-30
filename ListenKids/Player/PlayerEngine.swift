import AVFoundation
import Observation
import SwiftData

@MainActor
@Observable
final class PlayerEngine {
    @MainActor static let shared = PlayerEngine()
    private init() {}

    var currentTime: Double = 0
    var duration: Double = 0
    var isPlaying: Bool = false
    var rate: Float = 1.0
    var sleepEndsAt: Date?

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private(set) var loadedEpisodeID: String?
    @ObservationIgnored private weak var contextRef: ModelContext?
    @ObservationIgnored private var episodeRef: Episode?
    @ObservationIgnored private var lastSaveTime: Double = 0

    func load(episode: Episode, context: ModelContext) {
        let url: URL
        if let filename = episode.localAudioPath {
            url = DownloadManager.audioFileURL(for: filename)
        } else if let remote = episode.audioURL {
            url = remote
        } else {
            return
        }
        if loadedEpisodeID == episode.id { return }

        // Tear down any previously playing item so we never have two AVPlayers running.
        teardown()

        loadedEpisodeID = episode.id
        episodeRef = episode
        contextRef = context
        currentTime = episode.playProgressSeconds
        duration = Double(episode.durationSeconds ?? 0)
        lastSaveTime = currentTime
        isPlaying = false

        AudioSessionConfigurator.activate()

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        Task { [weak self] in
            do {
                let cm = try await item.asset.load(.duration)
                let secs = cm.seconds
                if secs.isFinite, secs > 0 {
                    await MainActor.run { self?.duration = secs }
                }
            } catch {}
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let secs = time.seconds
            Task { @MainActor in
                self?.handleTick(seconds: secs)
            }
        }

        if episode.playProgressSeconds > 0 {
            player.seek(to: CMTime(seconds: episode.playProgressSeconds, preferredTimescale: 600))
        }

        NowPlayingService.shared.bind(engine: self, episode: episode)
        play()
    }

    /// Stop and release the current AVPlayer; called when switching episodes.
    private func teardown() {
        if let player, let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
        timeObserver = nil
        saveProgress()
        cancelSleepTimer()
        loadedEpisodeID = nil
        episodeRef = nil
        currentTime = 0
        duration = 0
        isPlaying = false
    }

    func play() {
        guard let player else { return }
        if rate == 1.0 {
            player.play()
        } else {
            player.playImmediately(atRate: rate)
        }
        isPlaying = true
        NowPlayingService.shared.refresh(engine: self)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        NowPlayingService.shared.refresh(engine: self)
        saveProgress()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to seconds: Double) {
        let upper = duration > 0 ? duration : seconds
        let clamped = Swift.max(0, Swift.min(seconds, upper))
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
        currentTime = clamped
    }

    func skip(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if isPlaying { player?.rate = newRate }
    }

    func startSleepTimer(seconds: TimeInterval) {
        cancelSleepTimer()
        let endsAt = Date().addingTimeInterval(seconds)
        sleepEndsAt = endsAt
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.sleepEndsAt == endsAt else { return }
            await self.fadeOutAndPause()
        }
    }

    func cancelSleepTimer() {
        sleepEndsAt = nil
    }

    func saveProgress() {
        guard let ep = episodeRef, let ctx = contextRef else { return }
        ep.playProgressSeconds = currentTime
        ep.lastPlayedAt = Date()
        try? ctx.save()
    }

    private func fadeOutAndPause() async {
        guard let player else {
            pause()
            sleepEndsAt = nil
            return
        }
        let initialVolume = player.volume
        let steps = 10
        for i in 0..<steps {
            let v = initialVolume * (1.0 - Float(i + 1) / Float(steps))
            player.volume = max(0, v)
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        pause()
        player.volume = initialVolume
        sleepEndsAt = nil
    }

    private func handleTick(seconds: Double) {
        guard seconds.isFinite else { return }
        currentTime = seconds
        if seconds - lastSaveTime > 5 {
            lastSaveTime = seconds
            saveProgress()
        }
        NowPlayingService.shared.refresh(engine: self)
    }
}
