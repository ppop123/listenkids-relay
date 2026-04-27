import Foundation

struct RSSItem {
    var title: String = ""
    var summary: String?
    var description: String?
    var link: URL?
    var audioURL: URL?
    var pubDate: Date?
    var guid: String?
    var duration: Int?
    var episodeType: String?
}
