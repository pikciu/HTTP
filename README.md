# HTTP

A modern, thread-safe Swift networking library with automatic token management, request deduplication, and error handling.

## Features

- 🔐 **Automatic Token Management** - Transparent JWT handling with authorize/refresh/invalidate
- 🔄 **Request Deduplication** - Multiple identical requests share a single HTTP call
- 🎯 **Centralized Error Handling** - Pluggable strategy pattern for error responses
- ⚡️ **Actor-based Concurrency** - Thread-safe with Swift's modern concurrency
- 🧪 **Fully Tested** - Comprehensive test coverage
- 📦 **Zero Dependencies** - Built on Swift standard library

## Quick Start

### 1. Define Your Request

```swift
struct GetUserProfile: Request {
    let userID: Int
    
    // Control deduplication with UUID
    var id: UUID {
        UUID(uuidString: "user-profile-\(userID)") ?? UUID()
    }
    
    func urlRequest() throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.example.com/users/\(userID)")!)
        request.httpMethod = "GET"
        return request
    }
}
```

### 2. Implement Dependencies

```swift
class MyAuthService: AuthorizationService {
    func authorize() async throws(HTTPError) -> JWT {
        // Your authorization logic
    }
    
    func refreshToken(token: JWT) async throws(HTTPError) -> JWT {
        // Your token refresh logic
    }
}

class MyErrorHandler: ErrorHandler {
    func handle(error: HTTPError) async -> ErrorHandlerResult {
        switch error {
        case .serverError(let response) where response.httpURLResponse.statusCode == 401:
            return .invalidateToken
        case .serverError(let response) where response.httpURLResponse.statusCode == 403:
            return .logout
        default:
            return .propagate
        }
    }
}
```

### 3. Create APIClient

```swift
let tokenManager = TokenManager(defaults: .standard)
let authService = MyAuthService()
let errorHandler = MyErrorHandler()

let apiClient = APIClient(
    httpClient: URLSession.shared,
    tokenManager: tokenManager,
    errorHandler: errorHandler,
    authorizationService: authService
)
```

### 4. Execute Requests

```swift
let request = GetUserProfile(userId: 123)
let response = try await apiClient.execute(request: request)
```

With JSON decoding:

```swift
struct User: Decodable {
    let id: Int
    let name: String
}

let user: User = try await apiClient.responseJSON(request: request)
```

## Architecture

### Diagrams

- [Request Flow Diagram](docs/FLOW_DIAGRAM.md) - Visual representation of request execution flow
- [Class Diagram](docs/CLASS_DIAGRAM.md) - Component relationships and responsibilities

### Core Components

#### APIClient (Actor)
The main entry point. Coordinates request execution, deduplication, and token management.

**Key Responsibilities:**
- Request deduplication based on `Request.id`
- Token lifecycle management (authorize/refresh/invalidate)
- Error handling delegation
- Thread-safe state management

#### TokenManager (Actor)
Manages JWT token storage and state.

**States:**
- `.valid(JWT)` - Token is valid, use it
- `.invalid(JWT)` - Token expired, refresh needed
- `.unauthorized` - No token, authorization required

**Features:**
- Persistent storage in UserDefaults
- Automatic expiration detection
- Manual invalidation support

#### ErrorHandler (Protocol)
Defines application-specific error handling strategy.

**Strategies:**
- `.propagate` - Return error to caller
- `.invalidateToken` - Mark token invalid, trigger refresh
- `.logout` - Clear all tokens, terminate pending requests

#### AuthorizationService (Protocol)
Handles authentication operations.

**Methods:**
- `authorize()` - Initial authentication
- `refreshToken(token:)` - Token refresh

## Advanced Features

### Request Deduplication

Control deduplication behavior through `Request.id`:

```swift
// Always deduplicate same user
struct GetUser: Request {
    let userId: Int
    var id: UUID { 
        UUID(uuidString: "user-\(userId)") ?? UUID() 
    }
}

// Never deduplicate (fresh data)
struct GetFeed: Request {
    var id: UUID { UUID() }
}

// Deduplicate all instances
struct GetConfig: Request {
    let id = UUID(uuidString: "config")!
}
```

### Sequential Authorization/Refresh

When multiple requests need authorization/refresh simultaneously:
- ✅ Only ONE authorize/refresh executes
- ✅ Other requests wait on `AsyncLock`
- ✅ After completion, all proceed with updated token
- ✅ No parallel token operations

### Error Handling Flow

```
HTTP Error → ErrorHandler.handle()
    ↓
.propagate → Return error to caller
    ↓
.invalidateToken → Invalidate token → Refresh → Retry request
    ↓
.logout → Clear tokens → Fail all pending requests
```

### Retry Behavior

