import SwiftUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @StateObject private var favoritesManager = FavoritesManager.shared
    @State private var notes: String = ""
    @State private var showFullScreenImage = false
    @State private var selectedImageIndex = 0
    @State private var isSavingNotes = false
    @State private var saveTask: Task<Void, Never>?
    
    // Generate seeded data
    private var heroImageURL: URL {
        let seed = abs(restaurant.id.hashValue)
        return URL(string: "https://picsum.photos/seed/\(seed)/800/600")
            ?? URL(string: "https://picsum.photos/800/600")!
    }
    
    private var rating: Double {
        let seed = abs(restaurant.id.hashValue)
        return 3.5 + Double(seed % 15) / 10.0
    }
    
    private var reviewCount: Int {
        let seed = abs(restaurant.id.hashValue)
        return 100 + (seed % 5000)
    }
    
    private var topDishes: [String] {
        let dishes = [
            "Crispy Rice", "Spicy Tuna", "Lobster Mac & Cheese",
            "Truffle Pasta", "Wagyu Beef", "Salmon Tartare",
            "Chocolate Lava Cake", "Caesar Salad"
        ]
        let seed = abs(restaurant.id.hashValue)
        let startIndex = seed % (dishes.count - 3)
        return Array(dishes[startIndex..<min(startIndex + 3, dishes.count)])
    }
    
    private var photoURLs: [URL] {
        let seed = abs(restaurant.id.hashValue)
        return (0..<23).compactMap { index in
            URL(string: "https://picsum.photos/seed/\(seed + index)/400/400")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: heroImageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(3/2, contentMode: .fill)
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
                    .frame(height: 280)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture {
                        selectedImageIndex = 0
                        showFullScreenImage = true
                    }
                    
                    // Instagram badge
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.pink)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 38, height: 38)
                        )
                        .padding(16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                
                // Restaurant Header
                VStack(alignment: .leading, spacing: 12) {
                    // Name with favorite button
                    HStack(alignment: .top, spacing: 12) {
                        Text(restaurant.name)
                            .font(.system(size: 28, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                favoritesManager.toggleFavorite(restaurant.id)
                            }
                        }) {
                            Image(systemName: favoritesManager.isFavorite(restaurant.id) ? "heart.fill" : "heart")
                                .font(.system(size: 28))
                                .foregroundColor(favoritesManager.isFavorite(restaurant.id) ? .red : .secondary)
                        }
                        .scaleEffect(favoritesManager.isFavorite(restaurant.id) ? 1.1 : 1.0)
                    }
                    
                    // Rating, Reviews, Price, Maps Button
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            // Stars
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < Int(rating.rounded()) ? "star.fill" : "star")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            // Review count
                            Text("(\(reviewCount.formatted()) reviews)")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                            
                            // Price
                            if let priceRange = restaurant.priceRange {
                                Text(priceRange)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                        }
                        
                        // Action buttons row
                        HStack(spacing: 12) {
                            // Add to Google Maps button
                            Button(action: openInGoogleMaps) {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                    Text("Add to Google Maps")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                            
                            // Visited toggle button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    favoritesManager.toggleVisited(restaurant.id)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: favoritesManager.isVisited(restaurant.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(favoritesManager.isVisited(restaurant.id) ? .green : .secondary)
                                    Text(favoritesManager.isVisited(restaurant.id) ? "Visited" : "Mark Visited")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(favoritesManager.isVisited(restaurant.id) ? .green : .primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(favoritesManager.isVisited(restaurant.id) ? Color.green.opacity(0.1) : Color(.systemGray6))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    // Location Row
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(restaurant.city)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                
                // Top Dishes Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Top dishes reviewers love")
                            .font(.system(size: 20, weight: .bold))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(topDishes.joined(separator: ", "))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                
                // Photos Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photos")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<3) { index in
                                AsyncImage(url: photoURLs[index]) { phase in
                                    switch phase {
                                    case .empty:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .overlay(ProgressView())
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fill)
                                    case .failure:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    selectedImageIndex = index
                                    showFullScreenImage = true
                                }
                            }
                            
                            // +20 overlay
                            ZStack {
                                AsyncImage(url: photoURLs[3]) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(1, contentMode: .fill)
                                    default:
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                    }
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                
                                Text("+20")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .onTapGesture {
                                selectedImageIndex = 3
                                showFullScreenImage = true
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
                
                // Notes Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes")
                        .font(.system(size: 20, weight: .bold))
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(minHeight: 100)
                        
                        if notes.isEmpty {
                            HStack(spacing: 8) {
                                Text("✏️")
                                    .font(.system(size: 16))
                                Text("Write your notes here...")
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                        }
                        
                        TextEditor(text: $notes)
                            .font(.system(size: 15))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .frame(minHeight: 100)
                            .padding(8)
                            .onChange(of: notes) { newValue in
                                debounceSaveNotes(newValue)
                            }
                    }
                    
                    // Save indicator
                    if isSavingNotes {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Saving...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load notes from restaurant model if available
            if let restaurantNotes = restaurant.notes {
                notes = restaurantNotes
            }
        }
        .onDisappear {
            // Cancel any pending save task
            saveTask?.cancel()
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            FullScreenImageViewer(
                images: [heroImageURL] + photoURLs,
                selectedIndex: $selectedImageIndex,
                isPresented: $showFullScreenImage
            )
        }
    }
    
    private func openInGoogleMaps() {
        // Build search query from restaurant name + city
        let searchQuery = "\(restaurant.name), \(restaurant.city)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try Google Maps app first
        if let googleMapsAppURL = URL(string: "comgooglemaps://?q=\(searchQuery)"),
           UIApplication.shared.canOpenURL(googleMapsAppURL) {
            // User has Google Maps app installed
            UIApplication.shared.open(googleMapsAppURL)
        } else if let webURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(searchQuery)") {
            // Fall back to web version
            UIApplication.shared.open(webURL)
        }
    }
    
    // MARK: - Notes Auto-Save
    
    private func debounceSaveNotes(_ newNotes: String) {
        // Cancel previous save task
        saveTask?.cancel()
        
        // Create new debounced save task
        saveTask = Task {
            // Wait 1 second
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Save to backend
            await saveNotesToBackend(newNotes)
        }
    }
    
    private func saveNotesToBackend(_ notesText: String) async {
        isSavingNotes = true
        
        do {
            _ = try await APIClient.shared.saveNotes(restaurantId: restaurant.id, notes: notesText)
            AppLogger.info("Notes saved successfully", category: .data)
        } catch {
            AppLogger.error("Failed to save notes: \(error)", category: .data)
            // Could show an error alert here if needed
        }
        
        isSavingNotes = false
    }
}

// MARK: - Full Screen Image Viewer
struct FullScreenImageViewer: View {
    let images: [URL]
    @Binding var selectedIndex: Int
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(0..<images.count, id: \.self) { index in
                    AsyncImage(url: images[index]) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = lastScale * value
                                        }
                                        .onEnded { _ in
                                            lastScale = scale
                                            if scale < 1.0 {
                                                withAnimation {
                                                    scale = 1.0
                                                    lastScale = 1.0
                                                }
                                            }
                                        }
                                )
                        default:
                            ProgressView()
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            VStack {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
}
