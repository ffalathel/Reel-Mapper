import Foundation

@MainActor
class ListDetailViewModel: ObservableObject {
    @Published var restaurants: [Restaurant] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    let list: UserList
    
    init(list: UserList) {
        self.list = list
    }
    
    func fetchRestaurants() async {
        isLoading = true
        errorMessage = nil
        
        // For now, we'll filter from the home data since we don't have a dedicated endpoint
        // In production, this would call GET /lists/{id}/restaurants
        do {
            _ = try await APIClient.shared.getHome()
            // This is a simplified approach - in reality we'd need a proper endpoint
            // For now, we'll just show empty or mock data
            restaurants = []
        } catch {
            errorMessage = "Failed to load restaurants: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func removeRestaurant(_ restaurant: Restaurant) async {
        // Optimistic update - remove immediately from UI
        let originalRestaurants = restaurants
        restaurants.removeAll { $0.id == restaurant.id }
        
        do {
            try await APIClient.shared.deleteRestaurant(id: restaurant.id)
            print("ListDetailViewModel: Successfully deleted restaurant \(restaurant.name)")
        } catch {
            print("ListDetailViewModel: Failed to delete restaurant: \(error)")
            // Revert on failure
            restaurants = originalRestaurants
            errorMessage = "Failed to delete restaurant: \(error.localizedDescription)"
        }
    }
}
