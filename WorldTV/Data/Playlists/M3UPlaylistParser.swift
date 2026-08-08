import Foundation

struct M3UPlaylistParser: Sendable {
    func parse(_ data: Data, source: PlaylistSource) throws -> Catalog {
        guard let text = String(data: data, encoding: .utf8) else { throw PlaylistSourceError.emptyPlaylist }
        var entries: [Entry] = []
        var referrer: String?
        var userAgent: String?
        var group: String?
        let lines = text.components(separatedBy: .newlines)
        let isHLSMediaPlaylist = lines.contains { line in
            line.hasPrefix("#EXT-X-TARGETDURATION") || line.hasPrefix("#EXT-X-MEDIA-SEQUENCE") || line.hasPrefix("#EXT-X-STREAM-INF")
        }
        if isHLSMediaPlaylist {
            throw PlaylistSourceError.noPlayableEntries
        }

        for lineValue in lines {
            let line = lineValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("#EXTVLCOPT:http-referrer=") {
                referrer = String(line.dropFirst("#EXTVLCOPT:http-referrer=".count))
                continue
            }
            if line.hasPrefix("#EXTVLCOPT:http-user-agent=") {
                userAgent = String(line.dropFirst("#EXTVLCOPT:http-user-agent=".count))
                continue
            }
            if line.hasPrefix("#EXTGRP:") { group = String(line.dropFirst(8)); continue }
            if line.hasPrefix("#EXTINF:") {
                let parsed = parseExtInf(line)
                entries.append(Entry(index: entries.count, name: parsed.attributes["tvg-name"] ?? parsed.displayName, displayName: parsed.displayName, id: parsed.attributes["tvg-id"], country: parsed.attributes["tvg-country"] ?? parsed.attributes["tvg-country-code"] ?? inferCountry(from: parsed.attributes["tvg-id"]), group: parsed.attributes["group-title"] ?? group, logo: parsed.attributes["tvg-logo"], quality: parsed.attributes["tvg-quality"] ?? inferQuality(parsed.displayName), network: parsed.attributes["tvg-network"] ?? parsed.attributes["network"] ?? parsed.attributes["tvg-provider"] ?? parsed.attributes["tvg-broadcaster"], url: nil, referrer: parsed.attributes["http-referrer"] ?? parsed.attributes["referrer"], userAgent: parsed.attributes["http-user-agent"] ?? parsed.attributes["user-agent"]))
                continue
            }
            guard !line.hasPrefix("#") else { continue }
            let normalizedLine: String
            if line.contains("://") {
                normalizedLine = line
            } else {
                let parts = line.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                let relativeValue = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard relativeValue.contains("/") else { continue }
                guard let relativeURL = URL(string: relativeValue, relativeTo: source.url.deletingLastPathComponent())?.absoluteURL else { continue }
                normalizedLine = relativeURL.absoluteString + (parts.count == 2 ? "|\(parts[1])" : "")
            }
            guard let target = parseStreamTarget(normalizedLine, relativeTo: source.url) else { continue }
            let pending = entries.popLast()
            if let pending, pending.url == nil {
                entries.append(pending.with(url: target.url, referrer: referrer ?? target.referrer ?? pending.referrer, userAgent: userAgent ?? target.userAgent ?? pending.userAgent))
            } else {
                if let pending { entries.append(pending) }
                entries.append(Entry(index: entries.count, name: target.url.deletingPathExtension().lastPathComponent, displayName: target.url.lastPathComponent, id: nil, country: nil, group: nil, logo: nil, quality: nil, network: nil, url: target.url, referrer: referrer ?? target.referrer, userAgent: userAgent ?? target.userAgent))
            }
            referrer = nil
            userAgent = nil
            group = nil
        }

        let playable = entries.filter { $0.url != nil }
        guard !entries.isEmpty else {
            throw PlaylistSourceError.emptyPlaylist
        }
        guard !playable.isEmpty else { throw PlaylistSourceError.noPlayableEntries }

        var channels: [Channel] = []
        var streams: [ChannelStream] = []
        var logos: [ChannelLogo] = []
        var allCategoryNames: [String] = []
        var channelIndexes: [String: Int] = [:]
        var streamURLsByChannelID: [String: Set<URL>] = [:]
        for entry in playable {
            guard let url = entry.url else { continue }
            let rawIdentifier = entry.id?.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseIdentifier = canonicalChannelIdentifier(rawIdentifier, fallback: "entry-\(entry.index)")
            let channelID = "\(source.id.uuidString)|\(baseIdentifier)"
            let resolvedCountryCode = countryCode(entry.country)
            let categories = categoryNames(entry.group, countryCode: resolvedCountryCode)
            allCategoryNames.append(contentsOf: categories)
            if channelIndexes[channelID] == nil {
                channelIndexes[channelID] = channels.count
                channels.append(Channel(id: channelID, name: entry.name.isEmpty ? entry.displayName : entry.name, alternativeNames: entry.displayName == entry.name ? [] : [entry.displayName], countryCode: resolvedCountryCode, categoryIDs: categories.map(slug), isNSFW: false, network: entry.network, owners: [], launched: nil, closed: nil, replacedBy: nil, website: nil))
            }
            if streamURLsByChannelID[channelID, default: []].insert(url).inserted {
                streams.append(ChannelStream(id: url, channelID: channelID, url: url, feed: nil, title: entry.displayName, quality: entry.quality, label: nil, referrer: entry.referrer, userAgent: entry.userAgent))
            }
            if let logo = entry.logo, let logoURL = URL(string: logo), logoURL.isHTTP {
                if !logos.contains(where: { $0.channelID == channelID && $0.url == logoURL }) {
                    logos.append(ChannelLogo(id: logoURL, channelID: channelID, url: logoURL, feed: nil, width: nil, height: nil, format: nil, isInUse: true, tags: []))
                }
            }
        }

        let countryCodes = Set(channels.map(\.countryCode))
        let countries = countryCodes.sorted().map { code in
            let name: String
            switch code {
            case "INT": name = "International"
            case "UN": name = "United Nations"
            case "ZZ": name = "Unclassified"
            default: name = Locale.current.localizedString(forRegionCode: code) ?? code
            }
            return Country(code: code, name: name, languageCodes: [], flag: nil)
        }
        let categories = Set(allCategoryNames).sorted().map { ChannelCategory(id: slug($0), name: $0, description: nil) }
        return Catalog(channels: channels, countries: countries, categories: categories, streamsByChannelID: Dictionary(grouping: streams, by: \.channelID), logosByChannelID: Dictionary(grouping: logos, by: \.channelID))
    }

