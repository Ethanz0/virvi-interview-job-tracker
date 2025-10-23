//
//  AuthServicing.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import UIKit

protocol AuthServicing {
    var currentUser: AppUser? { get }
    func signInWithGoogle() async throws -> AppUser
    func signInWithApple(authorization: ASAuthorization) async throws -> AppUser
    func signOut() throws
    func deleteAccount() async throws
}

final class AuthService: NSObject, AuthServicing {
    private let auth = FirebaseManager.shared.auth
    
    // Store the current nonce for Apple Sign-In
    private var currentNonce: String?
    
    var currentUser: AppUser? {
        guard let user = auth.currentUser else { return nil }
        return AppUser.fromFirebaseUser(user)
    }
    
    // MARK: - Google Sign-In
    
    @MainActor
    func signInWithGoogle() async throws -> AppUser {
        guard let presenter = Self.rootViewController else {
            throw AuthError.misconfigured("Unable to find root view controller")
        }
        
        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        
        let googleUser = signInResult.user
        guard let idToken = googleUser.idToken?.tokenString else {
            throw AuthError.misconfigured("Missing Google ID token")
        }
        let accessToken = googleUser.accessToken.tokenString
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        let authResult = try await auth.signIn(with: credential)
        return AppUser.fromFirebaseUser(authResult.user)
    }
    
    // MARK: - Apple Sign-In
    
    /// Generate a nonce for Apple Sign-In
    func generateNonce() -> String {
        let nonce = randomNonceString()
        self.currentNonce = nonce
        return nonce
    }
    
    /// Sign in with Apple using the authorization result
    func signInWithApple(authorization: ASAuthorization) async throws -> AppUser {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.misconfigured("Invalid Apple ID credential")
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.misconfigured("Invalid state: A login callback was received, but no login request was sent.")
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.misconfigured("Unable to fetch identity token")
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.misconfigured("Unable to serialize token string from data")
        }
        
        // Create Firebase credential
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        // Sign in with Firebase
        let authResult = try await auth.signIn(with: credential)
        
        if let fullName = appleIDCredential.fullName,
           let givenName = fullName.givenName,
           authResult.user.displayName == nil {
            let changeRequest = authResult.user.createProfileChangeRequest()
            changeRequest.displayName = givenName
            try await changeRequest.commitChanges()
        }
        
        return AppUser.fromFirebaseUser(authResult.user)
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        try auth.signOut()
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.misconfigured("No user is currently signed in")
        }
        
        // Attempt to delete the Firebase Auth account
        try await user.delete()
        
        GIDSignIn.sharedInstance.signOut()
    }
    
    // MARK: - Helpers
    
    @MainActor
    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    enum AuthError: LocalizedError {
        case misconfigured(String)
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .misconfigured(let msg): return msg
            case .unknown: return "Unknown authentication error."
            }
        }
    }
}

// MARK: - Mock Auth Service for Previews

class MockAuthService: AuthServicing {
    var currentUser: AppUser? = AppUser(
        id: "preview-user-123",
        firstName: "Preview",
        email: "preview@example.com"
    )
    
    func signInWithGoogle() async throws -> AppUser {
        let user = AppUser(
            id: "preview-user-123",
            firstName: "Preview",
            email: "preview@example.com"
        )
        currentUser = user
        return user
    }
    
    func signInWithApple(authorization: ASAuthorization) async throws -> AppUser {
        let user = AppUser(
            id: "preview-user-456",
            firstName: "Apple User",
            email: "appleuser@example.com"
        )
        currentUser = user
        return user
    }
    
    func signOut() throws {
        currentUser = nil
    }
    
    func deleteAccount() async throws {
        currentUser = nil
    }
    
    func generateNonce() -> String {
        return "mock-nonce"
    }
}
