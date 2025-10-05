import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Error Handling: Logout Strategy")
struct APIClientErrorHandlingLogoutTests {
    
    @Test func `HTTP error with logout strategy resets token manager`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(result: .failure(.serverError(errorResponse)))
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
    
    @Test func `authorization error with logout strategy resets token manager`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient()
        let errorHandler = FakeErrorHandler(results: [.logout])
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
        
        let state = await tokenManager.state
        #expect(state == .unauthorized)
    }
    
    @Test func `logout strategy fails all pending requests`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(result: .failure(.serverError(errorResponse)))
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
            async let a = apiClient.execute(request: request)
            async let b = apiClient.execute(request: request)
            async let c = apiClient.execute(request: request)
            _ = try await [a, b, c]
        }
        
        #expect(await httpClient.executedRequests.count == 1)
    }
    
    @Test func `logout strategy returns error to all pending requests`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(result: .failure(.serverError(errorResponse)))
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
            async let a = apiClient.execute(request: request)
            async let b = apiClient.execute(request: request)
            _ = try await [a, b]
        }
    }
    
    @Test func `logout calls tokenManager reset`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(result: .failure(.serverError(errorResponse)))
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
    
    @Test func `multiple pending requests with different IDs all fail on logout`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse)),
            .failure(.serverError(errorResponse)),
            .failure(.serverError(errorResponse)),
        ])
        
        let errorHandler = FakeErrorHandler(results: [
            .logout,
            .logout,
            .logout,
        ])
        
        let authService = FakeAuthorizationService()
        
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
        
        let state = await tokenManager.state
        #expect(state == .unauthorized)
    }
}
