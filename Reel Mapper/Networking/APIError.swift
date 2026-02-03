import Foundation

enum APIError: Error {
    case invalidURL
    case serializationError
    case unauthorized // 401
    case notFound // 404
    case serverError(statusCode: Int)
    case decodingError(Error)
    case unknown(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serializationError: return "Failed to serialize request"
        case .unauthorized: return "Unauthorized access. Please login again."
        case .notFound: return "Resource not found."
        case .serverError(let code): return "Server returned error code: \(code)"
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .unknown(let error): return "Unknown error: \(error.localizedDescription)"
        }
    }
}
