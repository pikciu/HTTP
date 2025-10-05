import Combine

public protocol ResponseMapper {
    associatedtype Output

    func map(response: Response) throws -> Output
}
