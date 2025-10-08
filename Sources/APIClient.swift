import Foundation

public actor APIClient: HTTPClient {
    private let httpClient: HTTPClient
    private let tokenManager: TokenManager
    private let errorHandler: ErrorHandler
    private let authorizationService: AuthorizationService
    
    private var requests: [UUID: [CheckedContinuation<Response, any Error>]] = [:]
    private let isAuthorizingOrRefreshing = AsyncLock()
    
    public init(
        httpClient: HTTPClient,
        tokenManager: TokenManager,
        errorHandler: ErrorHandler,
        authorizationService: AuthorizationService
    ) {
        self.httpClient = httpClient
        self.tokenManager = tokenManager
        self.errorHandler = errorHandler
        self.authorizationService = authorizationService
    }
    
    public func execute(request: any Request) async throws(HTTPError) -> Response {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                if case nil = requests[request.id]?.append(continuation) {
                    requests[request.id] = [continuation]
                    execute(request: request)
                }
            }
        } catch let error as HTTPError {
            throw error
        } catch {
            throw .other(error)
        }
    }
    
    private func execute(request: any Request) {
        Task {
            await executeAsync(request: request)
        }
    }
    
    private func executeAsync(request: any Request) async {
        await isAuthorizingOrRefreshing.wait()
        
        guard requests[request.id] != nil else {
            debugPrint("HTTP: finished request \(request.id)")
            return
        }
        
        switch await tokenManager.state {
        case .valid(let jwt):
            debugPrint("HTTP: executeAsync valid request \(request.id)")
            await executeAuthorized(request: request, token: jwt)
        case .invalid(let jwt):
            debugPrint("HTTP: executeAsync invalid request \(request.id)")
            await refreshTokenThenExecute(request: request, token: jwt)
        case .unauthorized:
            debugPrint("HTTP: executeAsync unauthorized request \(request.id)")
            await authorizeThenExecute(request: request)
        }
    }
    
    private func authorizeThenExecute(request: any Request) async {
        await isAuthorizingOrRefreshing.tryExecute {
            debugPrint("HTTP: authorize \(request.id)")
            do {
                let token = try await authorizationService.authorize()
                await tokenManager.save(jwt: token)
            } catch {
                await handleAuthorizationError(request: request, error: error)
            }
        }
        
        await executeAsync(request: request)
    }
    
    private func refreshTokenThenExecute(request: any Request, token: JWT) async {
        await isAuthorizingOrRefreshing.tryExecute {
            debugPrint("HTTP: refresh token \(request.id)")
            do {
                let token = try await authorizationService.refreshToken(token: token)
                await tokenManager.save(jwt: token)
            } catch {
                await handleAuthorizationError(request: request, error: error)
            }
        }
        
        await executeAsync(request: request)
    }
    
    private func handleAuthorizationError(request: any Request, error: Error) async {
        let error = error as? HTTPError ?? .other(error)
        
        switch await errorHandler.handle(error: error) {
        case .propagate:
            resume(request: request, with: .failure(error))
        case .invalidateToken, .logout:
            resume(with: error)
            await tokenManager.reset()
        }
    }
    
    private func executeAuthorized(request: any Request, token: JWT) async {
        let authorizedRequest = AuthorizedRequest(request: request, token: token)
        do {
            debugPrint("HTTP: execute authorized request \(request.id)")
            let response = try await httpClient.execute(request: authorizedRequest)
            resume(request: request, with: .success(response))
        } catch {
            await handle(error: error, for: authorizedRequest)
        }
    }
    
    private func handle(error: HTTPError, for request: AuthorizedRequest) async {
        switch await errorHandler.handle(error: error) {
        case .propagate:
            resume(request: request.request, with: .failure(error))
        case .invalidateToken:
            await tokenManager.invalidate(jwt: request.token)
            await executeAsync(request: request.request)
        case .logout:
            resume(with: error)
            await tokenManager.reset()
        }
    }
    
    private func resume(request: any Request, with result: Result<Response, HTTPError>) {
        debugPrint("HTTP: resume request \(request.id) \(result)")
        requests.removeValue(forKey: request.id)?.forEach { $0.resume(with: result) }
    }
    
    private func resume(with error: HTTPError) {
        debugPrint("HTTP: error \(error)")
        requests.forEach { $0.value.forEach { $0.resume(with: .failure(error)) } }
        requests.removeAll()
    }
}
