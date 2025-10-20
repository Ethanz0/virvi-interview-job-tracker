//
//  MockApplicationRepository.swift
//  Virvi
//

import Foundation

/// Mock repository for previews and testing
@MainActor
class MockApplicationRepository: ApplicationRepository {
    private var applications: [SDApplication] = []
    
    func fetchApplications() async throws -> [ApplicationWithStages] {
        return applications.map { app in
            let stages = (app.stages ?? [])
                .filter { !$0.isDeleted }
                .sorted(by: { $0.sortOrder < $1.sortOrder })
            
            return ApplicationWithStages(
                application: app,
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
        let app = SDApplication(
            role: role,
            company: company,
            date: date,
            statusRawValue: status.rawValue,
            starred: starred,
            note: note,
            needsSync: false,
            isDeleted: false
        )
        applications.append(app)
        return app
    }
    
    func updateApplication(_ application: SDApplication) async throws {
        // In-memory update - nothing to do as we're working with reference types
        application.updatedAt = Date()
    }
    
    func deleteApplication(_ application: SDApplication) async throws {
        applications.removeAll { $0.id == application.id }
    }
    
    func toggleStar(_ application: SDApplication) async throws {
        application.starred.toggle()
        application.updatedAt = Date()
    }
    
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
        let newStage = SDApplicationStage(
            stageRawValue: stage.rawValue,
            statusRawValue: status.rawValue,
            date: date,
            note: note,
            sortOrder: sortOrder,
            needsSync: false,
            isDeleted: false
        )
        
        newStage.application = application
        
        if application.stages == nil {
            application.stages = []
        }
        application.stages?.append(newStage)
        
        return newStage
    }
    
    func updateStage(_ stage: SDApplicationStage) async throws {
        stage.updatedAt = Date()
    }
    
    func deleteStage(_ stage: SDApplicationStage) async throws {
        if let app = stage.application {
            app.stages?.removeAll { $0.id == stage.id }
        }
    }
    
    func deleteAllStages(for application: SDApplication) async throws {
        application.stages?.removeAll()
    }
}
