import Foundation

enum Endpoint {
    case health
    case saveEvent
    case home
    case restaurant(id: UUID)
    // case lists
    
    // Auth
    case currentUser
    
    // Favorites
    case toggleFavorite(restaurantId: UUID)
    case getFavorites
    
    // Visited
    case toggleVisited(restaurantId: UUID)
    case getVisited
    
    // List Management
    case lists
    case addRestaurantToList(listId: UUID, restaurantId: UUID)
    case deleteList(id: UUID)
    
    // Notes
    case saveNotes(restaurantId: UUID)
    
    // Deletion
    case deleteRestaurant(id: UUID)
    
    var path: String {
        switch self {
        case .health: return "/api/v1/health"
        case .saveEvent: return "/api/v1/save-events/"
        case .home: return "/api/v1/home"
        case .restaurant(let id): return "/api/v1/restaurants/\(id.uuidString)"
        case .lists: return "/api/v1/lists/"
        case .addRestaurantToList(let listId, _): return "/api/v1/lists/\(listId.uuidString)/restaurants"
        case .deleteList(let id): return "/api/v1/lists/\(id.uuidString)"
        case .currentUser: return "/api/v1/auth/me"
        case .deleteRestaurant(let id): return "/api/v1/user-restaurants/restaurant/\(id.uuidString)"
        case .toggleFavorite(let id): return "/api/v1/restaurants/\(id.uuidString)/favorite"
        case .getFavorites: return "/api/v1/favorites"
        case .toggleVisited(let id): return "/api/v1/restaurants/\(id.uuidString)/visited"
        case .getVisited: return "/api/v1/visited"
        case .saveNotes(let id): return "/api/v1/restaurants/\(id.uuidString)/notes"
        }
    }
    
    var method: String {
        switch self {
        case .saveEvent, .lists, .addRestaurantToList, .toggleFavorite, .toggleVisited:
            return "POST"
        case .saveNotes:
            return "PUT"
        case .deleteList, .deleteRestaurant:
            return "DELETE"
        case .health, .home, .restaurant, .getFavorites, .getVisited, .currentUser:
            return "GET"
        }
    }
}
