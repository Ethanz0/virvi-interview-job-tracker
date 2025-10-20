//
//  FirestoreApplicationRepository.swift
//  Virvi
//
//  This repository is used ONLY by SyncManager for Firebase syncing
//  The main app uses SwiftDataApplicationRepository instead
//

import Foundation
import FirebaseFirestore

class FirestoreApplicationRepository {
    private let db = Firestore.firestore()
    
    // MARK: - Application CRUD (Internal - for syncing only)
    
    func fetchApplications(for userId: String) async throws -> [FSApplicationWithStages] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("applications")
            .order(by: "date", descending: true)
            .getDocuments()
        
        var applicationsWithStages: [FSApplicationWithStages] = []
        
        for document in snapshot.documents {
            let application = try document.data(as: FSApplication.self)
            let stages = try await fetchStages(for: document.documentID, userId: userId)
            
            applicationsWithStages.append(FSApplicationWithStages(
                application: application,
                stages: stages
            ))
        }
        
        return applicationsWithStages
    }
    
    func createApplication(_ application: FSApplication, for userId: String) async throws -> String {
        var newApp = application
        newApp.updatedAt = Timestamp()
        
        let ref = try db.collection("users")
            .document(userId)
            .collection("applications")
            .addDocument(from: newApp)
        
        return ref.documentID
    }
    
    func updateApplication(_ application: FSApplication, for userId: String) async throws {
        guard let id = application.id else {
            throw RepositoryError.missingId
        }
        
        var updatedApp = application
        updatedApp.updatedAt = Timestamp()
        
        try db.collection("users")
            .document(userId)
            .collection("applications")
            .document(id)
            .setData(from: updatedApp, merge: true)
    }
    
    func deleteApplication(id: String, for userId: String) async throws {
        try await deleteAllStages(for: id, userId: userId)
        
        try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(id)
            .delete()
    }
    
    // MARK: - Stage CRUD (Internal - for syncing only)
    
    func fetchStages(for applicationId: String, userId: String) async throws -> [FSApplicationStage] {
        let stages = try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .order(by: "sortOrder")
            .getDocuments()
        
        return try stages.documents.map { document in
            try document.data(as: FSApplicationStage.self)
        }
    }
    
    func createStage(_ stage: FSApplicationStage, for applicationId: String, userId: String) async throws -> String {
        var newStage = stage
        newStage.updatedAt = Timestamp()
        
        let ref = try db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .addDocument(from: newStage)
        
        return ref.documentID
    }
    
    func updateStage(_ stage: FSApplicationStage, for applicationId: String, userId: String) async throws {
        guard let id = stage.id else {
            throw RepositoryError.missingId
        }
        
        var updatedStage = stage
        updatedStage.updatedAt = Timestamp()
        
        try db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .document(id)
            .setData(from: updatedStage, merge: true)
    }
    
    func deleteStage(id: String, for applicationId: String, userId: String) async throws {
        try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .document(id)
            .delete()
    }
    
    func deleteAllStages(for applicationId: String, userId: String) async throws {
        let stages = try await db.collection("users")
            .document(userId)
            .collection("applications")
            .document(applicationId)
            .collection("stages")
            .getDocuments()
        
        let batch = db.batch()
        for document in stages.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }
    
    func findApplication(company: String, role: String, date: Date, for userId: String) async throws -> FSApplication? {
        let timestamp = Timestamp(date: date)
        
        let querySnapshot = try await db.collection("users")
            .document(userId)
            .collection("applications")
            .whereField("company", isEqualTo: company)
            .whereField("role", isEqualTo: role)
            .whereField("date", isEqualTo: timestamp)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = querySnapshot.documents.first else { return nil }
        return try doc.data(as: FSApplication.self)
    }
}
