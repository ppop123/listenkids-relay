import SwiftUI
import SwiftData

struct PlayerView: View {
    let episode: Episode
    @Environment(\.modelContext) private var context
    @State private var engine = PlayerEngine.shared
    @State private var modeStore = AppModeStore.shared
    @State private var showSleepTimer = false
    @State private var showKaraoke = true
    @State private var segments: [TranscriptSegment] = []
    @State private var loadingTranscript = false
    @State private var showReportConfirm = false

    private var isBedtime: Bool { modeStore.current == .bedtime }
    private var fg: Color { isBedtime ? .white : .appInk }
    private var fgSoft: Color { isBedtime ? .white.opacity(0.65) : .appMuted }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                header.padding(.horizontal, 20).padding(.top, 8)
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                progressSection.padding(.horizontal, 32)
                transportControls
                if let end = engine.sleepEndsAt {
                    Label("Sleep at \(end.formatted(.dateTime.hour().minute()))",
                          systemImage: "moon.stars.fill")
                        .font(.rounded(13, weight: .medium))
                        .foregroundStyle(fgSoft)
                }
                Spacer().frame(height: 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    favoriteButton
                    speedMenu
                    sleepButton
                    karaokeToggleButton
                    reportButton
                }
            }
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet(engine: engine).presentationDetents([.medium])
        }
        .alert("Reported", isPresented: $showReportConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll regenerate this transcript with a more accurate model in a few minutes. Pull to refresh later.")
        }
        .task {
            engine.load(episode: episode, context: context)
            if isBedtime && engine.sleepEndsAt == nil {
                engine.startSleepTimer(seconds: 30 * 60)
            }
            UIApplication.shared.isIdleTimerDisabled = (modeStore.current == .meal)
            await loadSegments()
        }
        .onDisappear {
            engine.saveProgress()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            Text(episode.displayTitle)
                .font(.rounded(showKaraoke ? 17 : 22, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(fg)
                .lineLimit(showKaraoke ? 2 : 3)
                .animation(.easeInOut(duration: 0.25), value: showKaraoke)
            if let level = episode.level, !showKaraoke {
                Text(level.rawValue)
                    .font(.rounded(13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(level.tint)
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if showKaraoke {
            karaokePane
        } else {
            cover
                .frame(width: 220, height: 220)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var karaokePane: some View {
        if !segments.isEmpty {
            KaraokeView(
                segments: segments,
                currentTime: engine.currentTime,
                onSeek: { engine.seek(to: $0) },
                isBedtime: isBedtime
            )
        } else if loadingTranscript {
            VStack {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                    .tint(fg)
                Text("Loading transcript…")
                    .font(.rounded(14, weight: .medium))
                    .foregroundStyle(fgSoft)
                    .padding(.top, 8)
                Spacer()
            }
        } else {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "text.alignleft")
                    .font(.system(size: 42))
                    .foregroundStyle(fgSoft)
                Text("No transcript available yet")
                    .font(.rounded(14, weight: .medium))
                    .foregroundStyle(fgSoft)
                Text("Transcripts are generated overnight on the home server")
                    .font(.rounded(12))
                    .foregroundStyle(fgSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
        }
    }

    private var cover: some View {
        let tint = episode.level?.tint ?? Color.accentColor
        return ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(LinearGradient(
                    colors: [tint, tint.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.white.opacity(0.08))
            VStack(spacing: 6) {
                if let num = episode.displayNumber {
                    Text(num)
                        .font(.system(size: 78, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                if let l = episode.level {
                    Text(l.rawValue)
                        .font(.rounded(20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
        }
        .shadow(color: tint.opacity(0.45), radius: 24, x: 0, y: 12)
    }

    private var progressSection: some View {
        VStack(spacing: 4) {
            if engine.duration > 1 {
                Slider(
                    value: Binding(
                        get: { min(engine.currentTime, engine.duration) },
                        set: { engine.seek(to: $0) }
                    ),
                    in: 0...engine.duration
                )
                .tint(isBedtime ? .white.opacity(0.7) : .accentColor)
                HStack {
                    Text(timeString(engine.currentTime))
                    Spacer()
                    Text("-" + timeString(max(engine.duration - engine.currentTime, 0)))
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(fgSoft)
            } else {
                // Duration not yet known (server didn't include it; AVFoundation still loading).
                // Show only elapsed time and a disabled placeholder bar.
                Capsule()
                    .fill(fgSoft.opacity(0.25))
                    .frame(height: 4)
                HStack {
                    Text(timeString(engine.currentTime))
                    Spacer()
                    Text("--:--")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(fgSoft)
            }
        }
    }

    private var transportControls: some View {
        HStack(spacing: 36) {
            Button { engine.skip(by: -15) } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(fg)
            }
            Button { engine.togglePlayPause() } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .shadow(color: Color.accentColor.opacity(0.45), radius: 14, x: 0, y: 8)
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: engine.isPlaying ? 0 : 3)
                }
                .frame(width: 84, height: 84)
            }
            Button { engine.skip(by: 15) } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(fg)
            }
        }
    }

    // MARK: - Toolbar buttons

    private var favoriteButton: some View {
        Button {
            episode.isFavorite.toggle()
            try? context.save()
        } label: {
            Image(systemName: episode.isFavorite ? "star.fill" : "star")
                .foregroundStyle(episode.isFavorite ? .yellow : fg)
        }
    }

    private var speedMenu: some View {
        Menu {
            ForEach([0.8, 1.0, 1.2], id: \.self) { r in
                Button {
                    engine.setRate(Float(r))
                } label: {
                    HStack {
                        Text(String(format: "%.1fx", r))
                        if engine.rate == Float(r) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "speedometer").foregroundStyle(fg)
        }
    }

    private var sleepButton: some View {
        Button {
            showSleepTimer = true
        } label: {
            Image(systemName: engine.sleepEndsAt != nil ? "moon.fill" : "moon")
                .foregroundStyle(fg)
        }
    }

    private var karaokeToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showKaraoke.toggle()
            }
        } label: {
            Image(systemName: showKaraoke ? "text.alignleft" : "text.alignleft")
                .foregroundStyle(showKaraoke ? Color.accentColor : fg)
        }
    }

    private var reportButton: some View {
        Button {
            reportBadTranscript()
        } label: {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(fg)
        }
    }

    private func reportBadTranscript() {
        guard let audioURL = episode.audioURL else { return }
        var payload: [String: Any] = [
            "episodeID": episode.id,
            "audioURL": audioURL.absoluteString,
            "currentTime": engine.currentTime,
        ]
        if let t = episode.transcriptURL {
            payload["transcriptURL"] = t.absoluteString
        }
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let baseHost = audioURL.host else { return }
        var components = URLComponents()
        components.scheme = audioURL.scheme
        components.host = baseHost
        components.port = audioURL.port
        components.path = "/report"
        guard let reportURL = components.url else { return }
        var req = URLRequest(url: reportURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        Task {
            _ = try? await URLSession.shared.data(for: req)
            await TranscriptStore.shared.clearCache(for: episode.id)
            await MainActor.run {
                showReportConfirm = true
                // Wipe the in-memory segments so KaraokeView shows the
                // placeholder ("regenerating…") instead of stale text.
                self.segments = []
            }
            // Poll for the regenerated transcript: retranscribe with medium.en
            // takes 1-3 minutes for typical chapter lengths. Retry a handful
            // of times so the new subtitles appear without the user having
            // to back out of PlayerView.
            for delay in [45, 90, 180] {
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                if let segs = await TranscriptStore.shared.segments(for: episode), !segs.isEmpty {
                    await MainActor.run { self.segments = segs }
                    return
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: LinearGradient {
        if isBedtime {
            return LinearGradient(
                colors: [Color.bedtimeBgTop, Color.bedtimeBgBottom],
                startPoint: .top, endPoint: .bottom
            )
        }
        let tint = episode.level?.tint ?? Color.accentColor
        return LinearGradient(
            colors: [tint.opacity(0.4), Color.appBackground],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Loaders

    private func loadSegments() async {
        loadingTranscript = true
        defer { loadingTranscript = false }
        if let segs = await TranscriptStore.shared.segments(for: episode) {
            await MainActor.run { self.segments = segs }
        }
    }
}

private func timeString(_ sec: Double) -> String {
    guard sec.isFinite, sec >= 0 else { return "0:00" }
    let total = Int(sec)
    let m = total / 60
    let s = total % 60
    return String(format: "%d:%02d", m, s)
}
