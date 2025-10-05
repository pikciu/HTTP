import Foundation

public protocol AuthorizationService {
    func authorize() async throws(HTTPError) -> JWT
    func refreshToken(token: JWT) async throws(HTTPError) -> JWT
}
