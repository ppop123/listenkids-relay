import Foundation

struct TranscriptSegment: Identifiable, Decodable, Sendable, Hashable {
    let start: Double
    let end: Double
    let text: String

    var id: String { "\(start)-\(end)" }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WhisperTranscript: Decodable, Sendable {
    let text: String
    let language: String?
    let segments: [TranscriptSegment]
}
