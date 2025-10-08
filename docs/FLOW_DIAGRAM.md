# APIClient Request Flow Diagram

This diagram illustrates the complete request execution flow in the HTTP package, including:
- Request deduplication
- AsyncLock synchronization for authorize/refresh operations
- Token state management
- Error handling strategies
- Retry mechanisms

## Flow Diagram

```mermaid
graph TD
    Start([execute request]) --> CheckQueue{Request ID in queue?}
    
    CheckQueue -->|YES| AddCont[Add continuation to queue]
    CheckQueue -->|NO| CreateQueue[Create queue + add continuation]
    
    AddCont --> Wait[Wait for result...]
    CreateQueue --> ExecuteAsync[executeAsync]
    
    ExecuteAsync --> WaitLock[AsyncLock.wait]
    CheckCancelled -->|NO| EndCancelled([Request finished])
    CheckCancelled -->|YES| CheckToken{await tokenManager.state}
    
    WaitLock --> CheckCancelled{requests id exists?}
    
    CheckToken -->|VALID| ExecAuth[executeAuthorized]
    CheckToken -->|INVALID| RefreshFlow[refreshTokenThenExecute]
    CheckToken -->|UNAUTHORIZED| AuthFlow[authorizeThenExecute]
    
    AuthFlow --> TryAuth[AsyncLock.tryExecute]
    RefreshFlow --> TryRefresh[AsyncLock.tryExecute]
    
    TryAuth -->|Locked| ExecuteAsync
    TryAuth -->|Unlocked| DoAuth[authorizationService.authorize]
    
    TryRefresh -->|Locked| ExecuteAsync
    TryRefresh -->|Unlocked| DoRefresh[authorizationService.refreshToken]
    
    DoAuth --> JWTResult{Success?}
    DoRefresh --> JWTResult{Success?}
    
    JWTResult -->|YES| SaveToken[tokenManager.save + unlock]
    JWTResult -->|NO| HandleAuthError[handleAuthorizationError + unlock]
    
    SaveToken --> ExecuteAsync
    
    HandleAuthError --> HandleStrategy{errorHandler.handle}
    
    HandleStrategy -->|PROPAGATE| ResumeError2([Throw HTTPError])
    HandleStrategy -->|INVALIDATE or LOGOUT| ResumeAllError2([Throw HTTPError to all requests + reset])
    
    ExecAuth --> CreateAuthReq[Create AuthorizedRequest]
    
    CreateAuthReq --> HTTPCall[httpClient.execute]
    
    HTTPCall --> HTTPResult{Result?}
    
    HTTPResult -->|SUCCESS| ResumeSuccess([Resume request with Response])
    HTTPResult -->|ERROR| HandleHTTPError{errorHandler.handle}
    
    HandleHTTPError -->|PROPAGATE| ResumeError1([Throw HTTPError])
    HandleHTTPError -->|LOGOUT| ResumeAllError1([Throw HTTPError to all requests + reset])
    HandleHTTPError -->|INVALIDATE_TOKEN| Invalidate[tokenManager.invalidate]
    
    Invalidate --> ExecuteAsync

    
    style Start fill:#e1f5e1
    style ResumeSuccess fill:#e1f5e1
    style ResumeError1 fill:#ffe1e1
    style ResumeError2 fill:#ffe1e1
    style ResumeAllError1 fill:#ffe1e1
    style ResumeAllError2 fill:#ffe1e1
    style EndCancelled fill:#ffd700
    
    style CheckQueue fill:#fff4e1
    style CheckToken fill:#fff4e1
    style HTTPResult fill:#fff4e1
    style CheckCancelled fill:#fff4e1
    style JWTResult fill:#fff4e1
    
    style HandleHTTPError fill:#ffcccc
    
    style WaitLock fill:#e1e5ff
    style TryAuth fill:#e1e5ff
    style TryRefresh fill:#e1e5ff
    style HTTPCall fill:#e1e5ff
    
    style DoAuth fill:#ffe1ff
    style DoRefresh fill:#ffe1ff
```

## Legend

- 🟢 **Green** - Success paths
- 🔴 **Red** - Error/failure endpoints
- 🟡 **Yellow** - Cancellation/completion
- 🔵 **Blue** - Synchronization operations (AsyncLock)
- 🟣 **Purple** - External service calls (AuthorizationService)
- 🟠 **Orange** - Decision points

## Key Flow Points

### 1. Request Deduplication
Multiple requests with the same ID share a single execution. Additional requests wait for the first to complete.

### 2. AsyncLock Protection
`AsyncLock.wait()` ensures only one authorize/refresh operation executes at a time. Other requests wait at the barrier.

### 3. Token State Check
After waiting, each request independently checks token state, which may have changed during the wait.

### 4. Sequential Retry
If authorize/refresh fails, subsequent requests retry sequentially (not in parallel). This design handles transient network errors.

### 5. Guard Checks
Before critical operations, the code checks if `requests[id]` still exists, preventing crashes from already-completed requests.

### 6. Error Strategies
- **PROPAGATE** - Return error to specific request
- **INVALIDATE_TOKEN** - Invalidate token and retry request
- **LOGOUT** - Fail all pending requests and reset tokens

## Example Scenarios

### Scenario 1: Multiple Unauthorized Requests
```
Request A, B, C arrive (all unauthorized)
→ All wait at AsyncLock
→ Request A wins tryExecute, calls authorize()
→ B and C wait
→ A completes, saves token, unlocks
→ B wakes up, sees valid token, executes
→ C wakes up, sees valid token, executes
```

### Scenario 2: 401 Error with Token Refresh
```
Request executes with valid token
→ Server returns 401
→ errorHandler returns INVALIDATE_TOKEN
→ tokenManager.invalidate()
→ executeAsync again
→ Token now invalid, triggers refresh
→ After refresh, retry with new token
```

### Scenario 3: Deduplication
```
Request A starts (ID: 123)
Request B arrives (ID: 123) - same ID!
→ B's continuation added to queue
→ Only one HTTP call executes
→ Both A and B receive same response
```