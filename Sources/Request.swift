import Foundation

/// Protocol for API requests with built-in deduplication support.
///
/// The `id` property controls deduplication behavior:
/// - Use a **constant UUID** to deduplicate identical requests
/// - Use **UUID()** to disable deduplication (fresh request every time)
/// - Use **parameter-based UUID** for smart deduplication
///
/// Example:
/// ```swift
/// struct GetUserProfile: Request {
///     let userId: Int
///
///     // Deduplicate requests for the same user
///     var id: UUID {
///         UUID(uuidString: "user-profile-\(userId)") ?? UUID()
///     }
/// }
/// ```
public protocol Request: Identifiable<UUID> {
    func urlRequest() throws -> URLRequest
}
