//
//  MockApplicationRepository.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//
import Foundation
import FirebaseFirestore

// MARK: - Mock Repository

/// This is a mock repository used for previews and testing viewmodels
class MockApplicationRepository: ApplicationRepository {
    /// Handle applications with a array
    var applications: [ApplicationWithStages] = []
    
    func fetchApplications(for userId: String) async throws -> [ApplicationWithStages] {
        return applications
    }
    
    
    func createApplication(_ application: Application, for userId: String) async throws -> String {
        let id = UUID().uuidString
        var newApp = application
        newApp.id = id
        applications.append(ApplicationWithStages(application: newApp, stages: []))
        return id
    }
    
    func updateApplication(_ application: Application, for userId: String) async throws {
        guard let index = applications.firstIndex(where: { $0.id == application.id }) else {
            throw RepositoryError.notFound
        }
        applications[index].application = application
    }
    
    func deleteApplication(id: String, for userId: String) async throws {
        applications.removeAll { $0.id == id }
    }
    
    func toggleStar(applicationId: String, for userId: String) async throws {
        guard let index = applications.firstIndex(where: { $0.id == applicationId }) else {
            throw RepositoryError.notFound
        }
        applications[index].application.starred.toggle()
    }
    
    func fetchStages(for applicationId: String, userId: String) async throws -> [ApplicationStage] {
        guard let app = applications.first(where: { $0.id == applicationId }) else {
            throw RepositoryError.notFound
        }
        return app.stages
    }
    
    func createStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws -> String {
        guard let index = applications.firstIndex(where: { $0.id == applicationId }) else {
            throw RepositoryError.notFound
        }
        var newStage = stage
        newStage.id = UUID().uuidString
        applications[index].stages.append(newStage)
        return newStage.id!
    }
    
    func updateStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws {
        guard let appIndex = applications.firstIndex(where: { $0.id == applicationId }),
              let stageIndex = applications[appIndex].stages.firstIndex(where: { $0.id == stage.id }) else {
            throw RepositoryError.notFound
        }
        applications[appIndex].stages[stageIndex] = stage
    }
    
    func deleteStage(id: String, for applicationId: String, userId: String) async throws {
        guard let appIndex = applications.firstIndex(where: { $0.id == applicationId }) else {
            throw RepositoryError.notFound
        }
        applications[appIndex].stages.removeAll { $0.id == id }
    }
    
    func deleteAllStages(for applicationId: String, userId: String) async throws {
        guard let index = applications.firstIndex(where: { $0.id == applicationId }) else {
            throw RepositoryError.notFound
        }
        applications[index].stages.removeAll()
    }
    func findApplication(company: String, role: String, date: Date, for userId: String) async throws -> Application? {
        // Look for an application in the array that matches the unique fields
        if let appWithStages = applications.first(where: {
            $0.application.company == company &&
            $0.application.role == role &&
            $0.application.date.dateValue() == date
        }) {
            return appWithStages.application
        }
        return nil
    }
}
