import Foundation

enum LengthBucket: String, CaseIterable, Identifiable, Sendable {
    case short, medium, long

    var id: String { rawValue }

    func contains(seconds: Int?) -> Bool {
        guard let s = seconds else { return false }
        let m = s / 60
        switch self {
        case .short:  return m <= 10
        case .medium: return m > 10 && m <= 20
        case .long:   return m > 20
        }
    }
}
