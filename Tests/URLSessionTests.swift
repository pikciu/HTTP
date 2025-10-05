import Foundation
import Testing

@testable import HTTP

@Suite("URLSession as HTTP Client Tests")
@MainActor
final class URLSessionTests {

    let httpClient: HTTPClient = {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [FakeURLProtocol.self]
        return URLSession(configuration: configuration)
    }()

    init() {
        URLProtocol.registerClass(FakeURLProtocol.self)
    }
    
    deinit {
        URLProtocol.unregisterClass(FakeURLProtocol.self)
    }

    @Test
    func `Throw URL error`() async {
        let request = URLRequest(url: URL(string: "https://example.com/test-\(#function)")!)
        FakeURLProtocol.results[request] = .failure(URLError(.cannotConnectToHost))
        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(request: request)
        }
        #expect(error?.isURLError == true)
    }
    
    @Test
    func `Throw other error`() async {
        let request = URLRequest(url: URL(string: "https://example.com/test-\(#function)")!)
        FakeURLProtocol.results[request] = .failure(TestError())
        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(request: request)
        }
        #expect(error?.isOtherError == true)
    }
    
    @Test
    func `Throw server error`() async {
        let url = URL(string: "https://example.com/test-\(#function)")!
        let request = URLRequest(url: url)
        let httpURLResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        FakeURLProtocol.results[request] = .success(Response(httpURLResponse: httpURLResponse, data: Data()))
        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(request: request)
        }
        #expect(error?.isServerError == true)
    }
    
    @Test
    func `Throw other error from request`() async {
        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(request: TestRequest.throwing(error: HTTPError.other(TestError())))
        }
        #expect(error?.isOtherError == true)
    }
    
    @Test
    func `Throw request error`() async {
        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(request: TestRequest.throwing(error: TestError()))
        }
        #expect(error?.isRequestError == true)
    }
    
    @Test
    func `Success response`() async throws {
        let url = URL(string: "https://example.com/test-\(#function)")!
        let statusCode = 200
        let request = URLRequest(url: url)
        let httpURLResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        FakeURLProtocol.results[request] = .success(Response(httpURLResponse: httpURLResponse, data: Data()))
        let response = try await httpClient.execute(request: request)
        #expect(response.httpURLResponse.url == httpURLResponse.url)
        #expect(response.httpURLResponse.statusCode == statusCode)
    }
}
