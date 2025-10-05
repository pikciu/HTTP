import Foundation
import HTTP

actor FakeAuthorizationService: AuthorizationService {
    private(set) var authorizeResults: [Result<JWT, HTTPError>]
    private(set) var refreshTokenResults: [Result<JWT, HTTPError>]
    
    private(set) var authorizeCallCount = 0
    private(set) var refreshTokenCallCount = 0
    
    init(
        authorizeResults: [Result<JWT, HTTPError>] = [],
        refreshTokenResults: [Result<JWT, HTTPError>] = []
    ) {
        self.authorizeResults = authorizeResults
        self.refreshTokenResults = refreshTokenResults
    }
    
    func setAuthorizeResults(_ results: [Result<JWT, HTTPError>]) {
        authorizeResults = results
        authorizeCallCount = 0
    }
    
    func setRefreshTokenResults(_ results: [Result<JWT, HTTPError>]) {
        refreshTokenResults = results
        refreshTokenCallCount = 0
    }
    
    func authorize() async throws(HTTPError) -> JWT {
        defer { authorizeCallCount += 1 }
        return try authorizeResults[authorizeCallCount].get()
    }
    
    func refreshToken(token: JWT) async throws(HTTPError) -> JWT {
        defer { refreshTokenCallCount += 1 }
        return try refreshTokenResults[refreshTokenCallCount].get()
    }
}
