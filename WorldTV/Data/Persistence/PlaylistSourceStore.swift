import Foundation

protocol PlaylistSourceStore: Sendable {
    func load() async throws -> [PlaylistSource]
    func add(_ source: PlaylistSource) async throws
    func remove(id: UUID) async throws
}

actor FilePlaylistSourceStore: PlaylistSourceStore {
    private let fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }

    func load() throws -> [PlaylistSource] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([PlaylistSource].self, from: Data(contentsOf: fileURL))
    }

    func add(_ source: PlaylistSource) throws {
        var sources = try load()
        sources.append(source)
        try save(sources)
    }

    func remove(id: UUID) throws {
        try save(try load().filter { $0.id != id })
    }

    private func save(_ sources: [PlaylistSource]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(sources).write(to: fileURL, options: .atomic)
    }
}
