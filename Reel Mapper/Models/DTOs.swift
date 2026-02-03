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

struct HomeResponse: Codable {
    let lists: [UserList]
    let unsortedRestaurants: [Restaurant]
    
    enum CodingKeys: String, CodingKey {
        case lists
        case unsortedRestaurants = "unsorted_restaurants"
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
