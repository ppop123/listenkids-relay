import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(
        filter: #Predicate<Episode> { $0.isFavorite },
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
        .navigationTitle("Favorites")
        .overlay {
            if episodes.isEmpty {
                ContentUnavailableView(
                    "No favorites yet",
                    systemImage: "star",
                    description: Text("Swipe right on any episode to favorite")
                )
            }
        }
    }
}

#Preview {
    NavigationStack { FavoritesView() }
        .modelContainer(for: [Episode.self], inMemory: true)
}
