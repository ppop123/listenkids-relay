import SwiftUI

// MARK: - Palette

extension Color {
    static let appBackground = Color(red: 0.957, green: 0.945, blue: 0.910)   // cream
    static let appSurface    = Color.white
    static let appInk        = Color(red: 0.173, green: 0.141, blue: 0.094)   // dark warm
    static let appMuted      = Color(red: 0.502, green: 0.471, blue: 0.400)   // warm gray
    static let appCardShadow = Color.black.opacity(0.05)

    static let levelA2 = Color(red: 0.357, green: 0.749, blue: 0.659)         // mint
    static let levelB1 = Color(red: 0.361, green: 0.624, blue: 0.890)         // sky
    static let levelB2 = Color(red: 0.910, green: 0.604, blue: 0.278)         // sunset
    static let levelC1 = Color(red: 0.608, green: 0.435, blue: 0.737)         // plum

    static let modeFreeColor    = Color(red: 0.361, green: 0.624, blue: 0.890)
    static let modeMealColor    = Color(red: 0.890, green: 0.482, blue: 0.176)
    static let modeBedtimeColor = Color(red: 0.420, green: 0.310, blue: 0.549)

    static let bedtimeBgTop    = Color(red: 0.063, green: 0.043, blue: 0.118)
    static let bedtimeBgBottom = Color(red: 0.157, green: 0.118, blue: 0.227)
}

// MARK: - Level extension

extension Level {
    var tint: Color {
        switch self {
        case .a2: .levelA2
        case .b1: .levelB1
        case .b2: .levelB2
        case .c1: .levelC1
        }
    }
}

// MARK: - AppMode extension

extension AppMode {
    var tint: Color {
        switch self {
        case .free:    .modeFreeColor
        case .meal:    .modeMealColor
        case .bedtime: .modeBedtimeColor
        }
    }
    var label: LocalizedStringKey {
        switch self {
        case .free:    "Free"
        case .meal:    "Meal"
        case .bedtime: "Bedtime"
        }
    }
}

// MARK: - Episode helpers

extension Episode {
    /// Episode number from a title prefixed like "306. ..."
    var displayNumber: String? {
        if let m = title.range(of: #"^\d+"#, options: .regularExpression) {
            return String(title[m])
        }
        return nil
    }

    /// Title with leading "306. " and trailing "(B1 story)"-style suffix stripped.
    var displayTitle: String {
        var t = title
        if let m = t.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
            t = String(t[m.upperBound...])
        }
        if let m = t.range(of: #"\s*\([^)]*\)\s*$"#, options: .regularExpression) {
            let inside = String(t[m]).lowercased()
            if inside.contains("story") || inside.contains("a2") || inside.contains("b1") || inside.contains("b2") || inside.contains("c1") {
                t = String(t[..<m.lowerBound])
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Font helper

extension Font {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
