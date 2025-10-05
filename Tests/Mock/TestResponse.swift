import Foundation

struct TestResponse: Decodable, Equatable {

    let name: String

    var json: String {
        "{\"name\":\"\(name)\"}"
    }

    var data: Data {
        json.data(using: .utf8)!
    }
}
