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

        logger.info("EPG: loading for channel \(channelID, privacy: .public), guides found: \(guides.count, privacy: .public)")

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
           let cachedPrograms = try? await cache.load(key: cacheKey)
        {
            inMemoryCache[cacheKey] = (cachedPrograms, Date())
            logger.info("EPG: file cache load for \(channelID, privacy: .public), \(cachedPrograms.count, privacy: .public) programs")
            return cachedPrograms
        }

        var allPrograms: [Program] = []
        for guide in guides {
            for source in guide.sources where source.url != nil {
                guard let url = source.url else { continue }
                let fmt = source.format?.uppercased() ?? "nil"
                logger.info("EPG: source format=\(fmt, privacy: .public) url=\(url.absoluteString, privacy: .public)")
                if fmt != "XML" && fmt != "xmltv" {
                    continue
                }
                do {
                    let xmlData = try await guideSourceFetcher.fetchXML(from: url)
                    let parsed = XMLTVParser.parse(data: xmlData, feedID: guide.feedID)
                    logger.info("EPG: fetched \(parsed.count, privacy: .public) raw programs from \(url.absoluteString, privacy: .public)")
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
                    let currentCount = programs.filter { $0.isCurrent }.count
                    logger.info("EPG: \(programs.count, privacy: .public) valid programs, \(currentCount, privacy: .public) current")
                    allPrograms.append(contentsOf: programs)
                } catch {
                    logger.warning("EPG: Failed to fetch from \(url.absoluteString, privacy: .public): \(String(describing: error))")
                }
            }
        }

        inMemoryCache[cacheKey] = (allPrograms, Date())
        try? await cache.save(allPrograms, key: cacheKey)

        let currentCount = allPrograms.filter { $0.isCurrent }.count
        logger.info("EPG: total \(allPrograms.count, privacy: .public) programs for \(channelID, privacy: .public), \(currentCount, privacy: .public) current")

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
