//
//  ApplicationRepository.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftData

/// Wrapper to hold an application with its stages for easier handling
struct ApplicationWithStages: Identifiable {
    let application: SDApplication
    let stages: [SDApplicationStage]
    
    var id: String { application.id }
}

/// Repository protocol for managing applications and stages
/// All implementations work with SwiftData models
@MainActor
protocol ApplicationRepository {
    // Application CRUD
    func fetchApplications() async throws -> [ApplicationWithStages]
    func createApplication(role: String, company: String, date: Date, status: ApplicationStatus, starred: Bool, note: String) async throws -> SDApplication
    func updateApplication(_ application: SDApplication) async throws
    func deleteApplication(_ application: SDApplication) async throws
    func toggleStar(_ application: SDApplication) async throws
    
    // Stage CRUD
    func fetchStages(for application: SDApplication) async throws -> [SDApplicationStage]
    func createStage(for application: SDApplication, stage: StageType, status: StageStatus, date: Date, note: String, sortOrder: Int) async throws -> SDApplicationStage
    func updateStage(_ stage: SDApplicationStage) async throws
    func deleteStage(_ stage: SDApplicationStage) async throws
    func deleteAllStages(for application: SDApplication) async throws
}
