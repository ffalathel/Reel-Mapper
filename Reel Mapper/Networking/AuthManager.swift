import Foundation
import Clerk

/// AuthManager - Thin wrapper around Clerk SDK
/// Clerk handles: session state, token refresh (~every 50 seconds), and persistence
@MainActor
class AuthManager {
    static let shared = AuthManager()
    
    // App Group for sharing token with Share Extension
    private let appGroupID = "group.com.reelmapper.shared"
    private let sharedTokenKey = "clerk_session_token"
    private let tokenExpiryKey = "clerk_token_expiry"
    
    private init() {}
    
    // MARK: - Authentication State
    
    /// Check if user is signed in via Clerk
    var isSignedIn: Bool {
        return Clerk.shared.user != nil
    }
    
    // MARK: - Token Access
    
    /// Get current session token from Clerk for API calls
    /// Returns nil if not signed in
    func getToken() async -> String? {
        guard let session = Clerk.shared.session else {
            print("DEBUG AuthManager: No active session")
            return nil
        }
        
        do {
            // getToken returns TokenResource? - need to unwrap
            if let tokenResource = try await session.getToken() {
                print("DEBUG AuthManager: Retrieved token from Clerk: \(tokenResource.jwt.prefix(20))...")
                return tokenResource.jwt
            }
            print("DEBUG AuthManager: Token resource was nil")
            return nil
        } catch {
            print("DEBUG AuthManager: Failed to get token: \(error)")
            return nil
        }
    }
    
    /// Force refresh token (skip cache) - use after 401 errors
    func getTokenForceRefresh() async -> String? {
        guard let session = Clerk.shared.session else {
            print("DEBUG AuthManager: No active session for force refresh")
            return nil
        }
        
        do {
            if let tokenResource = try await session.getToken(.init(skipCache: true)) {
                print("DEBUG AuthManager: Force refreshed token: \(tokenResource.jwt.prefix(20))...")
                return tokenResource.jwt
            }
            print("DEBUG AuthManager: Force refresh token resource was nil")
            return nil
        } catch {
            print("DEBUG AuthManager: Failed to force refresh token: \(error)")
            return nil
        }
    }
    
    // MARK: - Sign Out
    
    /// Sign out via Clerk and clear Share Extension token
    func signOut() async throws {
        print("DEBUG AuthManager: Signing out...")
        try await Clerk.shared.signOut()
        clearExtensionToken()
        print("DEBUG AuthManager: Sign out complete")
    }
    
    // MARK: - Share Extension Token Bridge
    
    /// Store current token for Share Extension access
    /// Call this when app becomes active and after sign-in
    func storeTokenForExtension() async {
        guard let token = await getToken() else {
            print("DEBUG AuthManager: No token to store for extension")
            return
        }
        
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(token, forKey: sharedTokenKey)
        // Token expires in ~60 seconds, set expiry at 50 seconds to be safe
        sharedDefaults?.set(Date().addingTimeInterval(50), forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
        print("DEBUG AuthManager: Stored token for Share Extension")
    }
    
    /// Clear Share Extension token
    private func clearExtensionToken() {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.removeObject(forKey: sharedTokenKey)
        sharedDefaults?.removeObject(forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
        print("DEBUG AuthManager: Cleared Share Extension token")
    }
}
