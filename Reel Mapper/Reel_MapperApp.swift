import SwiftUI
import Clerk

// MARK: - Clerk Configuration
struct ClerkConfig {
    // Store your publishable key securely - consider using xcconfig files for different environments
    static let publishableKey = "pk_test_ZGlzdGluY3QtdHVya2V5LTc1LmNsZXJrLmFjY291bnRzLmRldiQ"
}

@main
struct Reel_MapperApp: App {
    @State private var clerk = Clerk.shared
    @StateObject private var favoritesManager = FavoritesManager.shared
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.clerk, clerk)
                .environmentObject(favoritesManager)
                .preferredColorScheme(darkModeEnabled ? .dark : .light)
                .task {
                    clerk.configure(publishableKey: ClerkConfig.publishableKey)
                    try? await clerk.load()
                }
        }
    }
}
