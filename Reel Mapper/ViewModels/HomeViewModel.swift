import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    // Singleton instance for shared state across all views
    static let shared = HomeViewModel()
    
    @Published var lists: [UserList] = []
    @Published var unsortedRestaurants: [Restaurant] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var pollingTask: Task<Void, Never>?
    
    func fetchHome(silent: Bool = false) async {
        AppLogger.debug("fetchHome called (silent: \(silent))", category: .data)

        isLoading = true
        if !silent {
            errorMessage = nil
        }
        
        do {
            AppLogger.debug("Calling getHome API...", category: .data)
            let response = try await APIClient.shared.getHome()
            AppLogger.info("Got \(response.lists.count) lists and \(response.unsortedRestaurants.count) restaurants", category: .data)
            lists = response.lists
            unsortedRestaurants = response.unsortedRestaurants

            // Sync favorites and visited from the restaurant data
            FavoritesManager.shared.syncFromRestaurants(response.unsortedRestaurants)

            // Clear any previous errors on success
            errorMessage = nil
        } catch APIError.unauthorized {
            // Token is invalid/expired - force sign out silently
            AppLogger.warning("401 Unauthorized - Signing out", category: .auth)
            Task {
                try? await AuthManager.shared.signOut()
            }
            // Reset local state
            lists = []
            unsortedRestaurants = []
            // Don't set errorMessage - this is expected for unauthenticated users
        } catch {
            AppLogger.error("fetchHome failed with error: \(error)", category: .data)
            // Only show error message if not silent (i.e., not from polling)
            if !silent {
                errorMessage = "Failed to load home: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
        AppLogger.debug("fetchHome completed, isLoading=false", category: .data)
    }
    
    func startPolling() {
        // TEMPORARILY DISABLED - Polling causes timeouts
        AppLogger.debug("Polling disabled", category: .data)
        return
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // MARK: - Deletion Actions
    
    func deleteList(_ list: UserList) async {
        // Optimistic update
        let originalLists = lists
        lists.removeAll { $0.id == list.id }
        
        do {
            try await APIClient.shared.deleteList(id: list.id)
            AppLogger.info("Successfully deleted list \(list.name)", category: .data)
        } catch {
            AppLogger.error("Failed to delete list: \(error)", category: .data)
            // Revert on failure
            lists = originalLists
            errorMessage = "Failed to delete folder: \(error.localizedDescription)"
        }
    }
    
    func deleteRestaurant(_ restaurant: Restaurant) async {
        // Optimistic update
        let originalRestaurants = unsortedRestaurants
        unsortedRestaurants.removeAll { $0.id == restaurant.id }
        
        do {
            try await APIClient.shared.deleteRestaurant(id: restaurant.id)
            AppLogger.info("Successfully deleted restaurant \(restaurant.name)", category: .data)
        } catch {
            AppLogger.error("Failed to delete restaurant: \(error)", category: .data)
            // Revert on failure
            unsortedRestaurants = originalRestaurants
            errorMessage = "Failed to delete restaurant: \(error.localizedDescription)"
        }
    }
    
    func moveRestaurant(_ restaurant: Restaurant, to list: UserList) async {
        // Optimistic update: Remove from unsorted if it's there
        // Note: If it's in another list, we don't track that locally in HomeViewModel, 
        // so we can't optimistically remove it from the source list easily without more complex state.
        // But preventing it from showing in Unsorted is good.
        let originalRestaurants = unsortedRestaurants
        if unsortedRestaurants.contains(where: { $0.id == restaurant.id }) {
            unsortedRestaurants.removeAll { $0.id == restaurant.id }
        }
        
        do {
            try await APIClient.shared.addRestaurantToList(listId: list.id, restaurantId: restaurant.id)
            AppLogger.info("Successfully moved \(restaurant.name) to \(list.name)", category: .data)
            // Refresh home to ensure consistent state (especially if moving FROM another list)
            await fetchHome(silent: true)
        } catch {
            AppLogger.error("Failed to move restaurant: \(error)", category: .data)
            // Revert
            unsortedRestaurants = originalRestaurants
            errorMessage = "Failed to move restaurant to folder: \(error.localizedDescription)"
        }
    }
}

