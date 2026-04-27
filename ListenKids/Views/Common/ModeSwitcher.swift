import SwiftUI

struct ModeSwitcher: View {
    @State private var store = AppModeStore.shared

    var body: some View {
        Picker(
            "Mode",
            selection: Binding(
                get: { store.current },
                set: { store.current = $0 }
            )
        ) {
            ForEach(AppMode.allCases, id: \.self) { m in
                Image(systemName: m.iconName).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 160)
    }
}
