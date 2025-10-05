import Foundation

public enum ErrorHandlerResult {
    case propagate
    case invalidateToken
    case logout
}

public protocol ErrorHandler {
    func handle(error: HTTPError) async -> ErrorHandlerResult
}
