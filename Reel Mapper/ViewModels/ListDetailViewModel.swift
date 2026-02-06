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

        do {
            let response = try await APIClient.shared.getListRestaurants(listId: list.id)
            restaurants = response.restaurants
            print("ListDetailViewModel: Loaded \(restaurants.count) restaurants for list \(list.name)")
        } catch {
            print("ListDetailViewModel: Failed to load restaurants: \(error)")
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
