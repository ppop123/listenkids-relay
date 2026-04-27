import Foundation

struct PractisingEnglish: ContentSource {
    let sourceID = "practising-english"
    let displayName = "Practising English"
    let feedURL = URL(string: "https://feeds.buzzsprout.com/1783332.rss")!

    func fetchEpisodes() async throws -> [FetchedEpisode] {
        let (data, _) = try await URLSession.shared.data(from: feedURL)
        let items = try RSSParser.parse(data)
        return items.compactMap { item -> FetchedEpisode? in
            guard let audio = item.audioURL else { return nil }
            if let t = item.episodeType, t != "full" { return nil }
            let id = item.guid ?? audio.absoluteString
            let level = Level.parse(from: item.title)?.rawValue
            return FetchedEpisode(
                id: id,
                title: item.title,
                summary: item.summary,
                audioURL: audio,
                pageURL: item.link,
                publishedAt: item.pubDate ?? Date(),
                durationSeconds: item.duration,
                levelRaw: level
            )
        }
    }
}
