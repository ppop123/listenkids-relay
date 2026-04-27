import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Episode.publishedAt, order: .reverse) private var allEpisodes: [Episode]
    @State private var levelFilter: Level?
    @State private var lengthFilter: LengthBucket?
    @State private var isRefreshing = false
    @State private var modeStore = AppModeStore.shared

    var body: some View {
        VStack(spacing: 0) {
            FilterBar(level: $levelFilter, length: $lengthFilter)
                .padding(.vertical, 8)
            List {
                if !continueListening.isEmpty {
                    Section("Continue listening") {
                        ForEach(continueListening) { ep in
                            row(ep)
                        }
                    }
                }
                Section {
                    ForEach(filteredEpisodes) { ep in
                        row(ep)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("ListenKids")
        .refreshable { await refresh() }
        .task {
            DownloadManager.shared.attach(context: context)
            if allEpisodes.isEmpty {
                await refresh()
            }
        }
        .overlay {
            if allEpisodes.isEmpty && !isRefreshing {
                ContentUnavailableView(
                    "No episodes yet",
                    systemImage: "headphones",
                    description: Text("Pull down to refresh")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ModeSwitcher()
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    FavoritesView()
                } label: {
                    Image(systemName: "star")
                }
                NavigationLink {
                    HistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                if isRefreshing {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ ep: Episode) -> some View {
        NavigationLink {
            PlayerView(episode: ep)
        } label: {
            EpisodeRow(episode: ep)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                ep.isFavorite.toggle()
                try? context.save()
            } label: {
                Label(ep.isFavorite ? "Unstar" : "Star", systemImage: "star.fill")
            }
            .tint(.yellow)
        }
    }

    private var continueListening: [Episode] {
        Array(
            allEpisodes
                .filter { ep in
                    guard ep.playProgressSeconds > 5 else { return false }
                    if let dur = ep.durationSeconds {
                        return Double(dur) - ep.playProgressSeconds > 30
                    }
                    return true
                }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
                .prefix(3)
        )
    }

    private var filteredEpisodes: [Episode] {
        allEpisodes.filter { ep in
            if let l = levelFilter, ep.level != l { return false }
            if let bucket = lengthFilter, !bucket.contains(seconds: ep.durationSeconds) { return false }
            if !modeStore.acceptsDuration(ep.durationSeconds) { return false }
            return true
        }
    }

    private func refresh() async {
        isRefreshing = true
        await EpisodeSync.refresh(context: context, source: PractisingEnglish())
        isRefreshing = false
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: [Episode.self], inMemory: true)
}
