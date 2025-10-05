import Foundation

public protocol HTTPClient {
    func execute(request: any Request) async throws(HTTPError) -> Response
}

extension HTTPClient {
    public func execute<M: ResponseMapper>(request: any Request, responseMapper: M) async throws(HTTPError) -> M.Output {
        let response = try await execute(request: request)
        do {
            let result = try responseMapper.map(response: response)
            return result
        } catch let error as HTTPError {
            throw error
        } catch {
            throw .responseMapperError(response, error)
        }
    }
}
