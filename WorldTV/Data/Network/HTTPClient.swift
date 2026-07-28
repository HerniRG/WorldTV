import Foundation

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> Data
}

enum HTTPError: Error, Equatable, Sendable {
    case invalidEndpoint
    case invalidResponse
    case unacceptableStatusCode(Int)
}

actor URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPError.unacceptableStatusCode(response.statusCode)
        }

        return data
    }
}
