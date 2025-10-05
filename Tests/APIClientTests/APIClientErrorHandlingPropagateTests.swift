import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Error Handling: propagate strategy")
struct APIClientErrorHandlingPropagateTests {
    
    @Test func `HTTP error with propagate strategy returns error without retry`() async throws {
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
        
        let request = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            try await apiClient.execute(request: request)
        }
        
        #expect(await httpClient.executedRequests.count == 1)
        #expect(await authService.authorizeCallCount == 0)
        #expect(await authService.refreshTokenCallCount == 0)
    }
    
    @Test func `authorization error with propagate strategy returns error`() async throws {
        let tokenManager = TokenManager.forTesting()
        let httpClient = FakeHTTPClient()
        let errorHandler = FakeErrorHandler(results: [
            .propagate
        ])
        let authService = FakeAuthorizationService(authorizeResults: [
            .failure(.other(TestError()))
        ])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            try await apiClient.execute(request: request)
        }
        
        #expect(await authService.authorizeCallCount == 1)
        #expect(await httpClient.executedRequests.count == 0)
    }
    
    @Test func `refresh token error with propagate strategy returns error`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient()
        let errorHandler = FakeErrorHandler(results: [
            .propagate
        ])
        let authService = FakeAuthorizationService(refreshTokenResults: [
            .failure(.other(TestError()))
        ])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            try await apiClient.execute(request: request)
        }
        
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await httpClient.executedRequests.count == 0)
    }
    
    @Test func `propagate strategy does not trigger retry`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200)),
        ])
        let errorHandler = FakeErrorHandler(results: [.propagate])
        let authService = FakeAuthorizationService()
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            try await apiClient.execute(request: request)
        }
        
        #expect(await httpClient.executedRequests.count == 1)
        
        let state = await tokenManager.state
        #expect(state == .valid(.valid))
    }
}