    private func parseExtInf(_ line: String) -> (attributes: [String: String], displayName: String) {
        let value = String(line.dropFirst(8))
        let comma = value.firstIndex(of: ",")
        let metadata = comma.map { String(value[..<$0]) } ?? value
        let name = comma.map { String(value[value.index(after: $0)...]) } ?? "Unnamed channel"
        var attributes: [String: String] = [:]
        var cursor = metadata.startIndex
        while cursor < metadata.endIndex {
            while cursor < metadata.endIndex && (metadata[cursor].isWhitespace || metadata[cursor] == "-" || metadata[cursor].isNumber) { cursor = metadata.index(after: cursor) }
            let start = cursor
            while cursor < metadata.endIndex && metadata[cursor] != "=" && !metadata[cursor].isWhitespace { cursor = metadata.index(after: cursor) }
            guard start < cursor else { break }
            let key = String(metadata[start..<cursor]).lowercased()
            while cursor < metadata.endIndex && metadata[cursor].isWhitespace { cursor = metadata.index(after: cursor) }
            guard cursor < metadata.endIndex, metadata[cursor] == "=" else { continue }
            cursor = metadata.index(after: cursor)
            while cursor < metadata.endIndex && metadata[cursor].isWhitespace { cursor = metadata.index(after: cursor) }
            let quote = cursor < metadata.endIndex && metadata[cursor] == "\""
            if quote { cursor = metadata.index(after: cursor) }
            let valueStart = cursor
            while cursor < metadata.endIndex && (quote ? metadata[cursor] != "\"" : !metadata[cursor].isWhitespace) { cursor = metadata.index(after: cursor) }
            attributes[key] = String(metadata[valueStart..<cursor])
            if quote && cursor < metadata.endIndex { cursor = metadata.index(after: cursor) }
        }
        return (attributes, name.trimmingCharacters(in: .whitespaces))
    }

