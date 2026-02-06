import Foundation

@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: UserProfile?
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    func fetchCurrentUser() async {
        // Check if user is signed in via Clerk
        guard AuthManager.shared.isSignedIn else {
            currentUser = nil
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            currentUser = try await APIClient.shared.getCurrentUser()
        } catch APIError.unauthorized {
            print("UserManager: 401 Unauthorized - User needs to re-authenticate")
            self.currentUser = nil
            // Don't call signOut here - let the UI handle it
        } catch {
            self.error = error.localizedDescription
            print("Failed to fetch user: \(error)")
        }
        
        isLoading = false
    }
    
    func clearUser() {
        currentUser = nil
    }
}

