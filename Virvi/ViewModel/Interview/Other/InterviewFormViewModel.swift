//
//  InterviewFormViewModel.swift
//  Virvi
//
//  Updated to use repository pattern
//

import Foundation
import SwiftUI
import SwiftData

class InterviewFormViewModel: ObservableObject {
    @Published var interviewTitle: String = ""
    @Published var duration: QuestionDuration = .seconds30
    @Published var numQuestions: Int = 3
    @Published var additionalNotes: String = ""
    @Published var isGenerating: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var questionMode: QuestionMode = QuestionMode.manual
    
    private var repository: InterviewRepositoryProtocol?
    private let geminiService = GeminiService()
    
    func setup(with modelContext: ModelContext) {
        self.repository = SwiftDataInterviewRepository(modelContext: modelContext)
    }
    
    func resetForm() {
        interviewTitle = ""
        duration = .seconds30
        numQuestions = 3
        additionalNotes = ""
        questionMode = .manual
        isGenerating = false
        showError = false
        errorMessage = ""
    }
    
    @MainActor
    func createInterview() async -> Interview? {
        guard let repository = repository else {
            errorMessage = "Repository not initialized"
            showError = true
            return nil
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let newInterview = Interview(
            title: interviewTitle,
            duration: duration.rawValue,
            completed: false,
            additionalContext: questionMode == .dynamic || questionMode == .aiGenerated ? additionalNotes : nil,
            maxQuestions: questionMode == .dynamic ? numQuestions : nil
        )
        
        if questionMode == .aiGenerated {
            do {
                let questionStrings = try await geminiService.generateQuestions(
                    title: interviewTitle,
                    prompt: additionalNotes,
                    count: numQuestions,
                    duration: duration.rawValue
                )
                
                let questionObjects = questionStrings.enumerated().map { index, questionText in
                    Question(question: questionText, order: index)
                }
                
                newInterview.questions = questionObjects
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate questions: \(error.localizedDescription)"
                    showError = true
                }
                return nil
            }
        }

        do {
            try repository.create(interview: newInterview)
            return newInterview
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save interview: \(error.localizedDescription)"
                showError = true
            }
            return nil
        }
    }
}
