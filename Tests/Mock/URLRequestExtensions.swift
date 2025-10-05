import Foundation
import HTTP

extension URLRequest: @retroactive Identifiable {}

extension URLRequest: Request {
    public var id: UUID {
        UUID()
    }
    
    public func urlRequest() throws -> URLRequest {
        self
    }
}
