import SwiftUI

@main
struct Reel_MapperApp: App {
    @StateObject private var favoritesManager = FavoritesManager.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .task {
                    // Load favorites and visited from backend on app launch
                    await favoritesManager.loadFromBackend()
                }
        }
    }
}
