import Foundation
import Security

class AuthManager {
    static let shared = AuthManager()
    
    // Key for Keychain
    private let tokenKey = "com.reelmapper.auth.token"
    
    // App Group for sharing with Share Extension
    private let appGroupID = "group.com.reelmapper.shared"
    private let sharedTokenKey = "authToken"
    
    func saveToken(_ token: String) {
        // Save to Keychain
        let data = Data(token.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey,
            kSecValueData: data
        ] as [CFString : Any]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
        
        // Also save to App Group for Share Extension
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.set(token, forKey: sharedTokenKey)
        sharedDefaults?.synchronize()
    }
    
    func getToken() -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as [CFString : Any]
        
        var dataTypeRef: AnyObject? = nil
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        return nil
    }
    
    func clearToken() {
        // Clear from Keychain
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: tokenKey
        ] as [CFString : Any]
        SecItemDelete(query as CFDictionary)
        
        // Clear from App Group
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        sharedDefaults?.removeObject(forKey: sharedTokenKey)
        sharedDefaults?.synchronize()
    }
    
    // Temporary helper for development
    func simulateLogin() {
        // In real app this would be a login API call
        self.saveToken("fake-jwt-token-for-dev")
    }
}
