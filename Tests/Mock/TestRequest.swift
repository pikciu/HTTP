import Foundation
import HTTP

struct TestRequest: Request {
    let id = UUID()
    
    let result: Result<URLRequest, Error>
    
    func urlRequest() throws -> URLRequest {
        try result.get()
    }
    
    static func throwing(error: Error) -> TestRequest {
        TestRequest(result: .failure(error))
    }
    
    static func valid() -> TestRequest {
        TestRequest(result: .success(URLRequest(url: URL(string: "https://example.com/test")!)))
    }
}
