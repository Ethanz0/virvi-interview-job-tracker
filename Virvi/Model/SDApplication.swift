import Foundation
import FirebaseCore
import SwiftData

// MARK: - SwiftData Application Model
@Model
final class SDApplication {
    @Attribute(.unique) var id: String
    var role: String
    var company: String
    var date: Date
    var statusRawValue: String
    var starred: Bool
    var note: String
    var createdAt: Date
    var updatedAt: Date
    
    // Sync metadata
    var needsSync: Bool
    var lastSyncedAt: Date?
    var firestoreId: String?
    var isDeleted: Bool  // NEW: Soft delete flag
    
    // Relationship to stages
    @Relationship(deleteRule: .cascade, inverse: \SDApplicationStage.application)
    var stages: [SDApplicationStage]?
    
    init(
        id: String = UUID().uuidString,
        role: String,
        company: String,
        date: Date = Date(),
        statusRawValue: String,
        starred: Bool = false,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = true,
        lastSyncedAt: Date? = nil,
        firestoreId: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.role = role
        self.company = company
        self.date = date
        self.statusRawValue = statusRawValue
        self.starred = starred
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.lastSyncedAt = lastSyncedAt
        self.firestoreId = firestoreId
        self.isDeleted = isDeleted
    }
    
    // Computed property for ApplicationStatus
    var status: ApplicationStatus {
        get { ApplicationStatus(rawValue: statusRawValue) ?? .notApplied }
        set { statusRawValue = newValue.rawValue }
    }
    
    // Convert to your existing Application model
    func toApplication() -> Application {
        Application(
            id: firestoreId ?? id,
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
    
    // Create from your existing Application model
    static func from(_ app: Application) -> SDApplication {
        SDApplication(
            id: UUID().uuidString,
            role: app.role,
            company: app.company,
            date: app.date.dateValue(),
            statusRawValue: app.status.rawValue,
            starred: app.starred,
            note: app.note,
            createdAt: app.createdAt.dateValue(),
            updatedAt: app.updatedAt.dateValue(),
            needsSync: false,
            lastSyncedAt: Date(),
            firestoreId: app.id,
            isDeleted: false
        )
    }
}

// MARK: - SwiftData ApplicationStage Model
@Model
final class SDApplicationStage {
    @Attribute(.unique) var id: String
    var stageRawValue: String
    var statusRawValue: String
    var date: Date
    var note: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Sync metadata
    var needsSync: Bool
    var lastSyncedAt: Date?
    var firestoreId: String?
    var isDeleted: Bool
    
    // Relationship back to application
    var application: SDApplication?
    
    init(
        id: String = UUID().uuidString,
        stageRawValue: String,
        statusRawValue: String,
        date: Date = Date(),
        note: String = "",
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        needsSync: Bool = true,
        lastSyncedAt: Date? = nil,
        firestoreId: String? = nil,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.stageRawValue = stageRawValue
        self.statusRawValue = statusRawValue
        self.date = date
        self.note = note
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.needsSync = needsSync
        self.lastSyncedAt = lastSyncedAt
        self.firestoreId = firestoreId
        self.isDeleted = isDeleted
    }
    
    // Computed properties
    var stage: StageType {
        get { StageType(rawValue: stageRawValue) ?? .applied }
        set { stageRawValue = newValue.rawValue }
    }
    
    var status: StageStatus {
        get { StageStatus(rawValue: statusRawValue) ?? .incomplete }
        set { statusRawValue = newValue.rawValue }
    }
    
    // Convert to your existing ApplicationStage model
    func toApplicationStage() -> ApplicationStage {
        ApplicationStage(
            id: firestoreId ?? id,
            stage: stage,
            status: status,
            date: Timestamp(date: date),
            note: note,
            sortOrder: sortOrder,
            createdAt: Timestamp(date: createdAt),
            updatedAt: Timestamp(date: updatedAt)
        )
    }
    
    // Create from your existing ApplicationStage model
    static func from(_ stage: ApplicationStage) -> SDApplicationStage {
        SDApplicationStage(
            id: UUID().uuidString,
            stageRawValue: stage.stage.rawValue,
            statusRawValue: stage.status.rawValue,
            date: stage.date.dateValue(),
            note: stage.note,
            sortOrder: stage.sortOrder,
            createdAt: stage.createdAt.dateValue(),
            updatedAt: stage.updatedAt.dateValue(),
            needsSync: false,
            lastSyncedAt: Date(),
            firestoreId: stage.id,
            isDeleted: false
        )
    }
}
