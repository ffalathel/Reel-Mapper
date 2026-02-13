import Foundation

// MARK: - API Configuration

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
        AppLogger.debug("Starting request to \(endpoint.path), retry: \(retryCount), tokenRefresh: \(isTokenRefreshRetry)", category: .network)

        guard let url = URL(string: APIConfig.baseURL + endpoint.path) else {
            AppLogger.error("Invalid URL - \(APIConfig.baseURL + endpoint.path)", category: .network)
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30
        
        // Get token from Clerk via AuthManager (async)
        if let token = await AuthManager.shared.getToken() {
            AppLogger.debugSensitive("Adding Clerk auth token: \(token.prefix(20))...", category: .auth)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            AppLogger.warning("No auth token available - user may not be signed in", category: .auth)
            throw APIError.unauthorized
        }
        
        if let body = body {
            do {
                urlRequest.httpBody = try jsonEncoder.encode(body)
                AppLogger.debug("Request body encoded successfully", category: .network)
            } catch {
                AppLogger.error("Failed to encode request body: \(error)", category: .network)
                throw APIError.serializationError
            }
        }
        
        do {
            AppLogger.debug("Sending request to \(url)", category: .network)
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.error("Invalid response type", category: .network)
                throw APIError.unknown(NSError(domain: "Invalid Response", code: 0))
            }

            AppLogger.debug("Received response with status code: \(httpResponse.statusCode)", category: .network)
            
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    AppLogger.debug("Attempting to decode response data...", category: .network)
                    let decoded = try jsonDecoder.decode(T.self, from: data)
                    AppLogger.info("Successfully decoded response", category: .network)

                    // Store token for Share Extension on successful authenticated requests
                    await AuthManager.shared.storeTokenForExtension()

                    return decoded
                } catch {
                    AppLogger.error("Decoding failed: \(error)", category: .network)
                    if let dataString = String(data: data, encoding: .utf8) {
                        AppLogger.debug("Response data: \(dataString)", category: .network)
                    }
                    throw APIError.decodingError(error)
                }
            case 401:
                AppLogger.warning("Unauthorized (401)", category: .auth)

                // If this is already a token refresh retry, don't retry again
                if isTokenRefreshRetry {
                    AppLogger.warning("Already retried with fresh token, giving up", category: .auth)
                    throw APIError.unauthorized
                }

                // Try force refreshing the token and retry once (per spec Step 13)
                AppLogger.info("Attempting token refresh and retry...", category: .auth)
                if let freshToken = await AuthManager.shared.getTokenForceRefresh() {
                    AppLogger.info("Got fresh token, retrying request...", category: .auth)
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
                        AppLogger.error("Retry also failed with status: \(retryHttpResponse.statusCode)", category: .auth)
                        throw APIError.unauthorized
                    }
                } else {
                    AppLogger.error("Could not refresh token", category: .auth)
                    throw APIError.unauthorized
                }
                
            case 404:
                AppLogger.warning("Not Found (404)", category: .network)
                throw APIError.notFound
            default:
                AppLogger.error("Server error with status code: \(httpResponse.statusCode)", category: .network)
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch let apiError as APIError {
            AppLogger.debug("Caught APIError: \(apiError)", category: .network)
            // Don't retry client errors (4xx) - only retry transient failures
            switch apiError {
            case .unauthorized, .notFound, .invalidURL, .serializationError, .decodingError:
                AppLogger.debug("Not retrying client error", category: .network)
                throw apiError
            case .serverError, .unknown:
                // Retry server errors and unknown errors
                if retryCount < APIConfig.maxRetries {
                    AppLogger.warning("Retrying... (\(retryCount + 1)/\(APIConfig.maxRetries))", category: .network)
                    try await Task.sleep(nanoseconds: APIConfig.retryDelay * UInt64(retryCount + 1))
                    return try await request(endpoint, body: body, retryCount: retryCount + 1)
                }
                AppLogger.error("Max retries reached", category: .network)
                throw apiError
            }
        } catch {
            AppLogger.error("Network error: \(error)", category: .network)
            // Network errors - retry these
            if retryCount < APIConfig.maxRetries {
                AppLogger.warning("Retrying network error... (\(retryCount + 1)/\(APIConfig.maxRetries))", category: .network)
                try await Task.sleep(nanoseconds: APIConfig.retryDelay * UInt64(retryCount + 1))
                return try await request(endpoint, body: body, retryCount: retryCount + 1)
            }
            AppLogger.error("Max retries reached for network error", category: .network)
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

    // REMOVED: getFavorites() - Favorites are now retrieved from /home endpoint
    // The /home endpoint returns restaurants with is_favorite flags, eliminating the need for a separate call

    // MARK: - Visited

    func toggleVisited(restaurantId: UUID) async throws -> VisitedResponse {
        return try await request(.toggleVisited(restaurantId: restaurantId))
    }

    // REMOVED: getVisited() - Visited status is now retrieved from /home endpoint
    // The /home endpoint returns restaurants with is_visited flags, eliminating the need for a separate call
    
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

    func getListRestaurants(listId: UUID) async throws -> ListRestaurantsResponse {
        return try await request(.getListRestaurants(listId: listId))
    }

    func addRestaurantToList(listId: UUID, restaurantId: UUID) async throws {
        let payload = AddRestaurantToListRequest(restaurantId: restaurantId)
        let _: UserRestaurantResponse = try await request(.addRestaurantToList(listId: listId, restaurantId: restaurantId), body: payload)
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
