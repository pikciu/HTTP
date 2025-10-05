import Combine
import Foundation
import HTTP

actor FakeHTTPClient: HTTPClient {
    private var results: [Result<Response, HTTPError>]
    private var callCount = 0
    private(set) var executedRequests: [any Request] = []
    
    init(results: [Result<Response, HTTPError>] = []) {
        self.results = results
    }
    
    init(result: Result<Response, HTTPError>) {
        self.results = [result]
    }
    
    func setResults(_ results: [Result<Response, HTTPError>]) {
        self.results = results
        self.callCount = 0
    }
    
    func execute(request: any Request) async throws(HTTPError) -> Response {
        executedRequests.append(request)
        defer { callCount += 1 }
        
        return try results[callCount].get()
    }
}
