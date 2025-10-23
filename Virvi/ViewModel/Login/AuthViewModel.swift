//
//  AuthViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let authService: AuthServicing
    
    init(authService: AuthServicing = AuthService()) {
        self.authService = authService
        self.user = authService.currentUser
    }
    
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await authService.signInWithGoogle()
                self.user = user
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func signInWithApple(authorization: ASAuthorization) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await authService.signInWithApple(authorization: authorization)
                self.user = user
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try authService.signOut()
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteAccount() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.deleteAccount()
            user = nil
            isLoading = false
        } catch {
            isLoading = false
            throw error
        }
    }
}
