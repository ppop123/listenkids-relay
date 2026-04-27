import Foundation

final class RSSParser: NSObject, XMLParserDelegate {
    static func parse(_ data: Data) throws -> [RSSItem] {
        let p = RSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = p
        xml.shouldProcessNamespaces = false
        if !xml.parse(), let err = xml.parserError {
            throw err
        }
        return p.items
    }

    private var items: [RSSItem] = []
    private var current: RSSItem?
    private var buffer: String = ""

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        buffer = ""
        if elementName == "item" {
            current = RSSItem()
        }
        if elementName == "enclosure",
           current != nil,
           (attributeDict["type"] ?? "").hasPrefix("audio"),
           let urlStr = attributeDict["url"],
           let url = URL(string: urlStr) {
            current?.audioURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let s = String(data: CDATABlock, encoding: .utf8) {
            buffer.append(s)
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "item" {
            if let c = current { items.append(c) }
            current = nil
            return
        }
        guard current != nil else { return }

        switch elementName {
        case "title", "itunes:title":
            current?.title = value
        case "itunes:summary":
            current?.summary = value
        case "description":
            if current?.description == nil { current?.description = value }
        case "content:encoded":
            current?.description = value
        case "link":
            if let url = URL(string: value) { current?.link = url }
        case "pubDate":
            current?.pubDate = parseRFC822(value)
        case "guid":
            current?.guid = value
        case "itunes:duration":
            current?.duration = parseDuration(value)
        case "itunes:episodeType":
            current?.episodeType = value
        default:
            break
        }
    }
}

private func parseRFC822(_ raw: String) -> Date? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return f.date(from: raw)
}

private func parseDuration(_ raw: String) -> Int? {
    if let s = Int(raw) { return s }
    let parts = raw.split(separator: ":").compactMap { Int($0) }
    switch parts.count {
    case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
    case 2: return parts[0] * 60 + parts[1]
    case 1: return parts[0]
    default: return nil
    }
}
