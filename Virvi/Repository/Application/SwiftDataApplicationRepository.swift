//
//  SwiftDataApplicationRepository.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftData

/// SwiftData-based repository implementation
/// This is the primary repository used throughout the app
@MainActor
class SwiftDataApplicationRepository: ApplicationRepository {
    private let modelContext: ModelContext
    private weak var syncManager: SyncManager?
    private var isUserAuthenticated: Bool = false
    
    init(modelContext: ModelContext, syncManager: SyncManager? = nil) {
        self.modelContext = modelContext
        self.syncManager = syncManager
    }
    
    /// Set authentication state to determine cleanup strategy
    func setAuthenticationState(isAuthenticated: Bool) {
        self.isUserAuthenticated = isAuthenticated
    }
    
    // MARK: - Application CRUD
    
    func fetchApplications() async throws -> [ApplicationWithStages] {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == false
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let applications = try modelContext.fetch(descriptor)
        
        return applications.map { sdApp in
            let stages = (try? fetchStagesSync(for: sdApp)) ?? []
            
            return ApplicationWithStages(
                application: sdApp,
                stages: stages
            )
        }
    }
    
    func createApplication(
        role: String,
        company: String,
        date: Date,
        status: ApplicationStatus,
        starred: Bool,
        note: String
    ) async throws -> SDApplication {
        let sdApp = SDApplication(
            role: role,
            company: company,
            date: date,
            statusRawValue: status.rawValue,
            starred: starred,
            note: note,
            needsSync: true,
            isDeleted: false
        )
        
        modelContext.insert(sdApp)
        try modelContext.save()
        
        syncManager?.scheduleSync()
        
        return sdApp
    }
    
    func updateApplication(_ application: SDApplication) async throws {
        application.updatedAt = Date()
        application.needsSync = true
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    func deleteApplication(_ application: SDApplication) async throws {
        // Soft delete application
        application.isDeleted = true
        application.updatedAt = Date()
        application.needsSync = true
        
        // Use deleteAllStages which properly soft-deletes all stages
        try await deleteAllStages(for: application)
        
        try modelContext.save()
        
        // If user is not authenticated, clean up immediately (no sync needed)
        if !isUserAuthenticated {
            print("User not authenticated - cleaning up deletion immediately")
            try await cleanupLocalDeletions()
        } else {
            syncManager?.scheduleSync()
        }
    }
    
    func toggleStar(_ application: SDApplication) async throws {
        application.starred.toggle()
        application.updatedAt = Date()
        application.needsSync = true
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    // MARK: - Bulk Operations
    
    func deleteAllApplications() async throws {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == false
            }
        )
        
        let applications = try modelContext.fetch(descriptor)
        
        for app in applications {
            try await deleteApplication(app)
        }
    }
    
