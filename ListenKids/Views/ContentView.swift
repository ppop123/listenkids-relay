import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular {
            PadShell()
        } else {
            PhoneShell()
        }
    }
}

private struct PhoneShell: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                DownloadsView()
            }
            .tabItem { Label("Downloads", systemImage: "arrow.down.circle.fill") }
        }
    }
}

private struct PadShell: View {
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.label, systemImage: item.icon)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.vertical, 4)
                        .tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ListenKids")
        } detail: {
            NavigationStack {
                switch selection ?? .home {
                case .home:      HomeView()
                case .downloads: DownloadsView()
                case .favorites: FavoritesView()
                case .history:   HistoryView()
                }
            }
        }
    }
}

private enum SidebarItem: String, Hashable, Identifiable, CaseIterable {
    case home, downloads, favorites, history
    var id: String { rawValue }
    var label: LocalizedStringKey {
        switch self {
        case .home:      "Home"
        case .downloads: "Downloads"
        case .favorites: "Favorites"
        case .history:   "History"
        }
    }
    var icon: String {
        switch self {
        case .home:      "house.fill"
        case .downloads: "arrow.down.circle.fill"
        case .favorites: "star.fill"
        case .history:   "clock.arrow.circlepath"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self], inMemory: true)
}
