import Foundation

actor AsyncLock {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    func wait() async {
        while isLocked {
            await withCheckedContinuation {
                waiters.append($0)
            }
        }
    }
    
    func lock() {
        isLocked = true
    }
    
    func unlock() {
        isLocked = false
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
    
    @discardableResult
    func tryExecute(operation: () async -> Void) async -> Bool {
        if isLocked {
            return false
        } else {
            lock()
            defer { unlock() }
            await operation()
            return true
        }
    }
}
