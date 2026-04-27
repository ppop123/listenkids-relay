import SwiftUI

struct FilterBar: View {
    @Binding var level: Level?
    @Binding var length: LengthBucket?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    label: "All",
                    isSelected: level == nil && length == nil
                ) {
                    level = nil
                    length = nil
                }
                ForEach(Level.allCases, id: \.self) { l in
                    FilterChip(
                        label: LocalizedStringKey(l.rawValue),
                        isSelected: level == l
                    ) {
                        level = (level == l) ? nil : l
                    }
                }
                Divider().frame(height: 18)
                FilterChip(label: "Short", isSelected: length == .short) {
                    length = (length == .short) ? nil : .short
                }
                FilterChip(label: "Medium", isSelected: length == .medium) {
                    length = (length == .medium) ? nil : .medium
                }
                FilterChip(label: "Long", isSelected: length == .long) {
                    length = (length == .long) ? nil : .long
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let label: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
