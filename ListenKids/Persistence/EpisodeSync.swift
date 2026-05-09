import Foundation
import SwiftData

@MainActor
enum EpisodeSync {
    static func refresh(context: ModelContext, source: any ContentSource) async {
        do {
            let fetched = try await source.fetchEpisodes()
            let existing = (try? context.fetch(FetchDescriptor<Episode>())) ?? []
            let byID: [String: Episode] = Dictionary(
                existing.map { ($0.id, $0) },
                uniquingKeysWith: { a, _ in a }
            )

            for f in fetched {
                let ep = byID[f.id] ?? {
                    let new = Episode()
                    new.id = f.id
                    new.publishedAt = f.publishedAt
                    context.insert(new)
                    return new
                }()
                ep.sourceID = f.sourceID
                ep.title = f.title
                ep.summary = f.summary
                ep.audioURL = f.audioURL
                ep.pageURL = f.pageURL
                ep.transcriptURL = f.transcriptURL
                ep.durationSeconds = f.durationSeconds
                ep.levelRaw = f.levelRaw
                ep.seriesID = f.seriesID
                ep.seriesTitle = f.seriesTitle
                ep.partNumber = f.partNumber
                ep.partTotal = f.partTotal
                ep.seriesAuthor = f.seriesAuthor
                ep.seriesCoverURL = f.seriesCoverURL
                ep.seriesPopularity = f.seriesPopularity
                ep.kind = f.kind
            }
            try? context.save()
        } catch {
            print("EpisodeSync error: \(error)")
        }
    }
}
