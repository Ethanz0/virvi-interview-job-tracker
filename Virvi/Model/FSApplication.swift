//
//  FSApplication.swift
//  Virvi
//
//  Created by Ethan Zhang on 15/9/2025.
//

import Foundation
import FirebaseFirestore

// MARK: - Application Model

/// Job application model
struct FSApplication: Codable, Identifiable {
    @DocumentID var id: String?
    var role: String
    var company: String
    var date: Timestamp
    var status: ApplicationStatus
    var starred: Bool
    var note: String
    let createdAt: Timestamp
    var updatedAt: Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case role
        case company
        case date
        case status
        case starred
        case note
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        role: String,
        company: String,
        date: Timestamp = Timestamp(),
        status: ApplicationStatus,
        starred: Bool = false,
        note: String = "",
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp()
    ) {
        self.id = id
        self.role = role
        self.company = company
        self.date = date
        self.status = status
        self.starred = starred
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Application Stage Model

/// Job application stage model
struct FSApplicationStage: Codable, Identifiable {
    @DocumentID var id: String?
    var stage: StageType
    var status: StageStatus
    var date: Timestamp
    var note: String
    var sortOrder: Int
    let createdAt: Timestamp
    var updatedAt: Timestamp
    
    enum CodingKeys: String, CodingKey {
        case id
        case stage
        case status
        case date
        case note
        case sortOrder
        case createdAt
        case updatedAt
    }
    
    init(
        id: String? = nil,
        stage: StageType,
        status: StageStatus,
        date: Timestamp = Timestamp(),
        note: String = "",
        sortOrder: Int = 0,
        createdAt: Timestamp = Timestamp(),
        updatedAt: Timestamp = Timestamp()
    ) {
        self.id = id
        self.stage = stage
        self.status = status
        self.date = date
        self.note = note
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Application with Stages

/// Stores an ``Application`` with its array of ``ApplicationStage``
struct FSApplicationWithStages: Identifiable {
    var application: FSApplication
    var stages: [FSApplicationStage]
    
    var id: String? {
        application.id
    }
}

extension FSApplication {
    var formattedDate: String {
        date.dateValue().formatted(date: .abbreviated, time: .omitted)
    }
}
extension FSApplicationStage {
    var formattedDate: String {
        date.dateValue().formatted(date: .abbreviated, time: .omitted)
    }
}
