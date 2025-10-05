import Foundation
import Testing
@testable import HTTP

@Suite
struct TokenManagerTests {
    private let key = "TokenManager.Token"
    
    @Test
    func `Initial unauthorized`() async {
        let sut = TokenManager.forTesting()
        
        let state = await sut.state
        
        #expect(state == .unauthorized)
    }
    
    @Test
    func `Initial valid`() async {
        let defaults = UserDefaults.forTesting()
        defaults.encode(JWT.valid, forKey: key)
        let sut = TokenManager(defaults: defaults)
        
        let state = await sut.state
        
        #expect(state == .valid(JWT.valid))
    }
    
    @Test
    func `Initial expired`() async {
        let defaults = UserDefaults.forTesting()
        defaults.encode(JWT.expired, forKey: key)
        let sut = TokenManager(defaults: defaults)
        
        let state = await sut.state
        
        #expect(state == .invalid(JWT.expired))
    }
    
    @Test
    func `Initial invalidted`() async {
        let defaults = UserDefaults.forTesting()
        defaults.encode(JWT.invalidted, forKey: key)
        let sut = TokenManager(defaults: defaults)
        
        let state = await sut.state
        
        #expect(state == .invalid(JWT.invalidted))
    }
    
    @Test
    func `State should be valid after saving valid JWT`() async {
        let sut = TokenManager.forTesting()
        
        await sut.save(jwt: JWT.valid)
        let state = await sut.state
        
        #expect(state == .valid(JWT.valid))
    }
    
    @Test
    func `Saving JWT should persist token`() async {
        let defaults = UserDefaults.forTesting()
        let old = TokenManager(defaults: defaults)
        
        await old.save(jwt: JWT.valid)
        
        let new = TokenManager(defaults: defaults)
        let state = await new.state
        #expect(state == .valid(JWT.valid))
    }

    @Test
    func `Saving new JWT should replace old JWT`() async {
        let sut = TokenManager.forTesting()
        
        await sut.save(jwt: JWT.expired)
        await sut.save(jwt: JWT.valid)
        
        let state = await sut.state
        #expect(state == .valid(JWT.valid))
    }
    
    @Test
    func `Reset should clear token`() async {
        let sut = TokenManager.forTesting()
        await sut.save(jwt: JWT.valid)
        await sut.reset()
        
        let state = await sut.state
        #expect(state == .unauthorized)
    }
    
    @Test
    func `Invalidate should mark token as invalidated`() async {
        let sut = TokenManager.forTesting()
        var token = JWT.valid
        await sut.save(jwt: token)
        await sut.invalidate(jwt: token)
        
        let state = await sut.state
        token = token.invalidated()
        #expect(state == .invalid(token))
    }
    
    @Test
    func `Invalidate should not affect different token`() async {
        let sut = TokenManager.forTesting()
        
        await sut.save(jwt: JWT.valid)
        await sut.invalidate(jwt: .expired)
        
        let state = await sut.state
        #expect(state == .valid(JWT.valid))
    }
    
    @Test
    func `Invalidate should persist invalidated state`() async {
        let defaults = UserDefaults.forTesting()
        let old = TokenManager(defaults: defaults)
        var token = JWT.valid
        await old.save(jwt: token)
        await old.invalidate(jwt: token)
        
        let new = TokenManager(defaults: defaults)
        let state = await new.state
        token = token.invalidated()
        #expect(state == .invalid(token))
    }
}

extension JWT {
    static let valid: JWT = {
        try! JWT(
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6NDkxNDQ3NDk0OX0.FCHgTbdMAvpEj6EzA-uBw6_ECKd_jqcmDEdWx7tNjrg",
            isInvalidated: false
        )
    }()
    
    static let expired: JWT = {
        try! JWT(
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6MTc1ODgwODY0MX0.RJ2YmgReHn1aZLgQbg3SEHU-Mtg15RGb4IXSHE8WKP4",
            isInvalidated: false
        )
    }()
    
    static let invalidted: JWT = {
        try! JWT(
            token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6NDkxNDQ3NDk0OX0.FCHgTbdMAvpEj6EzA-uBw6_ECKd_jqcmDEdWx7tNjrg",
            isInvalidated: true
        )
    }()
}

extension TokenManager {
    static func forTesting(suiteName: String = #function) -> TokenManager {
        TokenManager(defaults: .forTesting(suiteName: suiteName))
    }
}

extension UserDefaults {
    static func forTesting(suiteName: String = #function) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