    func getApplicationCount() async throws -> Int {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == false
            }
        )
        
        let applications = try modelContext.fetch(descriptor)
        return applications.count
    }
    
    // MARK: - Stage CRUD
    
    // Synchronous version using SwiftData predicate
    private func fetchStagesSync(for application: SDApplication) throws -> [SDApplicationStage] {
        let appId = application.id
        
        // Use SwiftData predicate to filter at query time
        let descriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate<SDApplicationStage> { stage in
                stage.application?.id == appId && stage.isDeleted == false
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func fetchStages(for application: SDApplication) async throws -> [SDApplicationStage] {
        return try fetchStagesSync(for: application)
    }
    
    func createStage(
        for application: SDApplication,
        stage: StageType,
        status: StageStatus,
        date: Date,
        note: String,
        sortOrder: Int
    ) async throws -> SDApplicationStage {
        let sdStage = SDApplicationStage(
            stageRawValue: stage.rawValue,
            statusRawValue: status.rawValue,
            date: date,
            note: note,
            sortOrder: sortOrder,
            needsSync: true,
            isDeleted: false
        )
        
        sdStage.application = application
        modelContext.insert(sdStage)
        
        application.updatedAt = Date()
        application.needsSync = true
        
        try modelContext.save()
        syncManager?.scheduleSync()
        
        return sdStage
    }
    
    func updateStage(_ stage: SDApplicationStage) async throws {
        // Don't update stages that are marked for deletion
        guard !stage.isDeleted else {
            print("Skipping update for deleted stage")
            return
        }
        
        stage.updatedAt = Date()
        stage.needsSync = true
        
        if let app = stage.application {
            app.updatedAt = Date()
            app.needsSync = true
        }
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    func deleteStage(_ stage: SDApplicationStage) async throws {
        // Unified soft delete logic
        stage.isDeleted = true
        stage.updatedAt = Date()
        stage.needsSync = true
        
        if let app = stage.application {
            app.updatedAt = Date()
            app.needsSync = true
        }
        
        try modelContext.save()
        
        // If user is not authenticated, clean up immediately (no sync needed)
        if !isUserAuthenticated {
            print("User not authenticated - cleaning up stage deletion immediately")
            try await cleanupLocalDeletions()
        } else {
            syncManager?.scheduleSync()
        }
    }
    
    func deleteAllStages(for application: SDApplication) async throws {
        // Fetch stages using predicate, then soft delete each
        let stages = try await fetchStages(for: application)
        
        for stage in stages {
            stage.isDeleted = true
            stage.updatedAt = Date()
            stage.needsSync = true
        }
        
        application.updatedAt = Date()
        application.needsSync = true
        
        try modelContext.save()
        
        // If user is not authenticated, clean up immediately (no sync needed)
        if !isUserAuthenticated {
            print("User not authenticated - cleaning up stage deletions immediately")
            try await cleanupLocalDeletions()
        } else {
            syncManager?.scheduleSync()
        }
    }
    
    // MARK: - Cleanup (Hard Delete)
    
    /// Permanently removes soft-deleted items that have been synced
    func cleanupSyncedDeletions() async throws {
        // Clean up both applications AND stages
        
        // Clean up applications
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == true && app.needsSync == false
            }
        )
        
        let syncedDeletedApps = try modelContext.fetch(appDescriptor)
        
        for app in syncedDeletedApps {
            // Cascade cleanup - delete all stages first
            if let stages = app.stages {
                for stage in stages {
                    modelContext.delete(stage)
                }
            }
            
            print("Permanently removing synced deleted app: \(app.company)")
            modelContext.delete(app)
        }
        
        // Clean up orphaned stages (stages whose parent app was deleted)
        let stageDescriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { stage in
                stage.isDeleted == true && stage.needsSync == false
            }
        )
        
        let syncedDeletedStages = try modelContext.fetch(stageDescriptor)
        
        for stage in syncedDeletedStages {
            print("Permanently removing synced deleted stage: \(stage.stage.rawValue)")
            modelContext.delete(stage)
        }
        
        if !syncedDeletedApps.isEmpty || !syncedDeletedStages.isEmpty {
            try modelContext.save()
            print("Cleaned up \(syncedDeletedApps.count) apps and \(syncedDeletedStages.count) stages")
        }
    }
    
    /// Permanently removes soft-deleted items for non-authenticated users
    /// This should be called when user is not logged in to clean up local deletions
    func cleanupLocalDeletions() async throws {
        // For non-authenticated users, delete all soft-deleted items immediately
        // since there's no cloud sync to worry about
        
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == true
            }
        )
        
        let deletedApps = try modelContext.fetch(appDescriptor)
        
        for app in deletedApps {
            // Cascade cleanup - delete all stages first
            if let stages = app.stages {
                for stage in stages {
                    modelContext.delete(stage)
                }
            }
            
            print("Permanently removing locally deleted app: \(app.company)")
            modelContext.delete(app)
        }
        
        // Clean up orphaned stages
        let stageDescriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { stage in
                stage.isDeleted == true
            }
        )
        
        let deletedStages = try modelContext.fetch(stageDescriptor)
        
        for stage in deletedStages {
            print("Permanently removing locally deleted stage: \(stage.stage.rawValue)")
            modelContext.delete(stage)
        }
        
        if !deletedApps.isEmpty || !deletedStages.isEmpty {
            try modelContext.save()
            print("Cleaned up \(deletedApps.count) apps and \(deletedStages.count) stages (local only)")
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case notFound
    case missingId
    case invalidData
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "The requested item was not found."
        case .missingId:
            return "Item is missing an ID."
        case .invalidData:
            return "The data is invalid or corrupted."
        case .unauthorized:
            return "You don't have permission to perform this action."
        }
    }
}
