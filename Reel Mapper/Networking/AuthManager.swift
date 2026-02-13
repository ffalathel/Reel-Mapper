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
            AppLogger.debug("No active session", category: .auth)
            return nil
        }
        
        do {
            // getToken returns TokenResource? - need to unwrap
            if let tokenResource = try await session.getToken() {
                AppLogger.debugSensitive("Retrieved token from Clerk: \(tokenResource.jwt.prefix(20))...", category: .auth)
                return tokenResource.jwt
            }
            AppLogger.warning("Token resource was nil", category: .auth)
            return nil
        } catch {
            AppLogger.error("Failed to get token: \(error)", category: .auth)
            return nil
        }
    }
    
    /// Force refresh token (skip cache) - use after 401 errors
    func getTokenForceRefresh() async -> String? {
        guard let session = Clerk.shared.session else {
            AppLogger.debug("No active session for force refresh", category: .auth)
            return nil
        }
        
        do {
            if let tokenResource = try await session.getToken(.init(skipCache: true)) {
                AppLogger.debugSensitive("Force refreshed token: \(tokenResource.jwt.prefix(20))...", category: .auth)
                return tokenResource.jwt
            }
            AppLogger.warning("Force refresh token resource was nil", category: .auth)
            return nil
        } catch {
            AppLogger.error("Failed to force refresh token: \(error)", category: .auth)
            return nil
        }
    }
    
    // MARK: - Sign Out
    
    /// Sign out via Clerk and clear Share Extension token
    func signOut() async throws {
        AppLogger.info("Signing out...", category: .auth)
        try await Clerk.shared.signOut()
        clearExtensionToken()
        AppLogger.info("Sign out complete", category: .auth)
    }
    
    // MARK: - Share Extension Token Bridge
    
    /// Store current token for Share Extension access
    /// Call this when app becomes active and after sign-in
    func storeTokenForExtension() async {
        guard let token = await getToken() else {
            AppLogger.debug("No token to store for extension", category: .auth)
            return
        }
        
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(token, forKey: sharedTokenKey)
        // Token expires in ~60 seconds, set expiry at 50 seconds to be safe
        sharedDefaults?.set(Date().addingTimeInterval(50), forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
        AppLogger.debug("Stored token for Share Extension", category: .auth)
    }
    
    /// Clear Share Extension token
    private func clearExtensionToken() {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.removeObject(forKey: sharedTokenKey)
        sharedDefaults?.removeObject(forKey: tokenExpiryKey)
        sharedDefaults?.synchronize()
        AppLogger.debug("Cleared Share Extension token", category: .auth)
    }
}
