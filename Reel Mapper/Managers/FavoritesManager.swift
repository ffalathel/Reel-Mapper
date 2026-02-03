import Foundation
import Combine

/// Manages favorites and visited status for restaurants with backend sync
@MainActor
class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteRestaurantIds: Set<UUID> = []
    @Published var visitedRestaurantIds: Set<UUID> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let favoritesKey = "favoriteRestaurants"
    private let visitedKey = "visitedRestaurants"
    private let apiClient = APIClient.shared
    
    private init() {
        loadFromUserDefaults()
    }
    
    // MARK: - Backend Sync
    
    /// Load favorites and visited from backend on app launch
    func loadFromBackend() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let favoritesResponse = apiClient.getFavorites()
            async let visitedResponse = apiClient.getVisited()
            
            let (favorites, visited) = try await (favoritesResponse, visitedResponse)
            
            favoriteRestaurantIds = Set(favorites.restaurantIds)
            visitedRestaurantIds = Set(visited.restaurantIds)
            
            saveToUserDefaults()
        } catch {
            // On error, keep using local cache
            print("Failed to load from backend: \(error)")
            errorMessage = "Failed to sync with server"
        }
        
        isLoading = false
    }
    
    // MARK: - Favorites
    
    func isFavorite(_ restaurantId: UUID) -> Bool {
        favoriteRestaurantIds.contains(restaurantId)
    }
    
    func toggleFavorite(_ restaurantId: UUID) {
        // Optimistic update
        let wasFavorite = favoriteRestaurantIds.contains(restaurantId)
        
        if wasFavorite {
            favoriteRestaurantIds.remove(restaurantId)
        } else {
            favoriteRestaurantIds.insert(restaurantId)
        }
        
        saveToUserDefaults()
        
        // Sync with backend
        Task {
            do {
                let response = try await apiClient.toggleFavorite(restaurantId: restaurantId)
                
                // Verify server state matches our optimistic update
                if response.isFavorite != !wasFavorite {
                    // Server state differs, update to match server
                    if response.isFavorite {
                        favoriteRestaurantIds.insert(restaurantId)
                    } else {
                        favoriteRestaurantIds.remove(restaurantId)
                    }
                    saveToUserDefaults()
                }
            } catch {
                // Rollback on error
                if wasFavorite {
                    favoriteRestaurantIds.insert(restaurantId)
                } else {
                    favoriteRestaurantIds.remove(restaurantId)
                }
                saveToUserDefaults()
                errorMessage = "Failed to update favorite status"
                print("Failed to toggle favorite: \(error)")
            }
        }
    }
    
    func addFavorite(_ restaurantId: UUID) {
        if !favoriteRestaurantIds.contains(restaurantId) {
            toggleFavorite(restaurantId)
        }
    }
    
    func removeFavorite(_ restaurantId: UUID) {
        if favoriteRestaurantIds.contains(restaurantId) {
            toggleFavorite(restaurantId)
        }
    }
    
    // MARK: - Visited
    
    func isVisited(_ restaurantId: UUID) -> Bool {
        visitedRestaurantIds.contains(restaurantId)
    }
    
    func toggleVisited(_ restaurantId: UUID) {
        // Optimistic update
        let wasVisited = visitedRestaurantIds.contains(restaurantId)
        
        if wasVisited {
            visitedRestaurantIds.remove(restaurantId)
        } else {
            visitedRestaurantIds.insert(restaurantId)
        }
        
        saveToUserDefaults()
        
        // Sync with backend
        Task {
            do {
                let response = try await apiClient.toggleVisited(restaurantId: restaurantId)
                
                // Verify server state matches our optimistic update
                if response.isVisited != !wasVisited {
                    // Server state differs, update to match server
                    if response.isVisited {
                        visitedRestaurantIds.insert(restaurantId)
                    } else {
                        visitedRestaurantIds.remove(restaurantId)
                    }
                    saveToUserDefaults()
                }
            } catch {
                // Rollback on error
                if wasVisited {
                    visitedRestaurantIds.insert(restaurantId)
                } else {
                    visitedRestaurantIds.remove(restaurantId)
                }
                saveToUserDefaults()
                errorMessage = "Failed to update visited status"
                print("Failed to toggle visited: \(error)")
            }
        }
    }
    
    func markAsVisited(_ restaurantId: UUID) {
        if !visitedRestaurantIds.contains(restaurantId) {
            toggleVisited(restaurantId)
        }
    }
    
    func markAsNotVisited(_ restaurantId: UUID) {
        if visitedRestaurantIds.contains(restaurantId) {
            toggleVisited(restaurantId)
        }
    }
    
    // MARK: - Persistence
    
    private func saveToUserDefaults() {
        let favoriteIds = Array(favoriteRestaurantIds).map { $0.uuidString }
        let visitedIds = Array(visitedRestaurantIds).map { $0.uuidString }
        
        UserDefaults.standard.set(favoriteIds, forKey: favoritesKey)
        UserDefaults.standard.set(visitedIds, forKey: visitedKey)
    }
    
    private func loadFromUserDefaults() {
        if let favoriteIds = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteRestaurantIds = Set(favoriteIds.compactMap { UUID(uuidString: $0) })
        }
        
        if let visitedIds = UserDefaults.standard.array(forKey: visitedKey) as? [String] {
            visitedRestaurantIds = Set(visitedIds.compactMap { UUID(uuidString: $0) })
        }
    }
    
    // MARK: - Helpers
    
    var favoriteCount: Int {
        favoriteRestaurantIds.count
    }
    
    var visitedCount: Int {
        visitedRestaurantIds.count
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
