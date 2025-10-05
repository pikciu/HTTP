import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Dependency Verification")
struct APIClientDependencyVerificationTests {
    
    @Test func `httpClient execute is called with authorized request`() async throws {
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
        _ = try await apiClient.execute(request: request)
        
        #expect(await httpClient.executedRequests.count == 1)
        
        let executedRequest = await httpClient.executedRequests[0]
        #expect(executedRequest is AuthorizedRequest)
    }
    
    @Test func `authorized request contains correct token`() async throws {
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
        _ = try await apiClient.execute(request: request)
        
        let executedRequest = await httpClient.executedRequests[0] as? AuthorizedRequest
        #expect(executedRequest?.token.token == JWT.valid.token)
    }
    
    @Test func `errorHandler handle is called for every error`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 500)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse))
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
        
        #expect(await errorHandler.callCount == 1)
    }
    
    @Test func `authorizationService authorize is called when unauthorized`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(authorizeResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        _ = try await apiClient.execute(request: request)
        
        #expect(await authService.authorizeCallCount == 1)
        #expect(await authService.refreshTokenCallCount == 0)
    }
    
    @Test func `authorizationService refreshToken is called when token invalid`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(results: [
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
        
        let request = TestRequest.valid()
        _ = try await apiClient.execute(request: request)
        
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await authService.authorizeCallCount == 0)
    }
    
    @Test func `tokenManager save is called after successful authorization`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(authorizeResults: [.success(.valid)])
        
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
    
    @Test func `tokenManager save is called after successful refresh`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(results: [
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
        
        let request = TestRequest.valid()
        _ = try await apiClient.execute(request: request)
        
        let state = await tokenManager.state
        #expect(state == .valid(.valid))
    }
    
    @Test func `tokenManager invalidate is called on invalidateToken strategy`() async throws {
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
        
        #expect(await authService.refreshTokenCallCount == 1)
    }
    
    @Test func `tokenManager reset is called on logout strategy`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse))
        ])
        let errorHandler = FakeErrorHandler(results: [.logout])
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
        
        let state = await tokenManager.state
        #expect(state == .unauthorized)
    }
}
