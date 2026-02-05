import SwiftUI
import Clerk

struct ContentView: View {
    @Environment(\.clerk) private var clerk
    @EnvironmentObject private var favoritesManager: FavoritesManager
    @State private var authIsPresented = false
    
    var body: some View {
        Group {
            if clerk.user != nil {
                // User is signed in - show main app
                HomeView()
                    .task {
                        // Load favorites and visited from backend on app launch
                        await favoritesManager.loadFromBackend()
                        // Store token for Share Extension
                        await AuthManager.shared.storeTokenForExtension()
                    }
            } else {
                // User is signed out - show sign in prompt
                VStack(spacing: 24) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                    
                    Text("Reel Mapper")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("Save restaurants from Instagram reels")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Sign In") {
                        authIsPresented = true
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    Button("Create Account") {
                        authIsPresented = true
                    }
                    .font(.system(size: 15))
                    .foregroundColor(.red)
                }
                .padding()
            }
        }
        .sheet(isPresented: $authIsPresented) {
            AuthView()  // Clerk's prebuilt auth view
        }
    }
}
