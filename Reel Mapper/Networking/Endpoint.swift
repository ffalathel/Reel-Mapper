import Foundation

enum Endpoint {
    case health
    case saveEvent
    case home
    case restaurant(id: UUID)
    case lists
    
    // Auth
    // Auth
    case currentUser
    
    // Deletion
    // Deletion
    case deleteList(id: UUID)
    case deleteUserRestaurant(id: UUID) // Deletes by join table ID
    case deleteSavedRestaurant(restaurantId: UUID) // Deletes by restaurant ID
    case removeFromList(listId: UUID, restaurantId: UUID)
    
    // Favorites
    case toggleFavorite(restaurantId: UUID)
    case getFavorites
    
    // Visited
    case toggleVisited(restaurantId: UUID)
    case getVisited
    
    // Notes
    case saveNotes(restaurantId: UUID)
    
    var path: String {
        switch self {
        case .health: return "/api/v1/health"
        case .saveEvent: return "/api/v1/save-events/"
        case .home: return "/api/v1/home"
        case .restaurant(let id): return "/api/v1/restaurants/\(id.uuidString)"
        case .lists: return "/api/v1/lists/"
        case .currentUser: return "/api/v1/auth/me"
        case .toggleFavorite(let id): return "/api/v1/favorites/\(id.uuidString)"
        case .getFavorites: return "/api/v1/favorites"
        case .toggleVisited(let id): return "/api/v1/visited/\(id.uuidString)"
        case .getVisited: return "/api/v1/visited"
        case .saveNotes(let id): return "/api/v1/restaurants/\(id.uuidString)/notes"
        case .deleteList(let id): return "/api/v1/lists/\(id.uuidString)"
        case .deleteUserRestaurant(let id): return "/api/v1/user-restaurants/\(id.uuidString)"
        case .deleteSavedRestaurant(let id): return "/api/v1/user-restaurants/restaurant/\(id.uuidString)"
        case .removeFromList(let listId, let rId): return "/api/v1/lists/\(listId.uuidString)/restaurants/\(rId.uuidString)"
        }
    }
    
    var method: String {
        switch self {
        case .saveEvent, .lists, .toggleFavorite, .toggleVisited:
            return "POST"
        case .deleteList, .deleteUserRestaurant, .deleteSavedRestaurant, .removeFromList:
            return "DELETE"
        case .saveNotes:
            return "PUT"
        case .health, .home, .restaurant, .getFavorites, .getVisited, .currentUser:
            return "GET"
        }
    }
}
