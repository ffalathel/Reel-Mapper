import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    // created_at can remain as String or Date depending on decoding strategy. Using String for now for simplicity unless Date decoding strategy is set.
}

struct UserProfile: Codable, Equatable {
    let id: UUID
    let email: String
    let name: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case createdAt = "created_at"
    }
}

struct Restaurant: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let city: String
    let priceRange: String? // Mapped from snake_case price_range via CodingKeys
    let googlePlaceId: String?
    
    // Additional backend fields
    let address: String?
    let state: String?
    let rating: Double?
    let reviewCount: Int?
    let primaryPhotoUrl: String?
    let createdAt: String?
    
    // User-specific fields (set from UserRestaurant data, default false)
    var isFavorite: Bool = false
    var isVisited: Bool = false
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, city
        case priceRange = "price_range"
        case googlePlaceId = "google_place_id"
        case address, state, rating
        case reviewCount = "review_count"
        case primaryPhotoUrl = "primary_photo_url"
        case createdAt = "created_at"
        case isFavorite = "is_favorite"
        case isVisited = "is_visited"
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        city = try container.decode(String.self, forKey: .city)
        priceRange = try container.decodeIfPresent(String.self, forKey: .priceRange)
        googlePlaceId = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount)
        primaryPhotoUrl = try container.decodeIfPresent(String.self, forKey: .primaryPhotoUrl)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isVisited = try container.decodeIfPresent(Bool.self, forKey: .isVisited) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct UserList: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID?  // Optional - backend doesn't always return this
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
    }
}

enum SaveEventStatus: String, Codable {
    case pending
    case processing
    case complete
    case failed
}

struct SaveEvent: Codable, Identifiable {
    let id: UUID
    let status: SaveEventStatus
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case errorMessage = "error_message"
    }
}
