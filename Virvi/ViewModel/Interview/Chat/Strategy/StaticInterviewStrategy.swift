//
//  StaticInterviewStrategy.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftData

@MainActor
class StaticInterviewStrategy: InterviewStrategy, ObservableObject {
    @Published private var currentQuestionIndex: Int = 0
    @Published var isProcessingAnswer: Bool = false
    
    private var interview: Interview?
    private var repository: InterviewRepositoryProtocol?
    private var questions: [Question] = []
    
    var isGeneratingQuestion: Bool { false }
    
    var currentQuestion: Question? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var visibleQuestions: [Question] {
        Array(questions.prefix(currentQuestionIndex + 1))
    }
    
    var hasMoreQuestions: Bool {
        currentQuestionIndex < questions.count
    }
    
    var totalQuestions: Int {
        questions.count
    }
    
    var answeredQuestions: Int {
        visibleQuestions.filter { $0.transcript != nil }.count
    }
    
    func setup(with interview: Interview, modelContext: ModelContext) {
        self.interview = interview
        self.repository = SwiftDataInterviewRepository(modelContext: modelContext)
        self.questions = interview.questions.sorted { $0.order < $1.order }
        self.currentQuestionIndex = 0
    }
    
    func handleAnswerSubmitted(transcript: String, videoURL: URL?) async {
        isProcessingAnswer = true
        
        let currentQuestion = questions[currentQuestionIndex]
        currentQuestion.transcript = transcript.isEmpty ? "" : transcript
        currentQuestion.recordingURL = videoURL
        
        currentQuestionIndex += 1
        
        if !hasMoreQuestions {
            endInterview()
        }
        
        try? repository?.saveContext()
        isProcessingAnswer = false
    }
    
    func endInterview() {
        interview?.completed = true
        interview?.completionDate = Date()
        try? repository?.saveContext()
    }
}
