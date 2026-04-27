import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DownloadManager: NSObject {
    @MainActor static let shared = DownloadManager()

    var progress: [String: Double] = [:]

    @ObservationIgnored private var session: URLSession!
    @ObservationIgnored private var tasks: [String: URLSessionDownloadTask] = [:]
    @ObservationIgnored private weak var contextRef: ModelContext?

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.simiaowang.listenkids.downloads"
        )
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func attach(context: ModelContext) {
        contextRef = context
    }

    func startDownload(episode: Episode) {
        guard let url = episode.audioURL,
              episode.localAudioPath == nil,
              tasks[episode.id] == nil else { return }
        let task = session.downloadTask(with: url)
        task.taskDescription = episode.id
        tasks[episode.id] = task
        progress[episode.id] = 0
        task.resume()
    }

    func deleteDownload(episode: Episode) {
        guard let filename = episode.localAudioPath else { return }
        let url = Self.audioFileURL(for: filename)
        try? FileManager.default.removeItem(at: url)
        episode.localAudioPath = nil
        try? contextRef?.save()
    }

    func handleCompletion(id: String, filename: String) {
        progress.removeValue(forKey: id)
        tasks.removeValue(forKey: id)
        guard let ctx = contextRef else { return }
        let descriptor = FetchDescriptor<Episode>(
            predicate: #Predicate { $0.id == id }
        )
        guard let episode = (try? ctx.fetch(descriptor))?.first else { return }
        episode.localAudioPath = filename
        try? ctx.save()
    }

    static func audioFileURL(for filename: String) -> URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("audio", isDirectory: true)
        return dir.appendingPathComponent(filename)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = downloadTask.taskDescription else { return }
        let safeID = id.replacingOccurrences(of: "/", with: "_")
        let filename = "\(safeID).mp3"
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            print("download move failed: \(error)")
            return
        }
        Task { @MainActor in
            DownloadManager.shared.handleCompletion(id: id, filename: filename)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = downloadTask.taskDescription else { return }
        let p = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        Task { @MainActor in
            DownloadManager.shared.progress[id] = p
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let id = task.taskDescription else { return }
        if let error {
            print("download error for \(id): \(error)")
        }
        Task { @MainActor in
            DownloadManager.shared.tasks.removeValue(forKey: id)
        }
    }
}
