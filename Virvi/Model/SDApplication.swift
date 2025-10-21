//
//  SDApplication.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore

@Model
final class SDApplication {
    // Local identifier (SwiftData's persistent ID)
    @Attribute(.unique) var id: String
    
    // Firestore document ID (set after syncing)
    var firestoreId: String?
    
    // Application data
    var role: String
    var company: String
    var date: Date
    var statusRawValue: String
    var starred: Bool
    var note: String
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    // Sync tracking
    var needsSync: Bool
    var isDeleted: Bool
    var lastSyncedAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \SDApplicationStage.application)
    var stages: [SDApplicationStage]?
    
    // Computed property for status
    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRawValue) ?? .notApplied }
        set { statusRawValue = newValue.rawValue }
    }
    
    // Formatted date helper
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
    
    init(
        role: String,
        company: String,
        date: Date,
        statusRawValue: String,
        starred: Bool = false,
        note: String = "",
        needsSync: Bool = true,
        isDeleted: Bool = false
    ) {
        self.id = UUID().uuidString
        self.role = role
        self.company = company
        self.date = date
        self.statusRawValue = statusRawValue
        self.starred = starred
        self.note = note
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
        self.isDeleted = isDeleted
    }
    
    // Convert to Firestore model for syncing
    func toFSApplication() -> FSApplication {
        FSApplication(
            id: firestoreId,
            role: role,
            company: company,
            date: Timestamp(date: date),
            status: status,
            starred: starred,
            note: note,
            createdAt: Timestamp(date: createdAt),
            updatedAt: Timestamp(date: updatedAt)
        )
    }
    
    // Create from Firestore model
    static func from(_ fsApp: FSApplication) -> SDApplication {
        let app = SDApplication(
            role: fsApp.role,
            company: fsApp.company,
            date: fsApp.date.dateValue(),
            statusRawValue: fsApp.status.rawValue,
            starred: fsApp.starred,
            note: fsApp.note,
            needsSync: false,
            isDeleted: false
        )
        app.firestoreId = fsApp.id
        app.createdAt = fsApp.createdAt.dateValue()
        app.updatedAt = fsApp.updatedAt.dateValue()
        return app
    }
}

@Model
final class SDApplicationStage {
    @Attribute(.unique) var id: String
    var firestoreId: String?
    
    var stageRawValue: String
    var statusRawValue: String
    var date: Date
    var note: String
    var sortOrder: Int
    
    var createdAt: Date
    var updatedAt: Date
    
    var needsSync: Bool
    var isDeleted: Bool
    var lastSyncedAt: Date?
    
    @Relationship
    var application: SDApplication?
    
    var stage: StageType {
        get { StageType(rawValue: stageRawValue) ?? .applied }
        set { stageRawValue = newValue.rawValue }
    }
    
    var status: StageStatus {
        get { StageStatus(rawValue: statusRawValue) ?? .incomplete }
        set { statusRawValue = newValue.rawValue }
    }
    
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
    
    init(
        stageRawValue: String,
        statusRawValue: String,
        date: Date,
        note: String = "",
        sortOrder: Int,
        needsSync: Bool = true,
        isDeleted: Bool = false
    ) {
        self.id = UUID().uuidString
        self.stageRawValue = stageRawValue
        self.statusRawValue = statusRawValue
        self.date = date
        self.note = note
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = needsSync
        self.isDeleted = isDeleted
    }
    
    func toFSApplicationStage() -> FSApplicationStage {
        FSApplicationStage(
            id: firestoreId,
            stage: stage,
            status: status,
            date: Timestamp(date: date),
            note: note,
            sortOrder: sortOrder,
            createdAt: Timestamp(date: createdAt),
            updatedAt: Timestamp(date: updatedAt)
        )
    }
    
    static func from(_ fsStage: FSApplicationStage) -> SDApplicationStage {
        let stage = SDApplicationStage(
            stageRawValue: fsStage.stage.rawValue,
            statusRawValue: fsStage.status.rawValue,
            date: fsStage.date.dateValue(),
            note: fsStage.note,
            sortOrder: fsStage.sortOrder,
            needsSync: false,
            isDeleted: false
        )
        stage.firestoreId = fsStage.id
        stage.createdAt = fsStage.createdAt.dateValue()
        stage.updatedAt = fsStage.updatedAt.dateValue()
        return stage
    }
}
