import HTTP

extension HTTPError {
    var isURLError: Bool {
        if case .urlError = self {
            return true
        }
        return false
    }
    
    var isResponseMapperError: Bool {
        if case .responseMapperError = self {
            return true
        }
        return false
    }
    
    var isServerError: Bool {
        if case .serverError = self {
            return true
        }
        return false
    }
    
    var isRequestError: Bool {
        if case .requestError = self {
            return true
        }
        return false
    }
    
    var isOtherError: Bool {
        if case .other = self {
            return true
        }
        return false
    }
}
