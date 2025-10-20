import Foundation
import FirebaseCore
import SwiftData

// MARK: - SwiftData Repository Implementation
class SwiftDataApplicationRepository: ApplicationRepository {
    private weak var syncManager: SyncManager?

    private let modelContext: ModelContext
    
    init(modelContext: ModelContext, syncManager: SyncManager?) {
        self.modelContext = modelContext
        self.syncManager = syncManager
    }
    
    // MARK: - Application CRUD
    
    func fetchApplications(for userId: String) async throws -> [ApplicationWithStages] {
        // Only fetch non-deleted applications
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == false
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let applications = try modelContext.fetch(descriptor)
        
        return applications.map { sdApp in
            // Only include non-deleted stages
            let stages = (sdApp.stages ?? [])
                .filter { !$0.isDeleted }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
                .map { $0.toApplicationStage() }
            
            return ApplicationWithStages(
                application: sdApp.toApplication(),
                stages: stages
            )
        }
    }
    
    func createApplication(_ application: Application, for userId: String) async throws -> String {
        let sdApp = SDApplication(
            role: application.role,
            company: application.company,
            date: application.date.dateValue(),
            statusRawValue: application.status.rawValue,
            starred: application.starred,
            note: application.note,
            needsSync: true,
            isDeleted: false
        )
        
        modelContext.insert(sdApp)
        try modelContext.save()
        await syncManager?.scheduleSync()
        return sdApp.id
    }
    
    func updateApplication(_ application: Application, for userId: String) async throws {
        guard let id = application.id else {
            throw RepositoryError.missingId
        }
        
        // Find by either local id or firestore id
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                (app.id == id || app.firestoreId == id) && app.isDeleted == false
            }
        )
        
        guard let sdApp = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        sdApp.role = application.role
        sdApp.company = application.company
        sdApp.date = application.date.dateValue()
        sdApp.status = application.status
        sdApp.starred = application.starred
        sdApp.note = application.note
        sdApp.updatedAt = Date()
        sdApp.needsSync = true
        
        try modelContext.save()
        await syncManager?.scheduleSync()
    }
    
    func deleteApplication(id: String, for userId: String) async throws {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.id == id || app.firestoreId == id
            }
        )
        
        guard let sdApp = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        // Soft delete: mark as deleted instead of actually deleting
        sdApp.isDeleted = true
        sdApp.updatedAt = Date()
        sdApp.needsSync = true
        
        // Also mark all stages as deleted
        for stage in sdApp.stages ?? [] {
            stage.isDeleted = true
            stage.updatedAt = Date()
            stage.needsSync = true
        }
        
        try modelContext.save()
        await syncManager?.scheduleSync()
    }
    
    func toggleStar(applicationId: String, for userId: String) async throws {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                (app.id == applicationId || app.firestoreId == applicationId) && app.isDeleted == false
            }
        )
        
        guard let sdApp = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        sdApp.starred.toggle()
        sdApp.updatedAt = Date()
        sdApp.needsSync = true
        
        try modelContext.save()
        await syncManager?.scheduleSync()
    }
    
    // MARK: - Stage CRUD
    
    func fetchStages(for applicationId: String, userId: String) async throws -> [ApplicationStage] {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                (app.id == applicationId || app.firestoreId == applicationId) && app.isDeleted == false
            }
        )
        
        guard let sdApp = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        return (sdApp.stages ?? [])
            .filter { !$0.isDeleted }
            .sorted(by: { $0.sortOrder < $1.sortOrder })
            .map { $0.toApplicationStage() }
    }
    
    func createStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws -> String {
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                (app.id == applicationId || app.firestoreId == applicationId) && app.isDeleted == false
            }
        )
        
        guard let sdApp = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        let sdStage = SDApplicationStage(
            stageRawValue: stage.stage.rawValue,
            statusRawValue: stage.status.rawValue,
            date: stage.date.dateValue(),
            note: stage.note,
            sortOrder: stage.sortOrder,
            needsSync: true,
            isDeleted: false
        )
        
        sdStage.application = sdApp
        modelContext.insert(sdStage)
        
        sdApp.updatedAt = Date()
        sdApp.needsSync = true
        
        try modelContext.save()
        await syncManager?.scheduleSync()
        return sdStage.id
    }
    
    func updateStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws {
        guard let id = stage.id else {
            throw RepositoryError.missingId
        }
        
        let descriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { s in
                (s.id == id || s.firestoreId == id) && s.isDeleted == false
            }
        )
        
        guard let sdStage = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        sdStage.stage = stage.stage
        sdStage.status = stage.status
        sdStage.date = stage.date.dateValue()
        sdStage.note = stage.note
        sdStage.sortOrder = stage.sortOrder
        sdStage.updatedAt = Date()
        sdStage.needsSync = true
        
        if let app = sdStage.application {
            app.updatedAt = Date()
            app.needsSync = true
        }
        
        try modelContext.save()
        await syncManager?.scheduleSync()
    }
    
    func deleteStage(id: String, for applicationId: String, userId: String) async throws {
        let descriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { s in
                s.id == id || s.firestoreId == id
            }
        )
        
        guard let sdStage = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        
        // Soft delete
        sdStage.isDeleted = true
        sdStage.updatedAt = Date()
        sdStage.needsSync = true
        
        if let app = sdStage.application {
            app.updatedAt = Date()
            app.needsSync = true
        }
        
        try modelContext.save()
        await syncManager?.scheduleSync()
    }
    
    func deleteAllStages(for applicationId: String, userId: String) async throws {
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                (app.id == applicationId || app.firestoreId == applicationId) && app.isDeleted == false
            }
        )
        
        guard let sdApp = try modelContext.fetch(appDescriptor).first else {
            throw RepositoryError.notFound
        }
        
        let stages = sdApp.stages ?? []
        for stage in stages {
            stage.isDeleted = true
            stage.updatedAt = Date()
            stage.needsSync = true
        }
        
        try modelContext.save()
        await syncManager?.scheduleSync()
    }
    func findApplication(company: String, role: String, date: Date, for userId: String) async throws -> Application? {
        
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.company == company &&
                app.role == role
            },
            sortBy: [SortDescriptor(\.date)]
        )
        
        guard let sdApp = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        return sdApp.toApplication()
    }

}
