import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Episode.publishedAt, order: .reverse) private var allEpisodes: [Episode]
    @State private var modeStore = AppModeStore.shared
    @State private var isRefreshing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ModeSwitcher()
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                if !continueListening.isEmpty {
                    section("Continue listening") {
                        VStack(spacing: 8) {
                            ForEach(continueListening) { ep in
                                NavigationLink {
                                    PlayerView(episode: ep)
                                } label: {
                                    EpisodeRow(episode: ep)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                ForEach(seriesGroups, id: \.titleKey) { group in
                    section(LocalizedStringKey(group.titleKey)) {
                        carousel(group.list)
                    }
                }

                if !filteredStandalone.isEmpty {
                    section("Stories") {
                        VStack(spacing: 8) {
                            ForEach(filteredStandalone.prefix(20)) { ep in
                                NavigationLink {
                                    PlayerView(episode: ep)
                                } label: {
                                    EpisodeRow(episode: ep)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 60)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Listen Up")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await refresh() }
        .task {
            DownloadManager.shared.attach(context: context)
            // Always refresh manifest on appear so newly generated covers /
            // newly added series flow in without the user pull-to-refreshing.
            await refresh()
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
    private func section<Content: View>(_ title: LocalizedStringKey,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .padding(.horizontal, 20)
            content()
        }
    }

    @ViewBuilder
    private func carousel(_ list: [SeriesGroup]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(list) { s in
                    NavigationLink {
                        CollectionDetailView(series: s)
                    } label: {
                        SeriesCard(series: s)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Derived data

    private var grouped: (series: [SeriesGroup], standalone: [Episode]) {
        allEpisodes.groupedSeries()
    }

    private var seriesGroups: [(titleKey: String, list: [SeriesGroup])] {
        let buckets: [(String, [SeriesGroup])] = [
            ("Roald Dahl",                  pickFor("roald-dahl")),
            ("Bilibili",                    pickFor("bilibili")),
            ("LibriVox Classics",           pickFor("librivox")),
            ("Practising English Stories",  pickFor("practising-english")),
        ]
        return buckets
            .filter { !$0.1.isEmpty }
            .map { (titleKey: $0.0, list: $0.1) }
    }

    /// Filter by source + current mode, then sort by popularity (DESC) so the
    /// best-known stories surface first; ties broken by title alpha for stability.
    private func pickFor(_ sourceID: String) -> [SeriesGroup] {
        grouped.series
            .filter { $0.sourceID == sourceID }
            .filter { modeAccepts($0) }
            .sorted { (a, b) in
                if a.popularity != b.popularity { return a.popularity > b.popularity }
                return a.title < b.title
            }
    }

    private var filteredStandalone: [Episode] {
        grouped.standalone
            .filter { ($0.kind ?? "story") == "story" }   // hide lessons + exam from home
            .filter { modeStore.acceptsDuration($0.durationSeconds) }
            .sorted { $0.publishedAt > $1.publishedAt }
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

    /// A series passes the current mode if at least one of its parts matches.
    private func modeAccepts(_ s: SeriesGroup) -> Bool {
        switch modeStore.current {
        case .free: return true
        default:
            return s.episodes.contains { modeStore.acceptsDuration($0.durationSeconds) }
        }
    }

    private func refresh() async {
        isRefreshing = true
        await EpisodeSync.refresh(context: context, source: ManifestSource())
        isRefreshing = false
    }
}

#Preview {
    NavigationStack { HomeView() }
        .modelContainer(for: [Episode.self], inMemory: true)
}
