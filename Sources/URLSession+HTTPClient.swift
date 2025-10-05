import Combine
import Foundation

extension URLSession: HTTPClient {
    public func execute(request: any Request) async throws(HTTPError) -> Response {
        let urlRequest = try urlRequest(from: request)
        let response = try await response(request: urlRequest)
        if response.isSuccessful {
            return response
        } else {
            throw .serverError(response)
        }
    }
    
    private func urlRequest(from request: any Request) throws(HTTPError) -> URLRequest {
        do {
            return try request.urlRequest()
        } catch let error as HTTPError {
            throw error
        } catch {
            throw .requestError(error)
        }
    }
    
    private func response(request: URLRequest) async throws(HTTPError) -> Response {
        do {
            let (data, urlResponse) = try await data(for: request)
            let response = Response(
                httpURLResponse: urlResponse as! HTTPURLResponse,
                data: data
            )
            return response
        } catch let error as URLError {
            throw .urlError(error)
        } catch {
            throw .other(error)
        }
    }
}
