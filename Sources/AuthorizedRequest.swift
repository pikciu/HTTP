import Foundation

struct AuthorizedRequest: Request {
    var id: UUID {
        request.id
    }
    
    let request: any Request
    let token: JWT
    
    func urlRequest() throws -> URLRequest {
        var urlRequest = try request.urlRequest()
        urlRequest.addValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization")
        return urlRequest
    }
}
