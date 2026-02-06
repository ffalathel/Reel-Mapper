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

    /// Sync favorites and visited from restaurant data (called by HomeViewModel after fetching)
    func syncFromRestaurants(_ restaurants: [Restaurant]) {
        // Extract favorites and visited from restaurant objects
        let newFavorites = Set(restaurants.filter { $0.isFavorite == true }.map { $0.id })
        let newVisited = Set(restaurants.filter { $0.isVisited == true }.map { $0.id })

        favoriteRestaurantIds = newFavorites
        visitedRestaurantIds = newVisited

        saveToUserDefaults()

        print("FavoritesManager: Synced \(favoriteRestaurantIds.count) favorites and \(visitedRestaurantIds.count) visited from restaurants")
    }

    /// DEPRECATED: Use syncFromRestaurants() instead
    /// Load favorites and visited from backend on app launch
    @available(*, deprecated, message: "Use syncFromRestaurants() instead - data now comes from /home endpoint")
    func loadFromBackend() async {
        // This method is deprecated and does nothing
        // Favorites/visited are now synced from /home endpoint via syncFromRestaurants()
        print("FavoritesManager: loadFromBackend() is deprecated, data synced from /home instead")
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
    
    /// Clear all favorites and visited data (used on sign out)
    func clearAll() {
        favoriteRestaurantIds = []
        visitedRestaurantIds = []
        saveToUserDefaults()
    }
}
