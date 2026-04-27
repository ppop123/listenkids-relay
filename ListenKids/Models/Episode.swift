import Foundation
import SwiftData

@Model
final class Episode {
    // CloudKit-compatible: every non-relationship property must be optional
    // or have a default value, and no @Attribute(.unique). De-duplication
    // is done in code via fetch-by-id before insert.
    var id: String = ""
    var sourceID: String = ""
    var title: String = ""
    var summary: String?
    var audioURL: URL?
    var pageURL: URL?
    var publishedAt: Date = Date.distantPast
    var durationSeconds: Int?
    var levelRaw: String?
    var transcriptText: String?
    var localAudioPath: String?
    var playProgressSeconds: Double = 0
    var isFavorite: Bool = false
    var lastPlayedAt: Date?

    init(
        id: String,
        sourceID: String,
        title: String,
        summary: String? = nil,
        audioURL: URL,
        pageURL: URL? = nil,
        publishedAt: Date,
        durationSeconds: Int? = nil,
        levelRaw: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.summary = summary
        self.audioURL = audioURL
        self.pageURL = pageURL
        self.publishedAt = publishedAt
        self.durationSeconds = durationSeconds
        self.levelRaw = levelRaw
    }

    var level: Level? { levelRaw.flatMap { Level(rawValue: $0) } }
}
