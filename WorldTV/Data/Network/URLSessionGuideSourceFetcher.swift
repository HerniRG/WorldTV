import Foundation

struct URLSessionGuideSourceFetcher: GuideSourceFetching {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func fetchXML(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/xml,text/xml,*/*", forHTTPHeaderField: "Accept")
        request.setValue("WorldTV/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError.unacceptableStatusCode(httpResponse.statusCode)
        }

        return data
    }
}
