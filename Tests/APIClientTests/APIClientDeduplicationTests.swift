import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Request Deduplication")
struct APIClientDeduplicationTests {
    
    @Test func `two requests with same ID are deduplicated`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(result: .success(.stub(statusCode: 200)))
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = request1
        
        async let response1 = apiClient.execute(request: request1)
        async let response2 = apiClient.execute(request: request2)
        
        let results = try await [response1, response2]
        
        #expect(results.count == 2)
        #expect(results[0].httpURLResponse.statusCode == 200)
        #expect(results[1].httpURLResponse.statusCode == 200)
        
        #expect(await httpClient.executedRequests.count == 1)
    }
    
    @Test func `two requests with different IDs execute separately`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 201)),
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        
        async let response1 = apiClient.execute(request: request1)
        async let response2 = apiClient.execute(request: request2)
        
        let results = try await [response1, response2]
        
        #expect(results.count == 2)
        #expect(await httpClient.executedRequests.count == 2)
    }
    
    @Test func `multiple requests with same ID are deduplicated`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(results: [.success(.stub(statusCode: 200))])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        async let response1 = apiClient.execute(request: request)
        async let response2 = apiClient.execute(request: request)
        async let response3 = apiClient.execute(request: request)
        async let response4 = apiClient.execute(request: request)
        async let response5 = apiClient.execute(request: request)
        
        let results = try await [
            response1,
            response2,
            response3,
            response4,
            response5
        ]
        
        #expect(results.count == 5)
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
        #expect(await httpClient.executedRequests.count == 1)
    }
    
    @Test func `deduplicated requests receive same response`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let responseData = "test data".data(using: .utf8)!
        let httpClient = FakeHTTPClient(result: .success(.stub(statusCode: 200, data: responseData)))
        
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = request1
        
        async let response1 = apiClient.execute(request: request1)
        async let response2 = apiClient.execute(request: request2)
        
        let results = try await [response1, response2]
        
        #expect(results[0].data == responseData)
        #expect(results[1].data == responseData)
        #expect(results[0].httpURLResponse.statusCode == 200)
        #expect(results[1].httpURLResponse.statusCode == 200)
    }
    
    @Test func `deduplicated requests receive same error`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 500)
        let httpClient = FakeHTTPClient(result: .failure(.serverError(errorResponse)))
        let errorHandler = FakeErrorHandler(results: [.propagate])
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = request1
        
        await #expect(throws: HTTPError.self) {
            async let a = apiClient.execute(request: request1)
            async let b = apiClient.execute(request: request2)
            _ = try await [a, b]
        }
        
        #expect(await httpClient.executedRequests.count == 1)
    }
}
