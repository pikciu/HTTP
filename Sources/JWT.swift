import Foundation

public struct JWT: Codable, Equatable, Sendable {
    struct InvalidToken: Error { }
    
    private struct Payload: Decodable {
        let exp: TimeInterval
    }
    
    let token: String
    let expiresAt: Date
    let isInvalidated: Bool
    
    var isExpired: Bool {
        expiresAt < Date()
    }
    
    var isValid: Bool {
        !isInvalidated && !isExpired
    }
    
    enum CodingKeys: CodingKey {
        case isInvalidated
        case token
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isInvalidated = try container.decodeIfPresent(Bool.self, forKey: .isInvalidated)
        let token = try container.decode(String.self, forKey: .token)
        
        try self.init(token: token, isInvalidated: isInvalidated ?? false)
    }
    
    init(token: String, isInvalidated: Bool = false) throws {
        self.token = token
        self.isInvalidated = isInvalidated
        
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw InvalidToken()
        }
        
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }
        
        guard let data = Data(base64Encoded: String(base64), options: [])
        else {
            throw InvalidToken()
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        self.expiresAt = Date(timeIntervalSince1970: payload.exp)
    }
    
    private init(
        token: String,
        expiresAt: Date,
        isInvalidated: Bool
    ) {
        self.token = token
        self.expiresAt = expiresAt
        self.isInvalidated = isInvalidated
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.isInvalidated, forKey: .isInvalidated)
        try container.encode(self.token, forKey: .token)
    }
    
    func invalidated() -> JWT {
        JWT(
            token: token,
            expiresAt: expiresAt,
            isInvalidated: true
        )
    }
}
