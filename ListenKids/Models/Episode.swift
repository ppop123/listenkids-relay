import Foundation
import SwiftData

@Model
final class Episode {
    // CloudKit-compatible: every property is optional or has a default; no @Attribute(.unique).
    // De-duplication happens in EpisodeSync via id lookup.
    var id: String = ""
    var sourceID: String = ""
    var title: String = ""
    var summary: String?
    var audioURL: URL?
    var pageURL: URL?
    var transcriptURL: URL?
    var publishedAt: Date = Date.distantPast
    var durationSeconds: Int?
    var levelRaw: String?
    var transcriptText: String?
    var localAudioPath: String?
    var playProgressSeconds: Double = 0
    var isFavorite: Bool = false
    var lastPlayedAt: Date?

    // Series grouping (set when this episode belongs to a multi-part series)
    var seriesID: String?
    var seriesTitle: String?
    var partNumber: Int?
    var partTotal: Int?
    var seriesAuthor: String?
    var seriesCoverURL: URL?

    /// Server-side classification: "story" (default for narrative listening),
    /// "lesson" (grammar / vocab tutorial), "exam" (exam prep).
    /// Series episodes inherit "story" from their parent series implicitly.
    var kind: String?

    init() {}

    var level: Level? { levelRaw.flatMap { Level(rawValue: $0) } }
}
