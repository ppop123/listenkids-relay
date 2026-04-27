import SwiftUI
import SwiftData

struct PlayerView: View {
    let episode: Episode
    @Environment(\.modelContext) private var context
    @State private var engine = PlayerEngine()
    @State private var modeStore = AppModeStore.shared
    @State private var showSleepTimer = false
    @State private var showTranscript = false
    @State private var loadingTranscript = false
    @State private var transcriptError: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(.tint)
                Text(episode.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(modeStore.current == .bedtime ? .white : .primary)
                if let level = episode.level {
                    Text(level.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.18))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)

            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { engine.currentTime },
                        set: { engine.seek(to: $0) }
                    ),
                    in: 0...max(engine.duration, 1)
                )
                HStack {
                    Text(timeString(engine.currentTime))
                    Spacer()
                    Text("-" + timeString(max(engine.duration - engine.currentTime, 0)))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(modeStore.current == .bedtime
                    ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal)

            HStack(spacing: 48) {
                Button { engine.skip(by: -15) } label: {
                    Image(systemName: "gobackward.15").font(.system(size: 32))
                }
                Button { engine.togglePlayPause() } label: {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                }
                Button { engine.skip(by: 15) } label: {
                    Image(systemName: "goforward.15").font(.system(size: 32))
                }
            }
            .tint(.accentColor)

            if let end = engine.sleepEndsAt {
                Label {
                    Text("Sleep at \(end.formatted(.dateTime.hour().minute()))")
                } icon: {
                    Image(systemName: "moon.stars.fill")
                }
                .font(.caption)
                .foregroundStyle(modeStore.current == .bedtime
                    ? .white.opacity(0.7) : .secondary)
            }

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(modeBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                favoriteButton
                speedMenu
                sleepButton
                transcriptButton
            }
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet(engine: engine)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTranscript) {
            transcriptSheet
        }
        .task {
            engine.load(episode: episode, context: context)
            if modeStore.current == .bedtime && engine.sleepEndsAt == nil {
                engine.startSleepTimer(seconds: 30 * 60)
            }
            UIApplication.shared.isIdleTimerDisabled = (modeStore.current == .meal)
        }
        .onDisappear {
            engine.saveProgress()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var modeBackground: Color {
        switch modeStore.current {
        case .bedtime: Color(red: 0.05, green: 0.02, blue: 0.0)
        default:       Color(.systemGroupedBackground)
        }
    }

    private var favoriteButton: some View {
        Button {
            episode.isFavorite.toggle()
            try? context.save()
        } label: {
            Image(systemName: episode.isFavorite ? "star.fill" : "star")
                .foregroundStyle(episode.isFavorite ? .yellow : .accentColor)
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
            Image(systemName: "speedometer")
        }
    }

    private var sleepButton: some View {
        Button {
            showSleepTimer = true
        } label: {
            Image(systemName: engine.sleepEndsAt != nil ? "moon.fill" : "moon")
        }
    }

    private var transcriptButton: some View {
        Button {
            Task { await loadTranscriptIfNeeded() }
            showTranscript = true
        } label: {
            Image(systemName: "text.alignleft")
        }
    }

    @ViewBuilder
    private var transcriptSheet: some View {
        NavigationStack {
            if let text = episode.transcriptText, !text.isEmpty {
                TranscriptView(text: text)
            } else if loadingTranscript {
                ProgressView()
                    .navigationTitle("Transcript")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Transcript not available",
                    systemImage: "text.alignleft",
                    description: Text(transcriptError ?? "")
                )
                .navigationTitle("Transcript")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .presentationDetents([.large])
    }

    private func loadTranscriptIfNeeded() async {
        if let t = episode.transcriptText, !t.isEmpty { return }
        guard let url = episode.pageURL else {
            transcriptError = "No page URL for this episode"
            return
        }
        loadingTranscript = true
        defer { loadingTranscript = false }
        do {
            if let text = try await TranscriptFetcher.fetch(pageURL: url) {
                episode.transcriptText = text
                try? context.save()
            } else {
                transcriptError = "Could not extract transcript"
            }
        } catch {
            transcriptError = error.localizedDescription
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
