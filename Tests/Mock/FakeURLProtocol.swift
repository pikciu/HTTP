import Foundation
import HTTP

final class FakeURLProtocol: URLProtocol {

    static var results = [URLRequest: Result<Response, Error>]()

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let result = FakeURLProtocol.results[request] {
            switch result {
            case .success(let response):
                client?.urlProtocol(self, didLoad: response.data)
                client?.urlProtocol(self, didReceive: response.httpURLResponse, cacheStoragePolicy: .allowed)
            case .failure(let error):
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
