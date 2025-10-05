import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Token Management")
struct APIClientTokenManagementTests {
    
    @Test func `saves token after successful authorization`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(result: .success(.stub(statusCode: 200)))
        let errorHandler = FakeErrorHandler()
        let newToken = JWT.valid
        let authService = FakeAuthorizationService(authorizeResults: [.success(newToken)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        
        _ = try await apiClient.execute(request: request)
        
        let state = await tokenManager.state
        #expect(state == .valid(newToken))
    }
    
    @Test func `saves token after successful token refresh`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(result: .success(.stub(statusCode: 200)))
        let errorHandler = FakeErrorHandler()
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
        
        let state = await tokenManager.state
        #expect(state == .valid(refreshedToken))
    }
    
    @Test func `multiple requests with invalid token trigger single refresh`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(results: [
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
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        async let c = apiClient.execute(request: request3)
        _ = try await [a, b, c]
        
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await httpClient.executedRequests.count == 3)
    }
    
    @Test func `multiple requests when unauthorized trigger single authorization`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200)),
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
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        let request3 = TestRequest.valid()
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        async let c = apiClient.execute(request: request3)
        _ = try await [a, b, c]
        
        #expect(await authService.authorizeCallCount == 1)
        #expect(await httpClient.executedRequests.count == 3)
    }
    
    @Test func `request waits for ongoing token refresh`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(results: [
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
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        
        let results = try await [a, b]
        
        #expect(results.count == 2)
        #expect(await authService.refreshTokenCallCount == 1)
        
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
    }
    
    @Test func `request waits for ongoing authorization`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: [
            .success(.stub(statusCode: 200)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(authorizeResults: [
            .success(.valid),
            .success(.valid), // delete
        ])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        let request2 = TestRequest.valid()
        
        async let a = apiClient.execute(request: request1)
        async let b = apiClient.execute(request: request2)
        
        let results = try await [a, b]
        
        #expect(results.count == 2)
        #expect(await authService.authorizeCallCount == 1)
        
        results.forEach { response in
            #expect(response.httpURLResponse.statusCode == 200)
        }
    }
}
