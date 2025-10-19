//
//  QuestionListViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 2/10/2025.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - QuestionListViewModel
/// This view model is reponsible for initialising and interacting with interview questions
@MainActor
class QuestionListViewModel: ObservableObject {
    @Published var questionTexts: [String] = [""]
    @Published var isSaving: Bool = false
    
    var interview: Interview?
    private var modelContext: ModelContext?
    
    /// Ensure at least one question exists
    /// Whitespace does not count as a question
    var canStart: Bool {
        !questionTexts.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func setup(with interview: Interview, modelContext: ModelContext) {
        self.interview = interview
        self.modelContext = modelContext
        loadExistingQuestions()
    }
    
    private func loadExistingQuestions() {
        guard let interview = interview else { return }
        
        // If interview already has questions, load them
        if !interview.questions.isEmpty {
            questionTexts = interview.questions
                .sorted { $0.order < $1.order }
                .map { $0.question }
        }
    }
    
    func addQuestion() {
        questionTexts.append("")
    }
    
    func deleteQuestion(at offsets: IndexSet) {
        guard questionTexts.count > 1 else { return }
        questionTexts.remove(atOffsets: offsets)
    }
    
    func saveQuestions() async -> Bool {
        guard let interview = interview, let modelContext = modelContext else { return false }
        
        isSaving = true
        
        // Create Question objects from text
        let validQuestions = questionTexts
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, text in
                Question(question: text, order: index)
            }
        
        // Add questions to interview
        interview.questions = validQuestions
        
        // Save to database
        do {
            try modelContext.save()
            isSaving = false
            return true
        } catch {
            isSaving = false
            return false
        }
    }
}
