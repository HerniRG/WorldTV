import Foundation
import OSLog

protocol EPGRepository: Sendable {
    func loadPrograms(
        for channelID: String,
        feedID: String?,
        forceRefresh: Bool
    ) async throws -> [Program]
}

protocol GuideSourceFetching: Sendable {
    func fetchXML(from url: URL) async throws -> Data
}

actor DefaultEPGRepository: EPGRepository {
    private let channelRepository: ChannelRepository
    private let guideSourceFetcher: GuideSourceFetching
    private let cache: EPGBCaching
    private let cacheMaxAge: TimeInterval
    private let logger = Logger(subsystem: "hrgapps.WorldTV", category: "epg")
    private var inMemoryCache: [String: (programs: [Program], loadedAt: Date)] = [:]

    init(
        channelRepository: ChannelRepository,
        guideSourceFetcher: GuideSourceFetching,
        cache: EPGBCaching,
        cacheMaxAge: TimeInterval = 30 * 60
    ) {
        self.channelRepository = channelRepository
        self.guideSourceFetcher = guideSourceFetcher
        self.cache = cache
        self.cacheMaxAge = cacheMaxAge
    }

    func loadPrograms(
        for channelID: String,
        feedID: String?,
        forceRefresh: Bool = false
    ) async throws -> [Program] {
        let catalog = try await channelRepository.loadCatalog()
        let guides = catalog.index.guidesByChannelID[channelID] ?? []

        logger.info("═══ EPG: START loadPrograms for channel \(channelID, privacy: .public), feedID: \(feedID ?? "nil", privacy: .public), forceRefresh: \(forceRefresh) ═══")
        logger.info("EPG: channel has \(guides.count, privacy: .public) guide(s)")

        guard !guides.isEmpty else {
            return []
        }

        let cacheKey = channelID + (feedID ?? "")

        if !forceRefresh,
           let cached = inMemoryCache[cacheKey],
           Date().timeIntervalSince(cached.loadedAt) < cacheMaxAge
        {
            logger.info("EPG: cache hit for \(channelID, privacy: .public), \(cached.programs.count, privacy: .public) programs")
            return cached.programs
        }

        if !forceRefresh,
           let cachedPrograms = try? await cache.load(key: cacheKey),
           !cachedPrograms.isEmpty
        {
            inMemoryCache[cacheKey] = (cachedPrograms, Date())
            logger.info("EPG: file cache load for \(channelID, privacy: .public), \(cachedPrograms.count, privacy: .public) programs")
            return cachedPrograms
        }

        var totalSources = 0
        var xmltvSources = 0
        var fetchedSources = 0
        var failedSources = 0
        var totalRawPrograms = 0
        var totalValidPrograms = 0

        var allPrograms: [Program] = []
        for guide in guides {
            logger.info("EPG: guide id=\(guide.id, privacy: .public), site=\(guide.siteName ?? "nil", privacy: .public), feedID=\(guide.feedID ?? "nil", privacy: .public), lang=\(guide.lang ?? "nil", privacy: .public), sources=\(guide.sources.count, privacy: .public)")
            for source in guide.sources where source.url != nil {
                guard let url = source.url else { continue }
                let fmt = source.format?.uppercased() ?? "nil"
                totalSources += 1
                logger.info("EPG: [\(totalSources, privacy: .public)] source host=\(source.host ?? "nil", privacy: .public) format=\(fmt, privacy: .public) url=\(url.absoluteString, privacy: .public)")
                if fmt != "XML" && fmt != "xmltv" {
                    logger.info("EPG: [\(totalSources, privacy: .public)] skipped (not XML/XMLTV)")
                    continue
                }
                xmltvSources += 1
                do {
                    let xmlData = try await guideSourceFetcher.fetchXML(from: url)
                    fetchedSources += 1
                    logger.info("EPG: [\(totalSources, privacy: .public)] fetched \(xmlData.count, privacy: .public) bytes")
                    let parsed = XMLTVParser.parse(data: xmlData, feedID: guide.feedID)
                    totalRawPrograms += parsed.count
                    logger.info("EPG: [\(totalSources, privacy: .public)] parsed \(parsed.count, privacy: .public) raw programs from XML")
                    let programs = parsed.compactMap { parsedProgram -> Program? in
                        guard let startTime = parsedProgram.startTime,
                              let endTime = parsedProgram.endTime
                        else {
                            return nil
                        }
                        let iconURL = parsedProgram.iconSrc.flatMap(URL.init)
                        return Program(
                            id: "\(channelID).\(startTime.timeIntervalSince1970)",
                            channelID: parsedProgram.channelID,
                            feedID: parsedProgram.feedID,
                            startTime: startTime,
                            endTime: endTime,
                            title: parsedProgram.title,
                            subtitle: parsedProgram.subtitle,
                            description: parsedProgram.desc,
                            category: parsedProgram.category,
                            language: parsedProgram.language ?? nil,
                            iconURL: iconURL
                        )
                    }
                    let validCount = programs.count
                    let currentCount = programs.filter { $0.isCurrent }.count
                    totalValidPrograms += validCount
                    logger.info("EPG: [\(totalSources, privacy: .public)] \(validCount, privacy: .public) valid programs (\(currentCount, privacy: .public) current)")
                    allPrograms.append(contentsOf: programs)
                } catch {
                    failedSources += 1
                    logger.warning("EPG: [\(totalSources, privacy: .public)] FAILED url=\(url.absoluteString, privacy: .public) error=\(String(describing: error))")
                }
            }
        }

        logger.info("═══ EPG: SUMMARY for \(channelID, privacy: .public) ═══")
        logger.info("EPG: total guides=\(guides.count, privacy: .public), total sources=\(totalSources, privacy: .public), xmltv sources=\(xmltvSources, privacy: .public), fetched=\(fetchedSources, privacy: .public), failed=\(failedSources, privacy: .public)")
        logger.info("EPG: raw programs=\(totalRawPrograms, privacy: .public), valid programs=\(totalValidPrograms, privacy: .public)")

        return allPrograms
    }
}

protocol EPGBCaching: Sendable {
    func load(key: String) async throws -> [Program]
    func save(_ programs: [Program], key: String) async throws
}

actor FileEPGBCache: EPGBCaching {
    private let baseURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func load(key: String) async throws -> [Program] {
        let fileURL = cacheFileURL(forKey: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Program].self, from: data)
    }

    func save(_ programs: [Program], key: String) async throws {
        let fileURL = cacheFileURL(forKey: key)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(programs)
        try data.write(to: fileURL, options: .atomic)
    }

    private func cacheFileURL(forKey key: String) -> URL {
        baseURL.appendingPathComponent("epg").appendingPathComponent("\(key).json")
    }
}
