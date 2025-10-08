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
    CreateQueue --> TaskExec[Task executeAsync]
    
    TaskExec --> CheckCancelled{requests id exists?}
    CheckCancelled -->|NO| EndCancelled([Request finished])
    CheckCancelled -->|YES| WaitLock[AsyncLock.wait]
    
    WaitLock --> CheckToken{await tokenManager.state}
    
    CheckToken -->|VALID| ExecAuth[executeAuthorized]
    CheckToken -->|INVALID| RefreshFlow[refreshTokenThenExecute]
    CheckToken -->|UNAUTHORIZED| AuthFlow[authorizeThenExecute]
    
    AuthFlow --> TryAuth[AsyncLock.tryExecute]
    RefreshFlow --> TryRefresh[AsyncLock.tryExecute]
    
    TryAuth -->|Locked| ReExecute1[executeAsync again]
    TryAuth -->|Unlocked| DoAuth[authorizationService.authorize]
    
    TryRefresh -->|Locked| ReExecute2[executeAsync again]
    TryRefresh -->|Unlocked| DoRefresh[authorizationService.refreshToken]
    
    DoAuth --> AuthResult{Success?}
    DoRefresh --> RefreshResult{Success?}
    
    AuthResult -->|YES| SaveToken1[tokenManager.save + unlock]
    AuthResult -->|NO| HandleAuthErr1[handleAuthorizationError + unlock]
    
    RefreshResult -->|YES| SaveToken2[tokenManager.save + unlock]
    RefreshResult -->|NO| HandleAuthErr2[handleAuthorizationError + unlock]
    
    SaveToken1 --> ReExecute3[executeAsync again]
    SaveToken2 --> ReExecute4[executeAsync again]
    
    HandleAuthErr1 --> HandleStrategy1{errorHandler.handle}
    HandleAuthErr2 --> HandleStrategy2{errorHandler.handle}
    
    HandleStrategy1 -->|PROPAGATE| Resume1[Resume request with error]
    HandleStrategy1 -->|INVALIDATE or LOGOUT| ResumeAll1[Resume all + reset]
    
    HandleStrategy2 -->|PROPAGATE| Resume2[Resume request with error]
    HandleStrategy2 -->|INVALIDATE or LOGOUT| ResumeAll2[Resume all + reset]
    
    ReExecute1 --> CheckCancelled
    ReExecute2 --> CheckCancelled
    ReExecute3 --> CheckCancelled
    ReExecute4 --> CheckCancelled
    
    ExecAuth --> CheckCancelled2{requests id exists?}
    CheckCancelled2 -->|NO| EndCancelled2([Request cancelled])
    CheckCancelled2 -->|YES| CreateAuthReq[Create AuthorizedRequest]
    
    CreateAuthReq --> HTTPCall[httpClient.execute]
    
    HTTPCall --> HTTPResult{Result?}
    
    HTTPResult -->|SUCCESS| ResumeSuccess[Resume with Response]
    HTTPResult -->|ERROR| HandleHTTPError{errorHandler.handle}
    
    HandleHTTPError -->|PROPAGATE| Resume3[Resume with error]
    HandleHTTPError -->|INVALIDATE_TOKEN| Invalidate[tokenManager.invalidate then executeAsync]
    HandleHTTPError -->|LOGOUT| ResumeAll3[Resume all + reset]
    
    Invalidate --> CheckToken
    
    ResumeSuccess --> End1([Return Response])
    Resume1 --> End2([Throw HTTPError])
    Resume2 --> End3([Throw HTTPError])
    Resume3 --> End4([Throw HTTPError])
    ResumeAll1 --> End5([Throw HTTPError])
    ResumeAll2 --> End6([Throw HTTPError])
    ResumeAll3 --> End7([Throw HTTPError])
    Wait --> End8([Receive result])
    
    style Start fill:#e1f5e1
    style End1 fill:#e1f5e1
    style End8 fill:#e1f5e1
    style End2 fill:#ffe1e1
    style End3 fill:#ffe1e1
    style End4 fill:#ffe1e1
    style End5 fill:#ffe1e1
    style End6 fill:#ffe1e1
    style End7 fill:#ffe1e1
    style EndCancelled fill:#ffd700
    style EndCancelled2 fill:#ffd700
    
    style CheckQueue fill:#fff4e1
    style CheckToken fill:#fff4e1
    style HTTPResult fill:#fff4e1
    style AuthResult fill:#fff4e1
    style RefreshResult fill:#fff4e1
    style CheckCancelled fill:#fff4e1
    style CheckCancelled2 fill:#fff4e1
    
    style HandleStrategy1 fill:#ffcccc
    style HandleStrategy2 fill:#ffcccc
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