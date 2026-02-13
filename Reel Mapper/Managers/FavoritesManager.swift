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
    private var inFlightFavorites: Set<UUID> = []
    private var inFlightVisited: Set<UUID> = []

    private init() {
        loadFromUserDefaults()
    }
    
    // MARK: - Backend Sync

    /// Sync favorites and visited from restaurant data (called by HomeViewModel after fetching)
    func syncFromRestaurants(_ restaurants: [Restaurant]) {
        // Extract favorites and visited from restaurant objects
        let newFavorites = Set(restaurants.filter { $0.isFavorite }.map { $0.id })
        let newVisited = Set(restaurants.filter { $0.isVisited }.map { $0.id })

        favoriteRestaurantIds = newFavorites
        visitedRestaurantIds = newVisited

        saveToUserDefaults()

        AppLogger.info("Synced \(favoriteRestaurantIds.count) favorites and \(visitedRestaurantIds.count) visited from restaurants", category: .data)
    }

    // MARK: - Favorites
    
    func isFavorite(_ restaurantId: UUID) -> Bool {
        favoriteRestaurantIds.contains(restaurantId)
    }
    
    func toggleFavorite(_ restaurantId: UUID) {
        performToggle(restaurantId, kind: .favorite)
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
        performToggle(restaurantId, kind: .visited)
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

    private enum ToggleKind {
        case favorite
        case visited
    }

    private func performToggle(_ restaurantId: UUID, kind: ToggleKind) {
        // Guard: block re-entry while a request is in-flight for this restaurant
        switch kind {
        case .favorite:
            guard !inFlightFavorites.contains(restaurantId) else { return }
        case .visited:
            guard !inFlightVisited.contains(restaurantId) else { return }
        }

        // Capture pre-toggle state for rollback
        let wasActive: Bool
        switch kind {
        case .favorite:
            wasActive = favoriteRestaurantIds.contains(restaurantId)
            if wasActive { favoriteRestaurantIds.remove(restaurantId) }
            else { favoriteRestaurantIds.insert(restaurantId) }
            inFlightFavorites.insert(restaurantId)
        case .visited:
            wasActive = visitedRestaurantIds.contains(restaurantId)
            if wasActive { visitedRestaurantIds.remove(restaurantId) }
            else { visitedRestaurantIds.insert(restaurantId) }
            inFlightVisited.insert(restaurantId)
        }
        saveToUserDefaults()

        Task {
            defer {
                switch kind {
                case .favorite: inFlightFavorites.remove(restaurantId)
                case .visited: inFlightVisited.remove(restaurantId)
                }
            }
            do {
                let serverState: Bool
                switch kind {
                case .favorite:
                    serverState = try await apiClient.toggleFavorite(restaurantId: restaurantId).isFavorite
                case .visited:
                    serverState = try await apiClient.toggleVisited(restaurantId: restaurantId).isVisited
                }
                // Always trust server response
                switch kind {
                case .favorite:
                    if serverState { favoriteRestaurantIds.insert(restaurantId) }
                    else { favoriteRestaurantIds.remove(restaurantId) }
                case .visited:
                    if serverState { visitedRestaurantIds.insert(restaurantId) }
                    else { visitedRestaurantIds.remove(restaurantId) }
                }
                saveToUserDefaults()
            } catch {
                // Rollback to pre-toggle state
                switch kind {
                case .favorite:
                    if wasActive { favoriteRestaurantIds.insert(restaurantId) }
                    else { favoriteRestaurantIds.remove(restaurantId) }
                case .visited:
                    if wasActive { visitedRestaurantIds.insert(restaurantId) }
                    else { visitedRestaurantIds.remove(restaurantId) }
                }
                saveToUserDefaults()
                let label = kind == .favorite ? "favorite" : "visited"
                errorMessage = "Failed to update \(label) status"
                AppLogger.error("Failed to toggle \(label): \(error)", category: .data)
            }
        }
    }

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
