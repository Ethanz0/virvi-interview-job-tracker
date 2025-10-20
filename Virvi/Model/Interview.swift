//
//  Interview.swift
//  Virvi
//
//  SwiftData model for Interview
//

import Foundation
import SwiftData

/// Interview model for interview simulations, stores array of questions
@Model
class Interview {
    var id: UUID
    var title: String
    var duration: Int
    var completed: Bool
    var completionDate: Date?
    var additionalContext: String?
    var maxQuestions: Int?
    var feedback: String?
    @Relationship(deleteRule: .cascade)
    var questions: [Question]
    
    init(title: String,
         duration: Int,
         questions: [Question] = [],
         completed: Bool = false,
         additionalContext: String? = nil,
         maxQuestions: Int? = nil) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.questions = questions
        self.completed = completed
        self.additionalContext = additionalContext
        self.maxQuestions = maxQuestions
    }
}

/// Individual question model, owned by interview
@Model
class Question {
    var id: UUID
    var question: String
    var order: Int
    var transcript: String?
    var recordingURL: URL?
    
    init(question: String, order: Int) {
        self.id = UUID()
        self.question = question
        self.order = order
    }
}
