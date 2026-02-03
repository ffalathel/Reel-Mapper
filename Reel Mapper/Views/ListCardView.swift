import SwiftUI

struct ListCardView: View {
    let list: UserList
    
    // Generate a seeded placeholder image URL based on list ID
    private var imageURL: URL {
        let seed = abs(list.id.hashValue)
        return URL(string: "https://picsum.photos/seed/\(seed)/300/300")!
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
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
                            Image(systemName: "folder.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 40))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 140, height: 100)
            .clipped()
            
            // Gradient overlay for text readability
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.5), Color.clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            
            // Text overlay
            Text(list.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .padding(10)
        }
        .frame(width: 140, height: 100)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
