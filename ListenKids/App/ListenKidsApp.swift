import SwiftUI
import SwiftData

@main
struct ListenKidsApp: App {
    init() {
        // Trigger DownloadManager singleton init so background URLSession delegate is registered.
        _ = DownloadManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Episode.self])
    }
}
