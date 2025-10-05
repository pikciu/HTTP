import Foundation

extension HTTPClient {
    public func responseJSON<T: Decodable>(request: any Request) async throws(HTTPError) -> T {
        try await execute(request: request, responseMapper: JSONResponseMapper())
    }
}
