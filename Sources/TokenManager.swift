import Foundation

public actor TokenManager {
    enum State: Equatable {
        case valid(JWT)
        case invalid(JWT)
        case unauthorized
    }
    private let key = "TokenManager.Token"
    private let defaults: UserDefaults
    private lazy var token: JWT? = defaults.decode(forKey: key) {
        didSet {
            defaults.encode(token, forKey: key)
        }
    }
    
    var state: State {
        if let token = token {
            if token.isValid {
                return .valid(token)
            } else {
                return .invalid(token)
            }
        } else {
            return .unauthorized
        }
    }
    
    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    
    func invalidate(jwt: JWT) {
        guard token?.token == jwt.token else { return }
        
        token = jwt.invalidated()
    }
    
    func reset() {
        token = nil
    }
    
    func save(jwt: JWT) {
        token = jwt
    }
}

extension UserDefaults {
    func encode<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value = value else {
            removeObject(forKey: key)
            return
        }
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(value)
            set(data, forKey: key)
        } catch {
            debugPrint("HTTP: Failed to encode \(T.self): \(error)")
        }
    }
    
    func decode<T: Decodable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            debugPrint("HTTP: Failed to decode \(T.self): \(error)")
            return nil
        }
    }
}
