//
//  QuestionListViewModel.swift
//  Virvi
//
//  Updated to use repository pattern
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class QuestionListViewModel: ObservableObject {
    @Published var questionTexts: [String] = [""]
    @Published var isSaving: Bool = false
    
    var interview: Interview?
    private var repository: InterviewRepositoryProtocol?
    
    var canStart: Bool {
        !questionTexts.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    func setup(with interview: Interview, modelContext: ModelContext) {
        self.interview = interview
        self.repository = SwiftDataInterviewRepository(modelContext: modelContext)
        loadExistingQuestions()
    }
    
    private func loadExistingQuestions() {
        guard let interview = interview else { return }
        
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
        guard let interview = interview, let repository = repository else { return false }
        
        isSaving = true
        
        let validQuestions = questionTexts
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .enumerated()
            .map { index, text in
                Question(question: text, order: index)
            }
        
        interview.questions = validQuestions
        
        do {
            try repository.update(interview: interview)
            isSaving = false
            return true
        } catch {
            isSaving = false
            return false
        }
    }
}
