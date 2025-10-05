import Foundation
import Testing

@testable import HTTP

@Suite("HTTP Client Tests")
struct HTTPClientTests {

    @Test
    func `Success response`() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/test-\(#function)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let exepctedResponse = Response(httpURLResponse: response!, data: Data())
        let httpClient = FakeHTTPClient(result: .success(exepctedResponse))

        let result = try await httpClient.execute(request: TestRequest.valid())
        #expect(result.httpURLResponse.statusCode == response?.statusCode)
        #expect(result.httpURLResponse.url == response?.url)
    }
    
    @Test
    func `Failure response`() async throws {
        let httpClient = FakeHTTPClient(result: .failure(.other(TestError())))

        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(request: TestRequest.valid())
        }
        
        #expect(error?.isOtherError == true)
    }
    
    @Test
    func `Success mapped response`() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/test-\(#function)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let exepctedResponse = Response(httpURLResponse: response!, data: Data())
        let httpClient = FakeHTTPClient(result: .success(exepctedResponse))

        let result = try await httpClient.execute(
            request: TestRequest.valid(),
            responseMapper: FakeResponseMapper(result: .success("Success"))
        )
        #expect(result == "Success")
    }
    
    @Test
    func `Response mapper throws HTTP error`() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/test-\(#function)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let exepctedResponse = Response(httpURLResponse: response!, data: Data())
        let httpClient = FakeHTTPClient(result: .success(exepctedResponse))

        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(
                request: TestRequest.valid(),
                responseMapper: FakeResponseMapper(result: .failure(HTTPError.other(TestError())))
            )
        }
        #expect(error?.isOtherError == true)
    }
    
    @Test
    func `Response mapper throws other error`() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/test-\(#function)")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let exepctedResponse = Response(httpURLResponse: response!, data: Data())
        let httpClient = FakeHTTPClient(result: .success(exepctedResponse))

        let error = await #expect(throws: HTTPError.self) {
            try await httpClient.execute(
                request: TestRequest.valid(),
                responseMapper: FakeResponseMapper(result: .failure(TestError()))
            )
        }
        #expect(error?.isResponseMapperError == true)
    }
}
