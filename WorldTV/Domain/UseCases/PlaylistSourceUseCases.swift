import Foundation

struct LoadPlaylistSourcesUseCase: Sendable {
    private let store: any PlaylistSourceStore
    init(store: any PlaylistSourceStore) { self.store = store }
    func execute() async throws -> [PlaylistSource] { try await store.load() }
}

struct AddPlaylistSourceUseCase: Sendable {
    private let store: any PlaylistSourceStore
    private let invalidate: @Sendable () async -> Void
    private let validate: @Sendable (PlaylistSource) async throws -> Void
    init(
        store: any PlaylistSourceStore,
        invalidate: @escaping @Sendable () async -> Void,
        validate: @escaping @Sendable (PlaylistSource) async throws -> Void = { _ in }
    ) {
        self.store = store
        self.invalidate = invalidate
        self.validate = validate
    }
    func execute(name: String, urlString: String) async throws -> PlaylistSource {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { throw PlaylistSourceError.invalidURL }
        guard url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else { throw PlaylistSourceError.unsupportedURLScheme }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = PlaylistSource(name: cleanName.isEmpty ? (url.host() ?? "Playlist") : cleanName, url: url)
        try await validate(source)
        try await store.add(source); await invalidate(); return source
    }
}

struct RemovePlaylistSourceUseCase: Sendable {
    private let store: any PlaylistSourceStore
    private let invalidate: @Sendable () async -> Void
    init(store: any PlaylistSourceStore, invalidate: @escaping @Sendable () async -> Void) { self.store = store; self.invalidate = invalidate }
    func execute(id: UUID) async throws { try await store.remove(id: id); await invalidate() }
}

struct CatalogMetadata: Codable, Sendable { let updatedAt: Date? }
protocol CatalogMetadataStore: Sendable { func load() async throws -> Date?; func save(date: Date) async throws; func clear() async throws }

actor FileCatalogMetadataStore: CatalogMetadataStore {
    private let fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }
    func load() throws -> Date? { guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }; return try JSONDecoder().decode(CatalogMetadata.self, from: Data(contentsOf: fileURL)).updatedAt }
    func save(date: Date) throws { let directory = fileURL.deletingLastPathComponent(); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); try JSONEncoder().encode(CatalogMetadata(updatedAt: date)).write(to: fileURL, options: .atomic) }
    func clear() throws { if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) } }
}
