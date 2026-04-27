import Foundation
import Observation

enum AppMode: String, CaseIterable, Codable, Sendable {
    case free, meal, bedtime

    var iconName: String {
        switch self {
        case .free:    "infinity"
        case .meal:    "fork.knife"
        case .bedtime: "moon.stars.fill"
        }
    }
}

@MainActor
@Observable
final class AppModeStore {
    @MainActor static let shared = AppModeStore()

    var current: AppMode = .free {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: "appMode")
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "appMode"),
           let mode = AppMode(rawValue: raw) {
            current = mode
        }
    }

    /// Whether the given duration matches the current mode's filter.
    func acceptsDuration(_ seconds: Int?) -> Bool {
        switch current {
        case .free:    return true
        case .meal:    return (seconds ?? 0) <= 15 * 60
        case .bedtime: return (seconds ?? 0) >= 15 * 60
        }
    }
}
