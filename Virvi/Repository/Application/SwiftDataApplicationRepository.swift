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
            let stages = (sdApp.stages ?? [])
                .filter { !$0.isDeleted }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
            
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
        
        // Trigger sync in background
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
        // Soft delete
        application.isDeleted = true
        application.updatedAt = Date()
        application.needsSync = true
        
        // Also soft delete all stages
        for stage in application.stages ?? [] {
            stage.isDeleted = true
            stage.updatedAt = Date()
            stage.needsSync = true
        }
        
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
    
    func fetchStages(for application: SDApplication) async throws -> [SDApplicationStage] {
        return (application.stages ?? [])
            .filter { !$0.isDeleted }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
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
        // Soft delete
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
        let stages = application.stages ?? []
        for stage in stages {
            stage.isDeleted = true
            stage.updatedAt = Date()
            stage.needsSync = true
        }
        
        try modelContext.save()
        syncManager?.scheduleSync()
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
