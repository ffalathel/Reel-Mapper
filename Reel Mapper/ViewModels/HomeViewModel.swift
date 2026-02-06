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
        print("DEBUG HomeViewModel: fetchHome called (silent: \(silent))")

        isLoading = true
        if !silent {
            errorMessage = nil
        }
        
        do {
            print("DEBUG HomeViewModel: Calling getHome API...")
            let response = try await APIClient.shared.getHome()
            print("DEBUG HomeViewModel: Got \(response.lists.count) lists and \(response.unsortedRestaurants.count) restaurants")
            lists = response.lists
            unsortedRestaurants = response.unsortedRestaurants

            // Sync favorites and visited from the restaurant data
            FavoritesManager.shared.syncFromRestaurants(response.unsortedRestaurants)

            // Clear any previous errors on success
            errorMessage = nil
        } catch APIError.unauthorized {
            // Token is invalid/expired - force sign out silently
            print("HomeViewModel: 401 Unauthorized - Signing out")
            Task {
                try? await AuthManager.shared.signOut()
            }
            // Reset local state
            lists = []
            unsortedRestaurants = []
            // Don't set errorMessage - this is expected for unauthenticated users
        } catch {
            print("DEBUG HomeViewModel: fetchHome failed with error: \(error)")
            // Only show error message if not silent (i.e., not from polling)
            if !silent {
                errorMessage = "Failed to load home: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
        print("DEBUG HomeViewModel: fetchHome completed, isLoading=false")
    }
    
    func startPolling() {
        // TEMPORARILY DISABLED - Polling causes timeouts
        print("DEBUG HomeViewModel: Polling disabled")
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
            print("HomeViewModel: Successfully deleted list \(list.name)")
        } catch {
            print("HomeViewModel: Failed to delete list: \(error)")
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
            print("HomeViewModel: Successfully deleted restaurant \(restaurant.name)")
        } catch {
            print("HomeViewModel: Failed to delete restaurant: \(error)")
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
            print("HomeViewModel: Successfully moved \(restaurant.name) to \(list.name)")
            // Refresh home to ensure consistent state (especially if moving FROM another list)
            await fetchHome(silent: true)
        } catch {
            print("HomeViewModel: Failed to move restaurant: \(error)")
            // Revert
            unsortedRestaurants = originalRestaurants
            errorMessage = "Failed to move restaurant to folder: \(error.localizedDescription)"
        }
    }
}

