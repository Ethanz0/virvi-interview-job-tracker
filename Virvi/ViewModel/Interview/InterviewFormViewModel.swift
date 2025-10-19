//
//  InterviewFormViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 6/10/2025.
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
    
    private var modelContext: ModelContext?
    private let geminiService = GeminiService()
    
    func setup(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @MainActor
    func createInterview() async -> Interview? {
        guard let modelContext = modelContext else {
            errorMessage = "Model context not initialized"
            showError = true
            return nil
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        // Create interview with appropriate settings
        let newInterview = Interview(
            title: interviewTitle,
            duration: duration.rawValue,
            completed: false,
            additionalContext: questionMode == .dynamic || questionMode == .aiGenerated ? additionalNotes : nil,
            maxQuestions: questionMode == .dynamic ? numQuestions : nil
        )
        
        // Generate questions if AI Generated mode
        if questionMode == .aiGenerated {
            do {
                let questionStrings = try await geminiService.generateQuestions(
                    title: interviewTitle,
                    prompt: additionalNotes,
                    count: numQuestions,
                    duration: duration.rawValue
                )
                
                // Convert question strings to Question objects
                let questionObjects = questionStrings.enumerated().map { index, questionText in
                    Question(question: questionText, order: index)
                }
                
                // Add questions to interview
                newInterview.questions = questionObjects
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate questions: \(error.localizedDescription)"
                    showError = true
                }
                return nil
            }
        }

        // Insert interview
        modelContext.insert(newInterview)
        
        do {
            try modelContext.save()
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