    private func countryCode(_ value: String?) -> String {
        let code = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        if code == "INT" { return code }
        return code.count == 2 && code.allSatisfy(\.isLetter) ? code : "ZZ"
    }

    private func inferCountry(from channelID: String?) -> String? {
        guard let channelID, let suffix = channelID.split(separator: ".").last else { return nil }
        let code = suffix.split(separator: "@").first.map(String.init)?.uppercased() ?? ""
        guard code.count == 2, code.allSatisfy(\.isLetter) else { return nil }
        return code
    }

    private func canonicalChannelIdentifier(_ value: String?, fallback: String) -> String {
        guard let value, !value.isEmpty else { return fallback }
        let parts = value.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return value }
        let qualityMarker = parts[1].uppercased().split(separator: ":").first.map(String.init) ?? parts[1].uppercased()
        let qualityMarkers = ["SD", "HD", "FHD", "UHD", "4K", "8K", "LD", "HQ"]
        return qualityMarkers.contains(qualityMarker) ? parts[0] : value
    }

    private func categoryNames(_ value: String?, countryCode: String) -> [String] {
        let names = value?.split(whereSeparator: { $0 == ";" || $0 == "|" || $0 == "," }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
        return names.filter { !isCountryName($0, code: countryCode) }
    }

    private func isCountryName(_ value: String, code: String) -> Bool {
        guard code != "UN", code != "INT", code != "ZZ", let localized = Locale(identifier: "en_US").localizedString(forRegionCode: code) else { return false }
        return value.caseInsensitiveCompare(localized) == .orderedSame
    }

    private func slug(_ value: String) -> String { value.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
    private func inferQuality(_ value: String) -> String? { ["2160p", "1440p", "1080p", "720p", "576p", "480p"].first { value.localizedCaseInsensitiveContains($0) } }

    private func parseStreamTarget(_ rawValue: String, relativeTo sourceURL: URL) -> StreamTarget? {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        let streamValue = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !streamValue.contains("://") {
            let normalizedValue = streamValue.lowercased()
            guard normalizedValue.hasSuffix(".m3u") || normalizedValue.hasSuffix(".m3u8") else {
                return nil
            }
        }
        let url: URL
        if streamValue.contains("://") {
            guard let parsedURL = URL(string: streamValue) else { return nil }
            url = parsedURL.absoluteURL
        } else {
            guard let resolvedURL = URL(string: streamValue, relativeTo: sourceURL.deletingLastPathComponent()) else {
                return nil
            }
            url = resolvedURL.absoluteURL
        }
        guard url.isHTTP else { return nil }
        guard parts.count == 2 else { return StreamTarget(url: url, referrer: nil, userAgent: nil) }

        var referrer: String?
        var userAgent: String?
        for parameter in parts[1].split(separator: "&") {
            let pair = parameter.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            let key = pair[0].lowercased()
            let value = pair[1].removingPercentEncoding ?? pair[1]
            if key == "referer" || key == "http-referrer" { referrer = value }
            if key == "user-agent" || key == "http-user-agent" { userAgent = value }
        }
        return StreamTarget(url: url, referrer: referrer, userAgent: userAgent)
    }

    private struct StreamTarget: Sendable {
        let url: URL
        let referrer: String?
        let userAgent: String?
    }

    private struct Entry: Sendable {
        let index: Int; let name: String; let displayName: String; let id: String?; let country: String?; let group: String?; let logo: String?; let quality: String?; let network: String?; let url: URL?; let referrer: String?; let userAgent: String?
        func with(url: URL, referrer: String?, userAgent: String?) -> Entry { Entry(index: index, name: name, displayName: displayName, id: id, country: country, group: group, logo: logo, quality: quality, network: network, url: url, referrer: referrer, userAgent: userAgent) }
    }
}

private extension URL { var isHTTP: Bool { scheme?.lowercased() == "http" || scheme?.lowercased() == "https" } }
