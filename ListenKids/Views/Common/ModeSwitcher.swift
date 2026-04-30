import SwiftUI

struct ModeSwitcher: View {
    @State private var store = AppModeStore.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppMode.allCases, id: \.self) { m in
                pill(for: m)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.6))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func pill(for mode: AppMode) -> some View {
        let active = store.current == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                store.current = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 13, weight: .semibold))
                Text(mode.label)
                    .font(.rounded(13, weight: .semibold))
            }
            .foregroundStyle(active ? Color.white : Color.appInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(active ? mode.tint : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
