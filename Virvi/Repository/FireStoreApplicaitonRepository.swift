//
//  ApplicationRepository.swift
//  Virvi
//
//  Created by Ethan Zhang on 3/10/2025.
//

import Foundation
import FirebaseFirestore
// Structure of firestore
//users/{userId}/applications/{appId}/stages/{stageId}

// MARK: - Firestore Implementation
class FirestoreApplicationRepository: ApplicationRepository {
    private let db = Firestore.firestore()
    
    // MARK: - Application CRUD
    
    /// Fetch all applications with their stages for a user
    func fetchApplications(for userId: String) async throws -> [ApplicationWithStages] {
        // Go to the users collection
        let snapshot = try await db.collection("users")
        // Go to the users specific document
            .document(userId)
        // Go to the applications collection
            .collection("applications")
        // Order by descending by date
            .order(by: "date", descending: true)
        // Execute the query
            .getDocuments()
        
        // Create a list of application with stage
        // This will be filled with the application with corresponding stage
        var applicationsWithStages: [ApplicationWithStages] = []
        
        // For each job application
        for document in snapshot.documents {
            // Deserialise back into Application with codable
            // @DocumentID is extracted into application.id
            let application = try document.data(as: Application.self)
            // Get all the stages for this documentID
            let stages = try await fetchStages(for: document.documentID, userId: userId)
            // Sotre each application and its stages into struct
            applicationsWithStages.append(ApplicationWithStages(
                application: application,
                stages: stages
            ))
        }
        
        return applicationsWithStages
    }

    
    /// Create a new application
    func createApplication(_ application: Application, for userId: String) async throws -> String {
        var newApp = application
        newApp.updatedAt = Timestamp()
        
        // Reference to the applications directory
        let ref = try db.collection("users")
            .document(userId)
            .collection("applications")
        // Add new applicatoin
            .addDocument(from: newApp)
        // Return the ID
        return ref.documentID
    }
    
    /// Update an existing application
    func updateApplication(_ application: Application, for userId: String) async throws {
        // Ensure ID exists in application, this shouldn't be possible
        guard let id = application.id else {
            throw RepositoryError.missingId
        }
        
        var updatedApp = application
        updatedApp.updatedAt = Timestamp()
        
        // Navigate to the document and merge data
        try db.collection("users")
            .document(userId)
            .collection("applications")
            .document(id)
            .setData(from: updatedApp, merge: true)
    }
    
    /// Delete an application and all its stages
    func deleteApplication(id: String, for userId: String) async throws {
        // Delete all stages
        try await deleteAllStages(for: id, userId: userId)
        
        // Delete the application
        try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(id)
            .delete()
    }
    
    /// Toggle starred status
    func toggleStar(applicationId: String, for userId: String) async throws {
        // Reference to the specific application in firestore
        let applicationRef = db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
        
        // get the application
        let document = try await applicationRef.getDocument()
        
        // Deserialise into Application
        guard let application = try? document.data(as: Application.self) else {
            throw RepositoryError.notFound
        }
        
        // Update the starred and updated at fields
        try await applicationRef.updateData([
            "starred": !application.starred,
            "updatedAt": Timestamp()
        ])
    }
    
    // MARK: - Stage CRUD
    
    /// Fetch all stages for an application
    func fetchStages(for applicationId: String, userId: String) async throws -> [ApplicationStage] {
        // Get all stages by an application and user
        let stages = try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
        // Get the stages
            .collection("stages")
            .order(by: "sortOrder")
            .getDocuments()
        // Deserialise the stages and put return the array
        return try stages.documents.map { document in
            try document.data(as: ApplicationStage.self)
        }
    }
    
    /// Create a new stage
    func createStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws -> String {
        var newStage = stage
        newStage.updatedAt = Timestamp()
        // Add document
        let ref = try db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .addDocument(from: newStage)
        
        return ref.documentID
    }
    
    /// Update an existing stage
    func updateStage(_ stage: ApplicationStage, for applicationId: String, userId: String) async throws {
        guard let id = stage.id else {
            throw RepositoryError.missingId
        }
        
        var updatedStage = stage
        updatedStage.updatedAt = Timestamp()
        
        // Go to the stage
        try db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .document(id)
        // Update the details of the stage
            .setData(from: updatedStage, merge: true)
    }
    
    /// Delete a single stage
    func deleteStage(id: String, for applicationId: String, userId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .document(id)
            .delete()
    }
    
    /// Delete all stages for an application (used when deleting application)
    func deleteAllStages(for applicationId: String, userId: String) async throws {
        let stages = try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .getDocuments()
        
        // Do batch deletion
        // This is more efficient
        let batch = db.batch()
        for document in stages.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
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

