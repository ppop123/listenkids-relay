import Foundation
import SwiftData

@MainActor
enum EpisodeSync {
    static func refresh(context: ModelContext, source: any ContentSource) async {
        do {
            let fetched = try await source.fetchEpisodes()
            let sourceID = source.sourceID
            let descriptor = FetchDescriptor<Episode>(
                predicate: #Predicate { $0.sourceID == sourceID }
            )
            let existing = (try? context.fetch(descriptor)) ?? []
            let byID: [String: Episode] = Dictionary(
                existing.map { ($0.id, $0) },
                uniquingKeysWith: { a, _ in a }
            )

            for f in fetched {
                if let ep = byID[f.id] {
                    ep.title = f.title
                    ep.summary = f.summary
                    ep.durationSeconds = f.durationSeconds
                    ep.levelRaw = f.levelRaw
                    ep.pageURL = f.pageURL
                } else {
                    let ep = Episode(
                        id: f.id,
                        sourceID: sourceID,
                        title: f.title,
                        summary: f.summary,
                        audioURL: f.audioURL,
                        pageURL: f.pageURL,
                        publishedAt: f.publishedAt,
                        durationSeconds: f.durationSeconds,
                        levelRaw: f.levelRaw
                    )
                    context.insert(ep)
                }
            }
            try? context.save()
        } catch {
            print("EpisodeSync error: \(error)")
        }
    }
}
