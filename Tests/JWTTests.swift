import Testing
import Foundation
@testable import HTTP

@Suite("JWT Tests")
struct JWTTests {
    
    static let validToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6NDkxNDQ3NDk0OX0.FCHgTbdMAvpEj6EzA-uBw6_ECKd_jqcmDEdWx7tNjrg"
    static let expiredToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImV4cCI6MTc1ODgwODY0MX0.RJ2YmgReHn1aZLgQbg3SEHU-Mtg15RGb4IXSHE8WKP4"
    
    @Test
    func `init with valid token`() throws {
        let token = JWTTests.validToken
        
        let jwt = try JWT(token: token)
        
        #expect(jwt.token == token)
        #expect(jwt.isInvalidated == false)
        #expect(jwt.isExpired == false)
        #expect(jwt.isValid == true)
        #expect(jwt.expiresAt > Date())
    }
    
    @Test
    func `init with valid token and invalidated flag`() throws {
        let token = JWTTests.validToken
        
        let jwt = try JWT(token: token, isInvalidated: true)
        
        #expect(jwt.token == token)
        #expect(jwt.isInvalidated == true)
        #expect(jwt.isValid == false)
    }
    
    @Test(arguments: [
        "invalid",
        "only.two",
        "",
        "....",
        "one"
    ])
    func `init with invalid tokens`(token: String) {
        #expect(throws: JWT.InvalidToken.self) {
            try JWT(token: token)
        }
    }
    
    @Test
    func `init with invalid base 64 payload`() {
        let invalidToken = "header.!!!invalid-base64!!!.signature"
        
        #expect(throws: JWT.InvalidToken.self) {
            try JWT(token: invalidToken)
        }
    }
    
    @Test
    func `init with invalid json payload`() {
        let invalidPayload = "not-json"
        let base64Payload = Data(invalidPayload.utf8).base64EncodedString()
        let token = "header.\(base64Payload).signature"
        
        #expect(throws: Error.self) {
            try JWT(token: token)
        }
    }
    
    @Test
    func `init with missing exp in payload`() {
        let payloadWithoutExp = "{\"sub\":\"user123\"}"
        let base64Payload = Data(payloadWithoutExp.utf8).base64EncodedString()
        let token = "header.\(base64Payload).signature"
        
        #expect(throws: Error.self) {
            try JWT(token: token)
        }
    }
    
    @Test
    func `expired token`() throws {
        let token = JWTTests.expiredToken
        
        let jwt = try JWT(token: token)
        
        #expect(jwt.isExpired == true)
        #expect(jwt.isValid == false)
        #expect(jwt.expiresAt < Date())
    }
    
    @Test
    func `not invalidated and not expired token`() throws {
        let jwt = try JWT(token: JWTTests.validToken, isInvalidated: false)
        
        #expect(jwt.isInvalidated == false)
        #expect(jwt.isExpired == false)
        #expect(jwt.isValid == true)
    }
    
    @Test
    func `invalidated and not expired token`() throws {
        let jwt = try JWT(token: JWTTests.validToken, isInvalidated: true)
        
        #expect(jwt.isInvalidated == true)
        #expect(jwt.isExpired == false)
        #expect(jwt.isValid == false)
    }
    
    @Test
    func `not invalidated but expired token`() throws {
        let jwt = try JWT(token: JWTTests.expiredToken, isInvalidated: false)
        
        #expect(jwt.isInvalidated == false)
        #expect(jwt.isExpired == true)
        #expect(jwt.isValid == false)
    }
    
    @Test
    func `init with ignored fields`() throws {
        let exp = Date().addingTimeInterval(3600).timeIntervalSince1970
        let payload = """
        {
            "exp": \(exp),
            "sub": "user123",
            "iat": \(Date().timeIntervalSince1970),
            "custom_field": "custom_value"
        }
        """
        let base64Payload = Data(payload.utf8).base64EncodedString()
        let token = "header.\(base64Payload).signature"
        
        let jwt = try JWT(token: token)
        
        #expect(jwt.isExpired == false)
        #expect(jwt.token == token)
    }
    
    @Test
    func `decode with ignored fileds`() throws {
        let token = JWTTests.validToken
        let json = """
        {
            "token": "\(token)",
            "isInvalidated": false,
            "extraField": "ignored",
            "anotherField": 123
        }
        """
        
        let data = json.data(using: .utf8)!
        let jwt = try JSONDecoder().decode(JWT.self, from: data)
        
        #expect(jwt.token == token)
        #expect(jwt.isInvalidated == false)
    }
    
    @Suite("JSON Encoding/Decoding Tests")
    struct JSONEncodingTests {
        func `encode`() throws {
            let token = validToken
            let jwt = try JWT(token: token, isInvalidated: true)
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(jwt)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            #expect(json?["token"] as? String == token)
            #expect(json?["isInvalidated"] as? Bool == true)
            #expect(json?["expiresAt"] == nil)
        }
        
        @Test
        func `decode with isInvalidated flag`() throws {
            let token = validToken
            let json = """
            {
                "token": "\(token)",
                "isInvalidated": true
            }
            """
            
            let data = json.data(using: .utf8)!
            let jwt = try JSONDecoder().decode(JWT.self, from: data)
            
            #expect(jwt.token == token)
            #expect(jwt.isInvalidated == true)
            #expect(jwt.expiresAt > Date())
        }
        
        @Test
        func `decode without isInvalidated flag`() throws {
            let token = validToken
            let json = """
            {
                "token": "\(token)"
            }
            """
            
            let data = json.data(using: .utf8)!
            let jwt = try JSONDecoder().decode(JWT.self, from: data)
            
            #expect(jwt.isInvalidated == false)
            #expect(jwt.token == token)
        }
        
        @Test
        func `decode with missing required field`() {
            let json = """
            {
                "isInvalidated": false
            }
            """
            
            let data = json.data(using: .utf8)!
            
            #expect(throws: Error.self) {
                try JSONDecoder().decode(JWT.self, from: data)
            }
        }
        
        @Test
        func `decode with invalid token`() {
            let json = """
            {
                "token": "invalid.token",
                "isInvalidated": false
            }
            """
            
            let data = json.data(using: .utf8)!
            
            #expect(throws: JWT.InvalidToken.self) {
                try JSONDecoder().decode(JWT.self, from: data)
            }
        }
        
        @Test
        func `encode and decode`() throws {
            let token = validToken
            let jwt = try JWT(token: token, isInvalidated: true)
            
            let encoder = JSONEncoder()
            let data = try encoder.encode(jwt)
            
            let decoder = JSONDecoder()
            let decodedJWT = try decoder.decode(JWT.self, from: data)
            
            #expect(decodedJWT.token == token)
            #expect(decodedJWT.isInvalidated == jwt.isInvalidated)
            #expect(abs(decodedJWT.expiresAt.timeIntervalSince(jwt.expiresAt)) < 1)
        }
    }
}
