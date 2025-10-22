//
//  AppDependencies.swift
//  Virvi
//
//  Created by Ethan Zhang on 21/10/2025.
//


import Foundation
import SwiftData

@MainActor
class AppDependencies: ObservableObject {
    let modelContext: ModelContext
    let syncManager: SyncManager
    let applicationRepository: ApplicationRepository
    let authService: AuthServicing
    
    init(modelContext: ModelContext, authService: AuthServicing? = nil) {
        self.modelContext = modelContext
        
        // Use injected auth service or create real one
        self.authService = authService ?? AuthService()
        
        // Create sync manager
        self.syncManager = SyncManager(modelContext: modelContext)
        
        // Create repository with sync manager
        self.applicationRepository = SwiftDataApplicationRepository(
            modelContext: modelContext,
            syncManager: syncManager
        )
    }
    
    // Helper to enable sync when user logs in
    func enableSync(for userId: String) async {
        if let repo = applicationRepository as? SwiftDataApplicationRepository {
            repo.setAuthenticationState(isAuthenticated: true)
        }
        await syncManager.enableSync(for: userId)
    }
    
    // Helper to disable sync when user logs out
    func disableSync() async {
        if let repo = applicationRepository as? SwiftDataApplicationRepository {
            repo.setAuthenticationState(isAuthenticated: false)
        }
        await syncManager.disableSync()
    }
}
