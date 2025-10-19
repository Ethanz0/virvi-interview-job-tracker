//
//  ApplicationRepository 2.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//
import Foundation
import FirebaseFirestore

protocol ApplicationRepository {
    // Application CRUD
    func fetchApplications(for userId: String) async throws -> [ApplicationWithStages]
    func createApplication(_ application: Application, for userId: String) async throws -> String
    func updateApplication(_ application: Application, for userId: String) async throws
    func deleteApplication(id: String, for userId: String) async throws
    func toggleStar(applicationId: String, for userId: String) async throws
    
    // Stage CRUD
    func fetchStages(for applicationId: String, userId: String) async throws -> [ApplicationStage]
    func createStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws -> String
    func updateStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws
    func deleteStage(id: String, for applicationId: String, userId: String) async throws
    func deleteAllStages(for applicationId: String, userId: String) async throws
}
