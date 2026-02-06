import Foundation

struct CreateSaveEventRequest: Codable {
    let sourceUrl: String
    let rawCaption: String?
    let targetListId: UUID?

    enum CodingKeys: String, CodingKey {
        case sourceUrl = "source_url"
        case rawCaption = "raw_caption"
        case targetListId = "target_list_id"
    }
}

struct CreateSaveEventResponse: Codable {
    let status: String
}

// Wrapper for backend UserRestaurantRead response
// Backend returns: {id, restaurant: {...}, created_at}
struct UserRestaurantResponse: Codable {
    let id: UUID
    let restaurant: Restaurant
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, restaurant
        case createdAt = "created_at"
    }
}

struct HomeResponse: Codable {
    let lists: [UserList]
    let unsortedRestaurants: [Restaurant]
    
    enum CodingKeys: String, CodingKey {
        case lists
        case unsortedRestaurants = "unsorted_restaurants"
    }
    
    // Custom decoder to handle nested restaurant objects from backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lists = try container.decode([UserList].self, forKey: .lists)
        
        // Backend returns array of {id, restaurant: {...}, created_at}
        // We need to extract just the restaurant objects
        let userRestaurants = try container.decode([UserRestaurantResponse].self, forKey: .unsortedRestaurants)
        unsortedRestaurants = userRestaurants.map { $0.restaurant }
    }
    
    // Standard encoder for completeness
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lists, forKey: .lists)
        try container.encode(unsortedRestaurants, forKey: .unsortedRestaurants)
    }
}

// MARK: - Favorites, Visited, Notes DTOs

struct SaveNotesRequest: Codable {
    let notes: String
}

struct FavoriteResponse: Codable {
    let isFavorite: Bool
    
    enum CodingKeys: String, CodingKey {
        case isFavorite = "is_favorite"
    }
}

struct VisitedResponse: Codable {
    let isVisited: Bool
    
    enum CodingKeys: String, CodingKey {
        case isVisited = "is_visited"
    }
}

struct NotesResponse: Codable {
    let notes: String?
}

struct FavoritesListResponse: Codable {
    let restaurantIds: [UUID]
    
    enum CodingKeys: String, CodingKey {
        case restaurantIds = "restaurant_ids"
    }
}

struct VisitedListResponse: Codable {
    let restaurantIds: [UUID]
    
    enum CodingKeys: String, CodingKey {
        case restaurantIds = "restaurant_ids"
    }
}

// MARK: - List/Folder DTOs

struct CreateListRequest: Codable {
    let name: String
}

struct ListCreateResponse: Codable {
    let id: UUID
    let name: String
    let userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case userId = "user_id"
    }
}
