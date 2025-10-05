import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Concurrent Authorization/Refresh Prevention")
struct APIClientConcurrentAuthTests {
    
    @Test func `concurrent unauthorized requests trigger single authorization`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(authorizeResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        let request3 = TestRequest.valid()
        let request4 = TestRequest.valid()
        let request5 = TestRequest.valid()
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        async let c = apiClient.execute(request: request3)
        async let d = apiClient.execute(request: request4)
        async let e = apiClient.execute(request: request5)
        
        let results = try await [a, b, c, d, e]
        
        #expect(results.count == 5)
        #expect(await authService.authorizeCallCount == 1)
        #expect(await httpClient.executedRequests.count == 5)
        
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
    }
    
    @Test func `concurrent invalid token requests trigger single refresh`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        let request3 = TestRequest.valid()
        let request4 = TestRequest.valid()
        let request5 = TestRequest.valid()
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        async let c = apiClient.execute(request: request3)
        async let d = apiClient.execute(request: request4)
        async let e = apiClient.execute(request: request5)
        
        let results = try await [a, b, c, d, e]
        
        #expect(results.count == 5)
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await httpClient.executedRequests.count == 5)
        
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
    }
    
    @Test func `concurrent 401 errors trigger single token refresh not multiple`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .failure(.serverError(errorResponse)),
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler(results: [
            .invalidateToken,
            .invalidateToken,
            .invalidateToken
        ])
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        let request3 = TestRequest.valid()
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        async let c = apiClient.execute(request: request3)
        
        let results = try await [a, b, c]
        
        #expect(results.count == 3)
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await httpClient.executedRequests.count == 6)
    }
    
    @Test func `mixed concurrent requests with authorization wait for single authorize`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: Array(repeating: .success(.stub(statusCode: 200)), count: 10))
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(authorizeResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let requests = (0..<10).map { _ in TestRequest.valid() }
        
        let results = try await withThrowingTaskGroup(of: Response.self) { group in
            for request in requests {
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
        #expect(await authService.authorizeCallCount == 1)
        #expect(await httpClient.executedRequests.count == 10)
    }
    
    @Test func `mixed concurrent requests with refresh wait for single refresh`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(results: Array(repeating: .success(.stub(statusCode: 200)), count: 10))
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let requests = (0..<10).map { _ in TestRequest.valid() }
        
        let results = try await withThrowingTaskGroup(of: Response.self) { group in
            for request in requests {
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
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await httpClient.executedRequests.count == 10)
    }
    
    @Test func `concurrent unauthorized requests retry authorize sequentially after failures`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient()
        let errorHandler = FakeErrorHandler(results: [
            .propagate,
            .propagate,
            .propagate,
        ])
        let authService = FakeAuthorizationService(authorizeResults: [
            .failure(.other(TestError())),
            .failure(.other(TestError())),
            .failure(.other(TestError())),
        ])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        let request3 = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            async let a = apiClient.execute(request: request1)
            async let b = apiClient.execute(request: request2)
            async let c = apiClient.execute(request: request3)
            _ = try await [a, b, c]
        }
        
        #expect(await authService.authorizeCallCount == 3)
        #expect(await httpClient.executedRequests.count == 0)
    }
    
    @Test func `concurrent invalid token requests retry refresh sequentially after failures`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient()
        let errorHandler = FakeErrorHandler(results: [
            .propagate,
            .propagate,
            .propagate,
        ])
        let authService = FakeAuthorizationService(refreshTokenResults: [
            .failure(.other(TestError())),
            .failure(.other(TestError())),
            .failure(.other(TestError())),
        ])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        let request3 = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            async let a = apiClient.execute(request: request1)
            async let b = apiClient.execute(request: request2)
            async let c = apiClient.execute(request: request3)
            _ = try await [a, b, c]
        }
        
        #expect(await authService.refreshTokenCallCount == 3)
        #expect(await httpClient.executedRequests.count == 0)
    }
}