When `authorize()` or `refreshToken()` fails:
- First request fails and returns error
- **Subsequent waiting requests retry sequentially**
- Designed for transient network errors
- Each request gets independent retry attempt

**Rationale:** Authorization failures are often temporary (network glitches). Sequential retries maximize recovery chances without thundering herd.

## Architecture Decisions

### Why Actor for APIClient?

**Decision:** Use Swift Actor instead of class + locks

**Rationale:**
- Thread-safe state management (requests dictionary)
- Prevents data races in concurrent environments
- Clean suspension points for async operations
- Native Swift Concurrency integration

**Trade-offs:**
- ✅ Memory safety guaranteed by compiler
- ✅ No manual lock management
- ❌ More `await` calls (suspension points)

### Why Custom AsyncLock?

**Decision:** Implement custom `AsyncLock` actor instead of using Task-based approach

**Rationale:**
- Prevents parallel authorize/refresh operations
- Simple barrier pattern for async operations
- Actor isolation ensures atomic check-and-set

**Trade-offs:**
- ✅ Atomic operations (actor isolation)
- ✅ Simple API
- ✅ No task overhead
- ❌ Custom implementation (not stdlib)

### Why NOT Task<JWT, Error> for Deduplication?

**Considered:** Using `Task` to share authorize/refresh results

**Rejected Reason:**
- Would share error/success result with all waiting requests
- Our design: each request retries independently on failure
- Better for transient errors (network glitches)

**Current Approach:**
- Requests wait for operation to complete
- After completion, each checks token state independently
- Each can retry if previous attempt failed

**Trade-offs:**
- ✅ Resilient to transient failures
- ✅ No error propagation to unrelated requests
- ❌ More authorize/refresh calls on persistent failures

### Why Sequential Retry on Auth Failure?

**Decision:** When authorize/refresh fails, subsequent requests retry (not fail immediately)

**Rationale:**
- Network errors are often transient
- Authorization servers may have temporary issues
- Sequential retry maximizes recovery without thundering herd
- Each request is independent (different users, contexts)

**Example:**
```
Request A: authorize() → network timeout → fail
Request B: (waiting) → authorize() → success ✅
Request C: (waiting) → uses new token from B
```

**Trade-offs:**
- ✅ Resilient to transient network errors
- ✅ No premature failure of valid requests
- ❌ Multiple auth calls on persistent failures
- ❌ Longer error feedback for subsequent requests

**When to Reconsider:**
- If auth failures are always persistent (bad credentials)
- If you want fail-fast behavior
- If auth server rate-limits retries

### Why Actor for TokenManager?

**Decision:** TokenManager as actor with lazy initialization

**Rationale:**
- Thread-safe state management via actor isolation
- Lazy loading from UserDefaults on first access
- Automatic Sendable conformance (no `@unchecked` needed)
- Clean separation of concerns

**Trade-offs:**
- ✅ Compiler-verified thread safety
- ✅ Automatic Sendable conformance
- ✅ No manual lock management
- ❌ Requires `await` for state access (suspension point)
- ❌ Potential for state changes between reads

**Why This Works:**
With `AsyncLock` preventing parallel authorize/refresh operations, the suspension points in `tokenManager.state` are acceptable. The state is stable during critical operations.

### Why Guard Against Completed Requests?

**Decision:** Check `requests[request.id] != nil` before operations

**Problem:** Dead-lock scenario
```swift
1. Request completes → continuation resumed → removed from dictionary
2. Same request ID arrives again while cleanup happening
3. Tries to operate on non-existent continuation → crash
```

**Trade-offs:**
- ✅ Prevents crashes
- ✅ Graceful handling of race conditions
- ✅ Supports cancellation patterns
- ❌ Extra checks in hot path

### Why JWT Invalidation Instead of Deletion?

**Decision:** Mark JWT as `isInvalidated` instead of deleting

**Rationale:**
- Need to pass old token to `refreshToken(token:)`
- Server may need old token for refresh validation
- Preserves token metadata (expiry, etc.)

**Trade-offs:**
- ✅ Server receives old token for validation
- ✅ Immutable struct (Sendable)
- ✅ Clear state transitions
- ❌ Extra field in JWT struct

### Request Cancellation

**Decision:** The package does NOT support explicit request cancellation.

**Rationale:**
- Requests are typically short-lived (network operations complete in seconds)
- Cost of incomplete request is minimal (wasted bandwidth for remaining time)
- Implementation complexity vs. benefit trade-off
- Continuation must be resumed exactly once (cancellation adds complexity)

**Current Behavior:**
When a user navigates away from a screen:
- Request continues executing in background
- Response is received but discarded (no continuation to resume)
- Minimal resource waste (typically < 1 second of execution)