import SwiftUI
import SwiftData

struct DownloadsView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Episode> { $0.localAudioPath != nil },
        sort: \Episode.publishedAt,
        order: .reverse
    )
    private var downloaded: [Episode]

    var body: some View {
        List {
            ForEach(downloaded) { ep in
                NavigationLink {
                    PlayerView(episode: ep)
                } label: {
                    EpisodeRow(episode: ep)
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Downloads")
        .overlay {
            if downloaded.isEmpty {
                ContentUnavailableView(
                    "No downloads",
                    systemImage: "arrow.down.circle",
                    description: Text("Tap the download icon on any episode")
                )
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets {
            DownloadManager.shared.deleteDownload(episode: downloaded[idx])
        }
    }
}

#Preview {
    NavigationStack {
        DownloadsView()
    }
    .modelContainer(for: [Episode.self], inMemory: true)
}
