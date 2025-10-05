import Foundation

public struct Response {
    public let httpURLResponse: HTTPURLResponse
    public let data: Data

    var isSuccessful: Bool {
        200 ..< 300 ~= httpURLResponse.statusCode
    }

    init(httpURLResponse: HTTPURLResponse, data: Data) {
        self.httpURLResponse = httpURLResponse
        self.data = data
    }
}
