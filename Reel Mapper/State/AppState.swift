import Foundation

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isAuthenticated: Bool = false
    
    private init() {
        // Check if token exists on init
        isAuthenticated = AuthManager.shared.getToken() != nil
    }
    
    func login(token: String) {
        AuthManager.shared.saveToken(token)
        isAuthenticated = true
    }
    
    func logout() {
        // In production, would clear token from Keychain
        isAuthenticated = false
    }
}
