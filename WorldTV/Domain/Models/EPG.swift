import Foundation

struct Guide: Identifiable, Hashable, Sendable {
    let id: String
    let channelID: String?
    let feedID: String?
    let site: String?
    let siteID: String?
    let siteName: String?
    let lang: String?
    let sources: [GuideSource]
}

struct GuideSource: Hashable, Sendable {
    let host: String?
    let url: URL?
    let format: String?
}

struct Program: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let channelID: String
    let feedID: String?
    let startTime: Date
    let endTime: Date
    let title: String
    let subtitle: String?
    let description: String?
    let category: String?
    let language: String?
    let iconURL: URL?
}

struct NowPlaying: Sendable {
    let program: Program?
    let isActive: Bool
}

extension Program {
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var isCurrent: Bool {
        let now = Date()
        return startTime <= now && endTime > now
    }

    func progress(at date: Date = Date()) -> Double {
        let total = duration
        guard total > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(startTime)
        return max(0, min(1, elapsed / total))
    }
}