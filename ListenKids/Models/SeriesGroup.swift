import Foundation
import SwiftUI

/// In-memory grouping of episodes that share a `seriesID`.
struct SeriesGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let author: String?
    let level: Level?
    let coverURL: URL?
    let sourceID: String
    let popularity: Int
    let episodes: [Episode]

    var totalDurationSeconds: Int {
        episodes.compactMap(\.durationSeconds).reduce(0, +)
    }

    var partsLabel: LocalizedStringKey {
        "\(episodes.count) parts"
    }

    static func == (lhs: SeriesGroup, rhs: SeriesGroup) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Array where Element == Episode {
    /// Splits episodes into series groups + standalone episodes.
    func groupedSeries() -> (series: [SeriesGroup], standalone: [Episode]) {
        var bucket: [String: [Episode]] = [:]
        var standalone: [Episode] = []
        for ep in self {
            if let sid = ep.seriesID {
                bucket[sid, default: []].append(ep)
            } else {
                standalone.append(ep)
            }
        }
        let groups: [SeriesGroup] = bucket.values.compactMap { eps in
            guard let first = eps.first else { return nil }
            return SeriesGroup(
                id: first.seriesID ?? "",
                title: first.seriesTitle ?? first.title,
                author: first.seriesAuthor,
                level: first.level,
                coverURL: first.seriesCoverURL,
                sourceID: first.sourceID,
                popularity: first.seriesPopularity ?? 0,
                episodes: eps.sorted { ($0.partNumber ?? 0) < ($1.partNumber ?? 0) }
            )
        }
        return (groups, standalone)
    }
}
