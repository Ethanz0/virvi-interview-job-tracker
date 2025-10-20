//
//  InterviewRepository.swift
//  Virvi
//
//  Repository pattern for Interview CRUD operations
//

import Foundation
import SwiftData

protocol InterviewRepositoryProtocol {
    func create(interview: Interview) throws
    func getAll() throws -> [Interview]
    func getCompleted() throws -> [Interview]
    func getById(id: UUID) throws -> Interview?
    func update(interview: Interview) throws
    func delete(interview: Interview) throws
    func deleteAll() throws
    func saveContext() throws
}

class SwiftDataInterviewRepository: InterviewRepositoryProtocol {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func create(interview: Interview) throws {
        modelContext.insert(interview)
        try modelContext.save()
    }
    
    func getAll() throws -> [Interview] {
        let descriptor = FetchDescriptor<Interview>(
            sortBy: [SortDescriptor(\.completionDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func getCompleted() throws -> [Interview] {
        let descriptor = FetchDescriptor<Interview>(
            predicate: #Predicate { $0.completed == true },
            sortBy: [SortDescriptor(\.completionDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    func getById(id: UUID) throws -> Interview? {
        let descriptor = FetchDescriptor<Interview>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func update(interview: Interview) throws {
        try modelContext.save()
    }
    
    func delete(interview: Interview) throws {
        // Delete associated video files
        for question in interview.questions {
            if let videoURL = question.recordingURL {
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
        
        modelContext.delete(interview)
        try modelContext.save()
    }
    
    func deleteAll() throws {
        let allInterviews = try getAll()
        
        // Delete all video files first
        for interview in allInterviews {
            for question in interview.questions {
                if let videoURL = question.recordingURL {
                    try? FileManager.default.removeItem(at: videoURL)
                }
            }
            modelContext.delete(interview)
        }
        
        try modelContext.save()
    }
    
    func saveContext() throws {
        try modelContext.save()
    }
}
