import Foundation

enum Level: String, Codable, CaseIterable, Sendable {
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"

    /// Try to extract a CEFR level token from a free-text source
    /// (e.g. an episode title like "B1 - Story about ...").
    static func parse(from raw: String) -> Level? {
        let upper = raw.uppercased()
        for level in Self.allCases where upper.contains(level.rawValue) {
            return level
        }
        return nil
    }
}
