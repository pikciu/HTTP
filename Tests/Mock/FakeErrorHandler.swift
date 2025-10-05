import Foundation
import HTTP

actor FakeErrorHandler: ErrorHandler {
    private var results: [ErrorHandlerResult]
    private(set) var callCount = 0
    
    init(results: [ErrorHandlerResult] = []) {
        self.results = results
    }
    
    func setResults(_ results: [ErrorHandlerResult]) {
        self.results = results
        self.callCount = 0
    }
    
    func handle(error: HTTPError) async -> ErrorHandlerResult {
        defer { callCount += 1 }
        return results[callCount]
    }
}
