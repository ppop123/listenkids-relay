import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(
        filter: #Predicate<Episode> { $0.lastPlayedAt != nil },
        sort: \Episode.lastPlayedAt,
        order: .reverse
    )
    private var episodes: [Episode]

    var body: some View {
        List(episodes) { ep in
            NavigationLink {
                PlayerView(episode: ep)
            } label: {
                EpisodeRow(episode: ep)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
        .overlay {
            if episodes.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Episodes you’ve started will appear here")
                )
            }
        }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .modelContainer(for: [Episode.self], inMemory: true)
}
