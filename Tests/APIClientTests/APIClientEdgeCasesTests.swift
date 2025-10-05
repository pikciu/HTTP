import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Edge Cases")
struct APIClientEdgeCasesTests {
    
    @Test func `all continuations are resumed exactly once`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        async let a = apiClient.execute(request: request)
        async let b = apiClient.execute(request: request)
        async let c = apiClient.execute(request: request)
        
        let results = try await [a, b, c]
        
        #expect(results.count == 3)
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
    }
    
    @Test func `no continuations are left pending after execution`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200))
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
        _ = try await apiClient.execute(request: request1)
        
        let request2 = TestRequest.valid()
        _ = try await apiClient.execute(request: request2)
        
        #expect(await httpClient.executedRequests.count == 2)
    }
    
    @Test func `empty response is handled correctly`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 204, data: Data()))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 204)
        #expect(response.data.isEmpty)
    }
    
    @Test func `rapid sequential requests with same ID deduplicate correctly`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        let results = try await withThrowingTaskGroup(of: Response.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await apiClient.execute(request: request)
                }
            }
            
            var collected: [Response] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }
        
        #expect(results.count == 10)
        #expect(await httpClient.executedRequests.count == 1)
        
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
    }
}
