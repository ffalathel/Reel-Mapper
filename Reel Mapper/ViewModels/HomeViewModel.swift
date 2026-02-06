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
    
    // Toggle this to see mock data (set to false for live backend)
    private let useMockData = false
    
    private var pollingTask: Task<Void, Never>?
    
    // Fixed UUIDs for mock data so favorites/visited persist
    private static let mockRestaurantIds: [UUID] = [
        UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        UUID(uuidString: "88888888-8888-8888-8888-888888888888")!
    ]
    
    private static let mockListIds: [UUID] = [
        UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    ]
    
    private static let mockUserId = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    
    init() {
        if useMockData {
            loadMockData()
        }
    }
    
    func fetchHome(silent: Bool = false) async {
        print("DEBUG HomeViewModel: fetchHome called (silent: \(silent))")
        
        if useMockData {
            print("DEBUG HomeViewModel: Using mock data, skipping API call")
            // Skip API call when using mock data
            return
        }
        
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
        
        /*
        if useMockData {
            // Skip polling when using mock data
            return
        }
        
        // Cancel existing polling task if any
        pollingTask?.cancel()
        
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                if !Task.isCancelled {
                    // Use silent mode to avoid showing error alerts during polling
                    await fetchHome(silent: true)
                }
            }
        }
        */
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
    
    private func loadMockData() {
        // Mock Lists/Folders - using fixed UUIDs
        lists = [
            UserList(
                id: Self.mockListIds[0],
                userId: Self.mockUserId,
                name: "Best Italian Spots"
            ),
            UserList(
                id: Self.mockListIds[1],
                userId: Self.mockUserId,
                name: "Brunch Classics"
            ),
            UserList(
                id: Self.mockListIds[2],
                userId: Self.mockUserId,
                name: "New Spots in LA"
            ),
            UserList(
                id: Self.mockListIds[3],
                userId: Self.mockUserId,
                name: "Date Night"
            )
        ]
        
        // Mock Restaurants - using fixed UUIDs
        unsortedRestaurants = [
            Restaurant(
                id: Self.mockRestaurantIds[0],
                name: "Catch LA",
                latitude: 34.0522,
                longitude: -118.2437,
                city: "Los Angeles, CA",
                priceRange: "$$$",
                googlePlaceId: "ChIJexample1",
                address: "8715 Melrose Ave",
                state: "CA",
                rating: 4.5,
                reviewCount: 1200,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[1],
                name: "Nobu Malibu",
                latitude: 34.0259,
                longitude: -118.7798,
                city: "Malibu, CA",
                priceRange: "$$$$",
                googlePlaceId: "ChIJexample2",
                address: "22706 Pacific Coast Hwy",
                state: "CA",
                rating: 4.8,
                reviewCount: 3500,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[2],
                name: "Republique",
                latitude: 34.0522,
                longitude: -118.3437,
                city: "Los Angeles, CA",
                priceRange: "$$",
                googlePlaceId: "ChIJexample3",
                address: "624 S La Brea Ave",
                state: "CA",
                rating: 4.6,
                reviewCount: 2800,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[3],
                name: "Bestia",
                latitude: 34.0407,
                longitude: -118.2468,
                city: "Los Angeles, CA",
                priceRange: "$$$",
                googlePlaceId: "ChIJexample4",
                address: "2121 E 7th Pl",
                state: "CA",
                rating: 4.7,
                reviewCount: 3100,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[4],
                name: "Gjelina",
                latitude: 33.9850,
                longitude: -118.4695,
                city: "Venice, CA",
                priceRange: "$$",
                googlePlaceId: "ChIJexample5",
                address: "1429 Abbot Kinney Blvd",
                state: "CA",
                rating: 4.4,
                reviewCount: 2200,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[5],
                name: "Perch LA",
                latitude: 34.0478,
                longitude: -118.2518,
                city: "Los Angeles, CA",
                priceRange: "$$$",
                googlePlaceId: "ChIJexample6",
                address: "448 S Hill St",
                state: "CA",
                rating: 4.3,
                reviewCount: 4500,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[6],
                name: "Sugarfish",
                latitude: 34.0689,
                longitude: -118.3742,
                city: "Beverly Hills, CA",
                priceRange: "$$",
                googlePlaceId: "ChIJexample7",
                address: "212 N Canon Dr",
                state: "CA",
                rating: 4.6,
                reviewCount: 1800,
                primaryPhotoUrl: nil,
                createdAt: nil
            ),
            Restaurant(
                id: Self.mockRestaurantIds[7],
                name: "The Ivy",
                latitude: 34.0707,
                longitude: -118.3782,
                city: "West Hollywood, CA",
                priceRange: "$$$",
                googlePlaceId: "ChIJexample8",
                address: "113 N Robertson Blvd",
                state: "CA",
                rating: 4.2,
                reviewCount: 1500,
                primaryPhotoUrl: nil,
                createdAt: nil
            )
        ]
    }
}

