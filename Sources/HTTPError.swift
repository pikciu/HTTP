import Foundation

public enum HTTPError: Error {
    case requestError(Error)
    case responseMapperError(Response, Error)
    case serverError(Response)
    case urlError(URLError)
    case other(Error)
}
