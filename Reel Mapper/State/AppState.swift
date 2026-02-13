import Foundation
import Clerk

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isAuthenticated: Bool = false
    
    private init() {
        // Initial state - will be updated when Clerk loads
        updateAuthState()
    }
    
    func updateAuthState() {
        isAuthenticated = Clerk.shared.user != nil
    }
    
    func logout() async {
        do {
            try await AuthManager.shared.signOut()
            isAuthenticated = false
        } catch {
            AppLogger.error("Failed to sign out: \(error)", category: .auth)
        }
    }
}
