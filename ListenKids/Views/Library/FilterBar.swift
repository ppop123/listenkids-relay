import SwiftUI

struct FilterBar: View {
    @Binding var level: Level?
    @Binding var length: LengthBucket?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    isSelected: level == nil && length == nil,
                    tint: Color.accentColor
                ) {
                    level = nil
                    length = nil
                }
                ForEach(Level.allCases, id: \.self) { l in
                    FilterChip(
                        label: LocalizedStringKey(l.rawValue),
                        isSelected: level == l,
                        tint: l.tint
                    ) {
                        level = (level == l) ? nil : l
                    }
                }
                Divider().frame(height: 18).padding(.horizontal, 4)
                FilterChip(label: "Short", isSelected: length == .short, tint: .accentColor) {
                    length = (length == .short) ? nil : .short
                }
                FilterChip(label: "Medium", isSelected: length == .medium, tint: .accentColor) {
                    length = (length == .medium) ? nil : .medium
                }
                FilterChip(label: "Long", isSelected: length == .long, tint: .accentColor) {
                    length = (length == .long) ? nil : .long
                }
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct FilterChip: View {
    let label: LocalizedStringKey
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.rounded(13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.appInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? tint : Color.white.opacity(0.7))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.black.opacity(isSelected ? 0 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
