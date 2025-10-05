import Foundation
import HTTP

struct FakeResponseMapper: ResponseMapper {
    let result: Result<String, Error>
    
    func map(response: Response) throws -> String {
        try result.get()
    }
}
