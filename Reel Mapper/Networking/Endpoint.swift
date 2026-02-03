import Foundation

enum Endpoint {
    case health
    case saveEvent
    case home
    case restaurant(id: UUID)
    case lists
    
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
        case .health: return "/health"
        case .saveEvent: return "/save-events"
        case .home: return "/home"
        case .restaurant(let id): return "/restaurants/\(id.uuidString)"
        case .lists: return "/lists"
        case .toggleFavorite(let id): return "/restaurants/\(id.uuidString)/favorite"
        case .getFavorites: return "/favorites"
        case .toggleVisited(let id): return "/restaurants/\(id.uuidString)/visited"
        case .getVisited: return "/visited"
        case .saveNotes(let id): return "/restaurants/\(id.uuidString)/notes"
        }
    }
    
    var method: String {
        switch self {
        case .saveEvent, .lists, .toggleFavorite, .toggleVisited:
            return "POST"
        case .saveNotes:
            return "PUT"
        case .health, .home, .restaurant, .getFavorites, .getVisited:
            return "GET"
        }
    }
}
