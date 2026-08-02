import Foundation

struct XMLTVParser: Sendable {
    struct ParsedProgram {
        let channelID: String
        let startTime: Date?
        let endTime: Date?
        let title: String
        let subtitle: String?
        let desc: String?
        let category: String?
        let language: String?
        let iconSrc: String?
        let feedID: String?
    }

    static func parse(data: Data, feedID: String? = nil) -> [ParsedProgram] {
        let parser = XMLParser(data: data)
        let delegate = XMLTVParserDelegate(feedID: feedID)
        parser.delegate = delegate
        let success = parser.parse()
        let count = delegate.programs.count
        print("EPG XML: parse success=\(success), programs=\(count), dataBytes=\(data.count)")
        return delegate.programs
    }
}

private final class XMLTVParserDelegate: NSObject, XMLParserDelegate {
    let feedID: String?
    private(set) var programs: [XMLTVParser.ParsedProgram] = []
    private var currentElement = ""
    private var currentChannelID: String?
    private var startTime: Date?
    private var endTime: Date?
    private var currentTitle: String?
    private var currentSubtitle: String?
    private var currentDesc: String?
    private var currentCategory: String?
    private var currentLanguage: String?
    private var currentIconSrc: String?
    private var foundTitle = false
    private var foundSubtitle = false
    private var foundDesc = false
    private var foundCategory = false
    private var foundLanguage = false
    private var pendingLanguage: String?

    init(feedID: String?) {
        self.feedID = feedID
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qname: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "programme" {
            currentChannelID = attributeDict["channel"]
            startTime = parseDate(from: attributeDict["start"])
            endTime = parseDate(from: attributeDict["stop"])
            currentTitle = nil
            currentSubtitle = nil
            currentDesc = nil
            currentCategory = nil
            currentLanguage = nil
            currentIconSrc = nil
            pendingLanguage = attributeDict["lang"]
            foundTitle = false
            foundSubtitle = false
            foundDesc = false
            foundCategory = false
            foundLanguage = false
        } else if elementName == "title" {
            pendingLanguage = attributeDict["lang"]
        } else if elementName == "sub-title" {
            pendingLanguage = attributeDict["lang"]
        } else if elementName == "desc" {
            pendingLanguage = attributeDict["lang"]
        } else if elementName == "category" {
            pendingLanguage = attributeDict["lang"]
        } else if elementName == "language" {
            pendingLanguage = attributeDict["lang"]
        } else if elementName == "icon" {
            currentIconSrc = attributeDict["src"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title" where !foundTitle:
            currentTitle = (currentTitle ?? "") + trimmed
        case "sub-title" where !foundSubtitle:
            currentSubtitle = (currentSubtitle ?? "") + trimmed
        case "desc" where !foundDesc:
            currentDesc = (currentDesc ?? "") + trimmed
        case "category" where !foundCategory:
            currentCategory = (currentCategory ?? "") + trimmed
        case "language" where !foundLanguage:
            currentLanguage = (currentLanguage ?? "") + trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qname: String?) {
        if elementName == "title" {
            if let title = currentTitle, !title.isEmpty {
                if !foundTitle {
                    foundTitle = true
                } else {
                    currentSubtitle = title
                    foundSubtitle = true
                }
            }
        } else if elementName == "desc" {
            foundDesc = true
        } else if elementName == "category" {
            foundCategory = true
        } else if elementName == "language" {
            foundLanguage = true
        } else if elementName == "programme" {
            guard let channelID = currentChannelID,
                  let startTime = startTime,
                  let endTime = endTime,
                  let title = currentTitle, !title.isEmpty
            else {
                return
            }

            programs.append(XMLTVParser.ParsedProgram(
                channelID: channelID,
                startTime: startTime,
                endTime: endTime,
                title: title,
                subtitle: currentSubtitle.isNilOrEmpty ? nil : currentSubtitle,
                desc: currentDesc.isNilOrEmpty ? nil : currentDesc,
                category: currentCategory.isNilOrEmpty ? nil : currentCategory,
                language: (currentLanguage ?? pendingLanguage).isNilOrEmpty ? nil : (currentLanguage ?? pendingLanguage),
                iconSrc: currentIconSrc,
                feedID: feedID
            ))
        }
        currentElement = ""
    }

    private func parseDate(from string: String?) -> Date? {
        guard let string else { return nil }
        // XMLTV format: "20240101000000 +0000"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without timezone
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "yyyyMMddHHmmss"
        shortFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return shortFormatter.date(from: string)
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
