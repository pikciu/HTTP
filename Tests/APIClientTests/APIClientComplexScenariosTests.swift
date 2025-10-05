import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Complex Scenarios")
struct APIClientComplexScenariosTests {
    
    @Test func `deduplicated requests with invalidate token retry together`() async throws {
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
        
        async let a = apiClient.execute(request: request)
        async let b = apiClient.execute(request: request)
        
        let results = try await [a, b]
        
        #expect(results.count == 2)
        #expect(results[0].httpURLResponse.statusCode == 200)
        #expect(results[1].httpURLResponse.statusCode == 200)
        #expect(await httpClient.executedRequests.count == 2)
        #expect(await authService.refreshTokenCallCount == 1)
    }
    
    @Test func `invalidate token followed by logout on retry`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let errorResponse401 = Response.stub(statusCode: 401)
        let errorResponse403 = Response.stub(statusCode: 403)
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(errorResponse401)),
            .failure(.serverError(errorResponse403))
        ])
        let errorHandler = FakeErrorHandler(results: [
            .invalidateToken,
            .logout
        ])
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
        
        let state = await tokenManager.state
        #expect(state == .unauthorized)
        #expect(await authService.refreshTokenCallCount == 1)
    }
    
    @Test func `multiple error strategies in sequence`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .valid)
        
        let error400 = Response.stub(statusCode: 400)
        let error401 = Response.stub(statusCode: 401)
        let error500 = Response.stub(statusCode: 500)
        
        let httpClient = FakeHTTPClient(results: [
            .failure(.serverError(error400)),
            .failure(.serverError(error401)),
            .failure(.serverError(error500)),
            .success(.stub(statusCode: 200))
        ])
        let errorHandler = FakeErrorHandler(results: [
            .propagate,
            .invalidateToken,
            .propagate
        ])
        let authService = FakeAuthorizationService(refreshTokenResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request1 = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            try await apiClient.execute(request: request1)
        }
        
        let request2 = TestRequest.valid()
        
        await #expect(throws: HTTPError.self) {
            try await apiClient.execute(request: request2)
        }
        
        #expect(await httpClient.executedRequests.count == 3)
        #expect(await authService.refreshTokenCallCount == 1)
    }
    
    @Test func `unauthorized then invalid then valid token flow`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(results: [
            .failure(.other(TestError())),
            .success(.stub(statusCode: 200)),
        ])
        let errorHandler = FakeErrorHandler(results: [
            .invalidateToken,
        ])
        let authService = FakeAuthorizationService(
            authorizeResults: [.success(.expired)],
            refreshTokenResults: [
                .success(.valid),
                .success(.valid),
            ]
        )
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 200)
        #expect(await authService.authorizeCallCount == 1)
        #expect(await authService.refreshTokenCallCount == 2)
        #expect(await httpClient.executedRequests.count == 2)
        
        let state = await tokenManager.state
        #expect(state == .valid(.valid))
    }
}
