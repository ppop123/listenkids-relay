import Foundation

protocol ContentSource: Sendable {
    var sourceID: String { get }
    var displayName: String { get }
    func fetchEpisodes() async throws -> [FetchedEpisode]
}

struct FetchedEpisode: Sendable {
    var id: String
    var sourceID: String
    var title: String
    var summary: String?
    var audioURL: URL
    var pageURL: URL?
    var transcriptURL: URL?
    var publishedAt: Date
    var durationSeconds: Int?
    var levelRaw: String?
    var seriesID: String?
    var seriesTitle: String?
    var partNumber: Int?
    var partTotal: Int?
    var seriesAuthor: String?
    var seriesCoverURL: URL?
    var seriesPopularity: Int?
    var kind: String?
}
