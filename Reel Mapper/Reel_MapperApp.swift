import SwiftUI

@main
struct Reel_MapperApp: App {
    @StateObject private var favoritesManager = FavoritesManager.shared
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
                .task {
                    // Load favorites and visited from backend on app launch
                    await favoritesManager.loadFromBackend()
                }
        }
    }
}
