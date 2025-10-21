import Foundation
import SwiftData

/// SwiftData-based repository implementation
/// This is the primary repository used throughout the app
@MainActor
class SwiftDataApplicationRepository: ApplicationRepository {
    private let modelContext: ModelContext
    private weak var syncManager: SyncManager?
    
    init(modelContext: ModelContext, syncManager: SyncManager? = nil) {
        self.modelContext = modelContext
        self.syncManager = syncManager
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
            // FIX 3: Use fetchStages to get filtered stages with SwiftData predicate
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
        
        // FIX 1: Use deleteAllStages which properly soft-deletes all stages
        try await deleteAllStages(for: application)
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    func toggleStar(_ application: SDApplication) async throws {
        application.starred.toggle()
        application.updatedAt = Date()
        application.needsSync = true
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    // MARK: - Stage CRUD
    // FIX 3: Synchronous version using SwiftData predicate
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
        // FIX 4: Don't update stages that are marked for deletion
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
        // FIX 1: Unified soft delete logic
        stage.isDeleted = true
        stage.updatedAt = Date()
        stage.needsSync = true
        
        if let app = stage.application {
            app.updatedAt = Date()
            app.needsSync = true
        }
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    func deleteAllStages(for application: SDApplication) async throws {
        // FIX 1 & 3: Fetch stages using predicate, then soft delete each
        let stages = try await fetchStages(for: application)
        
        for stage in stages {
            stage.isDeleted = true
            stage.updatedAt = Date()
            stage.needsSync = true
        }
        
        application.updatedAt = Date()
        application.needsSync = true
        
        try modelContext.save()
        syncManager?.scheduleSync()
    }
    
    // MARK: - Cleanup (Hard Delete)
    
    /// Permanently removes soft-deleted items that have been synced
    func cleanupSyncedDeletions() async throws {
        // FIX 2: Clean up both applications AND stages
        
        // Clean up applications
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == true && app.needsSync == false
            }
        )
        
        let syncedDeletedApps = try modelContext.fetch(appDescriptor)
        
        for app in syncedDeletedApps {
            // FIX 5: Cascade cleanup - delete all stages first
            if let stages = app.stages {
                for stage in stages {
                    modelContext.delete(stage)
                }
            }
            
            print("Permanently removing synced deleted app: \(app.company)")
            modelContext.delete(app)
        }
        
        // FIX 2: Clean up orphaned stages (stages whose parent app was deleted)
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
