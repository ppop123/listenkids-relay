import Foundation

protocol ContentSource: Sendable {
    var sourceID: String { get }
    var displayName: String { get }
    func fetchEpisodes() async throws -> [FetchedEpisode]
}

struct FetchedEpisode: Sendable, Equatable {
    var id: String
    var title: String
    var summary: String?
    var audioURL: URL
    var pageURL: URL?
    var publishedAt: Date
    var durationSeconds: Int?
    var levelRaw: String?
}
