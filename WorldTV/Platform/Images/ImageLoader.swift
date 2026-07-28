import Foundation

protocol ImageLoading: Sendable {
    func data(from url: URL) async throws -> Data
}

actor URLSessionImageLoader: ImageLoading {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPError.unacceptableStatusCode(response.statusCode)
        }
        return data
    }
}
