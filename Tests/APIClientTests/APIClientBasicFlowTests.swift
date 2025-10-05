import Testing
import Foundation
@testable import HTTP

@Suite("APIClient - Basic Flow")
struct APIClientBasicFlowTests {
    
    @Test func `execute request with valid token`() async throws {
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
        
        let request = TestRequest.valid()
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 200)
        #expect(await httpClient.executedRequests.count == 1)
        #expect(await authService.authorizeCallCount == 0)
        #expect(await authService.refreshTokenCallCount == 0)
        
        let executedRequest = await httpClient.executedRequests[0] as? AuthorizedRequest
        #expect(executedRequest?.token.token == JWT.valid.token)
    }
    
    @Test func `execute request with invalid token refreshes and succeeds`() async throws {
        let tokenManager = TokenManager.forTesting()
        await tokenManager.save(jwt: .expired)
        
        let httpClient = FakeHTTPClient(result: .success(.stub(statusCode: 200)))
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(refreshTokenResults: [
            .success(.valid)
        ])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 200)
        #expect(await httpClient.executedRequests.count == 1)
        #expect(await authService.refreshTokenCallCount == 1)
        #expect(await authService.authorizeCallCount == 0)
        
        let state = await tokenManager.state
        #expect(state == .valid(.valid))
        
        let executedRequest = await httpClient.executedRequests[0] as? AuthorizedRequest
        #expect(executedRequest?.token.token == JWT.valid.token)
    }
    
    @Test func `execute request when unauthorized performs authorization`() async throws {
        let tokenManager = TokenManager.forTesting()
        
        let httpClient = FakeHTTPClient(result: .success(.stub(statusCode: 200)))
        let errorHandler = FakeErrorHandler()
        let authService = FakeAuthorizationService(authorizeResults: [.success(.valid)])
        
        let apiClient = APIClient(
            httpClient: httpClient,
            tokenManager: tokenManager,
            errorHandler: errorHandler,
            authorizationService: authService
        )
        
        let request = TestRequest.valid()
        let response = try await apiClient.execute(request: request)
        
        #expect(response.httpURLResponse.statusCode == 200)
        #expect(await httpClient.executedRequests.count == 1)
        #expect(await authService.authorizeCallCount == 1)
        #expect(await authService.refreshTokenCallCount == 0)
        
        let state = await tokenManager.state
        #expect(state == .valid(.valid))
        
        let executedRequest = await httpClient.executedRequests[0] as? AuthorizedRequest
        #expect(executedRequest?.token.token == JWT.valid.token)
    }
}

extension Response {
    static func stub(statusCode: Int, data: Data = Data()) -> Response {
        let url = URL(string: "https://api.example.com")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return Response(httpURLResponse: httpResponse, data: data)
    }
}
