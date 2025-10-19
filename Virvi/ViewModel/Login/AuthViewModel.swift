//
//  AuthViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 2/10/2025.
//

import Foundation
@MainActor
final class AuthViewModel: ObservableObject {
    /// ``AppUser`` of signed in user
    @Published var user: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Service responsible for authenticating user
    private let authService: AuthServicing
    /// Constructor that dependency injects services
    init(authService: AuthServicing = AuthService()) {
        self.authService = authService
        self.user = authService.currentUser
    }
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let appUser = try await authService.signInWithGoogle()
                self.user = appUser
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
    func signOut() {
        do {
            try authService.signOut()
            self.user = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

