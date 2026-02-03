import Foundation

struct APIConfig {
    // Toggle this to false when AWS backend is ready
    static let useMockMode = true
    
    // URL Configuration
    static let localURL = "http://localhost:8000"
    static let productionURL = "https://your-aws-server.com"  // TODO: Update when AWS is ready
    
    // Use local URL for development, production URL when deployed
    static var baseURL: String {
        useMockMode ? localURL : productionURL
    }
    
    static let maxRetries = 3
    static let retryDelay: UInt64 = 1_000_000_000 // 1 second in nanoseconds
}

class APIClient {
    static let shared = APIClient()
    
    private let session = URLSession.shared
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable? = nil, retryCount: Int = 0) async throws -> T {
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        if let token = AuthManager.shared.getToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            do {
                urlRequest.httpBody = try jsonEncoder.encode(body)
            } catch {
                throw APIError.serializationError
            }
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown(NSError(domain: "Invalid Response", code: 0))
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try jsonDecoder.decode(T.self, from: data)
                } catch {
                    throw APIError.decodingError(error)
                }
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch {
            // Retry logic for transient failures
            if retryCount < APIConfig.maxRetries {
                try await Task.sleep(nanoseconds: APIConfig.retryDelay * UInt64(retryCount + 1))
                return try await request(endpoint, body: body, retryCount: retryCount + 1)
            }
            throw error
        }
    }
    
    // MARK: - Specific API Methods via wrapper
    
    func saveEvent(url: String, caption: String?, listId: UUID?) async throws -> CreateSaveEventResponse {
        let payload = CreateSaveEventRequest(sourceUrl: url, rawCaption: caption, targetListId: listId)
        return try await request(.saveEvent, body: payload)
    }
    
    func getHome() async throws -> HomeResponse {
        return try await request(.home)
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(restaurantId: UUID) async throws -> FavoriteResponse {
        return try await request(.toggleFavorite(restaurantId: restaurantId))
    }
    
    func getFavorites() async throws -> FavoritesListResponse {
        return try await request(.getFavorites)
    }
    
    // MARK: - Visited
    
    func toggleVisited(restaurantId: UUID) async throws -> VisitedResponse {
        return try await request(.toggleVisited(restaurantId: restaurantId))
    }
    
    func getVisited() async throws -> VisitedListResponse {
        return try await request(.getVisited)
    }
    
    // MARK: - Notes
    
    func saveNotes(restaurantId: UUID, notes: String) async throws -> NotesResponse {
        let payload = SaveNotesRequest(notes: notes)
        return try await request(.saveNotes(restaurantId: restaurantId), body: payload)
    }
}
