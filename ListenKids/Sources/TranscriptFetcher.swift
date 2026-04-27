import Foundation
import SwiftSoup

enum TranscriptFetcher {
    /// Fetch and extract transcript text from an episode page.
    /// Returns nil if no recognisable transcript content was found.
    static func fetch(pageURL: URL) async throws -> String? {
        let (data, response) = try await URLSession.shared.data(from: pageURL)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        let doc = try SwiftSoup.parse(html)

        // Try increasingly broad selectors. Practising English uses .w3-main
        // as the article container; others are tolerant fallbacks.
        let selectors = [".w3-main p", "article p", ".entry-content p", "main p"]
        for selector in selectors {
            let elements = try doc.select(selector).array()
            let parts = elements
                .compactMap { try? $0.text() }
                .filter { $0.split(separator: " ").count >= 5 }
            if parts.count >= 3 {
                return parts.joined(separator: "\n\n")
            }
        }
        return nil
    }
}
