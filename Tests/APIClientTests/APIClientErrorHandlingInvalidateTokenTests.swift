import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Error Handling: InvalidateToken Strategy")
struct APIClientErrorHandlingInvalidateTokenTests {
    
    @Test func `HTTP error with invalidate token strategy invalidates token`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200)),
        ])
        let errorHandler = FakeErrorHandler(results: [.invalidateToken])
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 200)
        #expect(await httpClient.executedRequests.count == 2)
        #expect(await authService.refreshTokenCallCount == 1)
    }
    
    @Test func `invalidate token strategy retries request`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler(results: [.invalidateToken])
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        _ = try await apiClient.execute(request: request)
        
        #expect(await httpClient.executedRequests.count == 2)
        
        let firstRequest = await httpClient.executedRequests[0] as? AuthorizedRequest
        let secondRequest = await httpClient.executedRequests[1] as? AuthorizedRequest
        
        #expect(firstRequest?.token.token == JWT.valid.token)
        #expect(secondRequest?.token.token == JWT.valid.token)
    }
    
    @Test func `retry after invalidate succeeds with new token`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler(results: [.invalidateToken])
        let newToken = JWT.valid
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(newToken)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 200)
        
        let state = await tokenManager.state
        #expect(state == .valid(newToken))
        
        let retryRequest = await httpClient.executedRequests[1] as? AuthorizedRequest
        #expect(retryRequest?.token.token == newToken.token)
    }
    
    @Test func `retry after invalidate fails with propagate strategy returns error`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .failure(.serverError(errorResponse))
        ])
        let errorHandler = FakeErrorHandler(results: [.invalidateToken, .propagate])
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
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
        
        #expect(await httpClient.executedRequests.count == 2)
        #expect(await authService.refreshTokenCallCount == 1)
    }
    
    @Test func `invalidate token calls tokenManager invalidate`() async throws {
        let tokenManager = TokenManager.forTesting()
        let originalToken = JWT.valid
        await tokenManager.save(jwt: originalToken)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler(results: [.invalidateToken])
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        _ = try await apiClient.execute(request: request)
        
        let state = await tokenManager.state
        #expect(state == .valid(.valid))
    }
    
    @Test func `retry uses refreshed token after invalidation`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 401)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler(results: [.invalidateToken])
        
        let refreshedToken = JWT.valid
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(refreshedToken)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        _ = try await apiClient.execute(request: request)
        
        let retryRequest = await httpClient.executedRequests[1] as? AuthorizedRequest
        #expect(retryRequest?.token.token == refreshedToken.token)
        #expect(await authService.refreshTokenCallCount == 1)
    }
}
