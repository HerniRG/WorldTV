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
        cacheMaxAge: TimeInterval = 30 * 60,
        now: @escaping @Sendable () -> Date = Date.init
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

        guard !guides.isEmpty else {
            return []
        }

        let cacheKey = channelID + (feedID ?? "")

        // Check in-memory cache
        if !forceRefresh,
           let cached = inMemoryCache[cacheKey],
           Date().timeIntervalSince(cached.loadedAt) < cacheMaxAge
        {
            return cached.programs
        }

        // Check file cache
        if !forceRefresh,
           let cachedPrograms = try? await cache.load(key: cacheKey)
        {
            inMemoryCache[cacheKey] = (cachedPrograms, Date())
            return cachedPrograms
        }

        // Fetch from guide sources
        var allPrograms: [Program] = []
        for guide in guides {
            for source in guide.sources where source.format?.uppercased() == "XML" {
                guard let url = source.url else { continue }
                do {
                    let xmlData = try await guideSourceFetcher.fetchXML(from: url)
                    let parsed = XMLTVParser.parse(data: xmlData, feedID: guide.feedID)
                    let programs = parsed.compactMap { parsedProgram -> Program? in
                        guard let startTime = parsedProgram.startTime,
                              let endTime = parsedProgram.endTime,
                              let iconURL = parsedProgram.iconSrc.flatMap(URL.init)
                        else {
                            return nil
                        }
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
                    allPrograms.append(contentsOf: programs)
                } catch {
                    logger.warning("Failed to fetch EPG from \(url.absoluteString): \(String(describing: error))")
                }
            }
        }

        // Cache results
        inMemoryCache[cacheKey] = (allPrograms, Date())
        try? await cache.save(allPrograms, key: cacheKey)

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
