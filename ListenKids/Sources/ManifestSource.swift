import Foundation

/// Single content source that reads the unified `manifest.json` produced by
/// the home server, exposing both Practising English (RSS-derived) and Roald
/// Dahl (filesystem-scanned) episodes through one channel.
struct ManifestSource: ContentSource {
    let sourceID = "manifest"
    let displayName = "ListenKids Library"
    let manifestURL: URL

    init(baseURL: URL = URL(string: "http://192.168.50.8:18000")!) {
        self.manifestURL = baseURL.appendingPathComponent("manifest.json")
    }

    func fetchEpisodes() async throws -> [FetchedEpisode] {
        let (data, _) = try await URLSession.shared.data(from: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        var episodes: [FetchedEpisode] = []

        for s in manifest.series {
            let total = s.parts.count
            let coverURL = s.cover.flatMap { URL(string: $0) }
            for part in s.parts {
                guard let audioURL = URL(string: part.audioURL) else { continue }
                episodes.append(FetchedEpisode(
                    id: part.id,
                    sourceID: s.sourceID,
                    title: part.title,
                    summary: part.rawTitle,
                    audioURL: audioURL,
                    pageURL: part.pageURL.flatMap { URL(string: $0) },
                    transcriptURL: part.transcriptURL.flatMap { URL(string: $0) },
                    publishedAt: part.publishedAt.flatMap(parseDate) ?? .distantPast,
                    durationSeconds: part.durationSeconds,
                    levelRaw: part.level ?? s.level,
                    seriesID: s.id,
                    seriesTitle: s.title,
                    partNumber: part.partNumber,
                    partTotal: total,
                    seriesAuthor: s.author,
                    seriesCoverURL: coverURL,
                    seriesPopularity: s.popularity,
                    kind: "story"
                ))
            }
        }

        for ep in manifest.episodes {
            guard let audioURL = URL(string: ep.audioURL) else { continue }
            episodes.append(FetchedEpisode(
                id: ep.id,
                sourceID: ep.sourceID,
                title: ep.title,
                summary: ep.rawTitle,
                audioURL: audioURL,
                pageURL: ep.pageURL.flatMap { URL(string: $0) },
                transcriptURL: ep.transcriptURL.flatMap { URL(string: $0) },
                publishedAt: ep.publishedAt.flatMap(parseDate) ?? .distantPast,
                durationSeconds: ep.durationSeconds,
                levelRaw: ep.level,
                seriesID: nil,
                seriesTitle: nil,
                partNumber: nil,
                partTotal: nil,
                seriesAuthor: nil,
                seriesCoverURL: nil,
                seriesPopularity: nil,
                kind: ep.kind ?? "story"
            ))
        }

        return episodes
    }
}

// MARK: - JSON shapes

private struct Manifest: Decodable {
    let version: Int
    let publicBase: String?
    let series: [SeriesItem]
    let episodes: [EpisodeItem]
}

private struct SeriesItem: Decodable {
    let id: String
    let sourceID: String
    let title: String
    let author: String?
    let level: String?
    let cover: String?
    let popularity: Int?
    let parts: [PartItem]
}

private struct PartItem: Decodable {
    let id: String
    let partNumber: Int?
    let title: String
    let rawTitle: String?
    let audioURL: String
    let pageURL: String?
    let transcriptURL: String?
    let publishedAt: String?
    let durationSeconds: Int?
    let level: String?
}

private struct EpisodeItem: Decodable {
    let id: String
    let sourceID: String
    let title: String
    let rawTitle: String?
    let episodeNumber: Int?
    let audioURL: String
    let pageURL: String?
    let transcriptURL: String?
    let publishedAt: String?
    let durationSeconds: Int?
    let level: String?
    let kind: String?
}

private func parseDate(_ s: String) -> Date? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return f.date(from: s)
}
