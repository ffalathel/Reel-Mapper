import Foundation

struct APIConfig {
    // Toggle this to false when AWS backend is ready
    static let useMockMode = false  // ← Switched to TRUE to use local backend for testing
    
    // URL Configuration
    static let localURL = "http://localhost:8000"
    static let productionURL = "http://3.132.121.16:8000"  // AWS EC2 Backend
    
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
    
    func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable? = nil, retryCount: Int = 0, isTokenRefreshRetry: Bool = false) async throws -> T {
        print("DEBUG API: Starting request to \(endpoint.path), retry: \(retryCount), tokenRefresh: \(isTokenRefreshRetry)")
        
        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            print("DEBUG API: Invalid URL - \(APIConfig.baseURL + endpoint.path)")
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        // Get token from Clerk via AuthManager (async)
        if let token = await AuthManager.shared.getToken() {
            print("DEBUG API: Adding Clerk auth token: \(token.prefix(20))...")
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("DEBUG API: No auth token available - user may not be signed in")
            throw APIError.unauthorized
        }
        
        if let body = body {
            do {
                urlRequest.httpBody = try jsonEncoder.encode(body)
                print("DEBUG API: Request body encoded successfully")
            } catch {
                print("DEBUG API: Failed to encode request body: \(error)")
                throw APIError.serializationError
            }
        }
        
        do {
            print("DEBUG API: Sending request to \(url)")
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("DEBUG API: Invalid response type")
                throw APIError.unknown(NSError(domain: "Invalid Response", code: 0))
            }
            
            print("DEBUG API: Received response with status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    print("DEBUG API: Attempting to decode response data...")
                    let decoded = try jsonDecoder.decode(T.self, from: data)
                    print("DEBUG API: Successfully decoded response")
                    
                    // Store token for Share Extension on successful authenticated requests
                    await AuthManager.shared.storeTokenForExtension()
                    
                    return decoded
                } catch {
                    print("DEBUG API: Decoding failed: \(error)")
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("DEBUG API: Response data: \(dataString)")
                    }
                    throw APIError.decodingError(error)
                }
            case 401:
                print("DEBUG API: Unauthorized (401)")
                
                // If this is already a token refresh retry, don't retry again
                if isTokenRefreshRetry {
                    print("DEBUG API: Already retried with fresh token, giving up")
                    throw APIError.unauthorized
                }
                
                // Try force refreshing the token and retry once (per spec Step 13)
                print("DEBUG API: Attempting token refresh and retry...")
                if let freshToken = await AuthManager.shared.getTokenForceRefresh() {
                    print("DEBUG API: Got fresh token, retrying request...")
                    var retryRequest = urlRequest
                    retryRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")
                    
                    let (retryData, retryResponse) = try await session.data(for: retryRequest)
                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                        throw APIError.unknown(NSError(domain: "Invalid Response", code: 0))
                    }
                    
                    if retryHttpResponse.statusCode == 200 || retryHttpResponse.statusCode < 300 {
                        let decoded = try jsonDecoder.decode(T.self, from: retryData)
                        await AuthManager.shared.storeTokenForExtension()
                        return decoded
                    } else {
                        print("DEBUG API: Retry also failed with status: \(retryHttpResponse.statusCode)")
                        throw APIError.unauthorized
                    }
                } else {
                    print("DEBUG API: Could not refresh token")
                    throw APIError.unauthorized
                }
                
            case 404:
                print("DEBUG API: Not Found (404)")
                throw APIError.notFound
            default:
                print("DEBUG API: Server error with status code: \(httpResponse.statusCode)")
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let apiError as APIError {
            print("DEBUG API: Caught APIError: \(apiError)")
            // Don't retry client errors (4xx) - only retry transient failures
            switch apiError {
            case .unauthorized, .notFound, .invalidURL, .serializationError, .decodingError:
                print("DEBUG API: Not retrying client error")
                throw apiError
            case .serverError, .unknown:
                // Retry server errors and unknown errors
                if retryCount < APIConfig.maxRetries {
                    print("DEBUG API: Retrying... (\(retryCount + 1)/\(APIConfig.maxRetries))")
                    try await Task.sleep(nanoseconds: APIConfig.retryDelay * UInt64(retryCount + 1))
                    return try await request(endpoint, body: body, retryCount: retryCount + 1)
                }
                print("DEBUG API: Max retries reached")
                throw apiError
            }
        } catch {
            print("DEBUG API: Network error: \(error)")
            // Network errors - retry these
            if retryCount < APIConfig.maxRetries {
                print("DEBUG API: Retrying network error... (\(retryCount + 1)/\(APIConfig.maxRetries))")
                try await Task.sleep(nanoseconds: APIConfig.retryDelay * UInt64(retryCount + 1))
                return try await request(endpoint, body: body, retryCount: retryCount + 1)
            }
            print("DEBUG API: Max retries reached for network error")
            throw APIError.unknown(error)
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
    
    // MARK: - User Profile
    
    func getCurrentUser() async throws -> UserProfile {
        return try await request(.currentUser)
    }
    
    // MARK: - Lists/Folders
    
    func createList(name: String) async throws -> ListCreateResponse {
        let payload = CreateListRequest(name: name)
        return try await request(.lists, body: payload)
    }
    
    func deleteList(id: UUID) async throws {
        // DELETE returns 204 No Content, so we expect empty body or handle it gracefully.
        // Our request method is generic <T: Decodable>. 
        // We might need a requestNoResponse method OR expect a specific EmptyResponse.
        // Quick fix: define a struct EmptyResponse: Decodable {} and use it?
        // OR modifying request to allow Void Return.
        // Let's assume we can ignore the return for now if we don't define generic T but specialized method.
        // Actually the `request` method requires T: Decodable.
        // We'll create a DummyResponse for 204.
        let _: EmptyResponse = try await request(.deleteList(id: id))
    }
    
    func deleteRestaurant(id: UUID) async throws {
        let _: EmptyResponse = try await request(.deleteRestaurant(id: id))
    }
}

struct EmptyResponse: Decodable {}
