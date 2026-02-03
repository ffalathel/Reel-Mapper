import SwiftUI

struct RestaurantCardView: View {
    let restaurant: Restaurant
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    // Generate a seeded placeholder image URL based on restaurant ID
    private var imageURL: URL {
        let seed = abs(restaurant.id.hashValue)
        return URL(string: "https://picsum.photos/seed/\(seed)/400/300")!
    }
    
    // Generate a mock rating (seeded by restaurant ID for consistency)
    private var rating: Double {
        let seed = abs(restaurant.id.hashValue)
        return 3.5 + Double(seed % 15) / 10.0 // Range: 3.5 to 5.0
    }
    
    private var reviewCount: Int {
        let seed = abs(restaurant.id.hashValue)
        return 100 + (seed % 5000) // Range: 100 to 5100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image with avatar and Instagram badge overlay
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 140)
                .clipped()
                
                // Favorite star button (top-right)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                favoritesManager.toggleFavorite(restaurant.id)
                            }
                        }) {
                            Image(systemName: favoritesManager.isFavorite(restaurant.id) ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(favoritesManager.isFavorite(restaurant.id) ? .red : .white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                        .blur(radius: 2)
                                )
                        }
                        .scaleEffect(favoritesManager.isFavorite(restaurant.id) ? 1.1 : 1.0)
                    }
                    Spacer()
                }
                .padding(8)
                
                // Bottom overlay with avatar and Instagram badge
                HStack {
                    // Circular avatar
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        )
                    
                    Spacer()
                    
                    // Instagram badge
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.pink)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 34, height: 34)
                        )
                }
                .padding(8)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(restaurant.city)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if let priceRange = restaurant.priceRange {
                        Spacer()
                        Text(priceRange)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Star rating
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    
                    Text("▲ \(reviewCount.formatted()) ratings")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(10)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
