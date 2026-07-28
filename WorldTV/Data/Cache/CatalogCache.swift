import Foundation

struct CachedCatalogSnapshot: Codable, Sendable {
    let savedAt: Date
    let payload: IPTVOrgCatalogPayload

    func isFresh(at date: Date, maxAge: TimeInterval) -> Bool {
        date.timeIntervalSince(savedAt) < maxAge
    }
}

protocol CatalogCaching: Sendable {
    func load() async throws -> CachedCatalogSnapshot?
    func save(_ snapshot: CachedCatalogSnapshot) async throws
    func clear() async throws
}

actor FileCatalogCache: CatalogCaching {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func load() throws -> CachedCatalogSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try decoder.decode(CachedCatalogSnapshot.self, from: Data(contentsOf: fileURL))
    }

    func save(_ snapshot: CachedCatalogSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}
