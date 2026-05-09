import Foundation

/// Fetches Whisper-generated transcripts (with timestamps) from the NAS.
/// Mirrors the audio URL: `/audio/<name>.mp3` → `/transcripts/<name>.json`.
actor TranscriptStore {
    static let shared = TranscriptStore()

    private var cache: [String: [TranscriptSegment]] = [:]

    func clearCache(for episodeID: String) {
        cache.removeValue(forKey: episodeID)
    }

    func segments(for episode: Episode) async -> [TranscriptSegment]? {
        if let cached = cache[episode.id] { return cached }
        guard let url = transcriptURL(for: episode) else { return nil }
        // Bypass URLSession's local cache — the relay overwrites a transcript
        // when the kid taps "report bad subtitle", and we don't want a stale
        // 404 (or stale body) to mask the freshly-generated JSON.
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let transcript = try JSONDecoder().decode(WhisperTranscript.self, from: data)
            // Defensive sort by start time so KaraokeView's lastIndex lookup is correct
            // even if a source ever delivers segments out of order.
            let sorted = transcript.segments.sorted { $0.start < $1.start }
            cache[episode.id] = sorted
            return sorted
        } catch {
            return nil
        }
    }

    private func transcriptURL(for episode: Episode) -> URL? {
        guard let audioURL = episode.audioURL else { return nil }
        let basename = audioURL.deletingPathExtension().lastPathComponent
        var components = URLComponents(url: audioURL, resolvingAgainstBaseURL: false)
        components?.path = "/transcripts/\(basename).json"
        return components?.url
    }
}
