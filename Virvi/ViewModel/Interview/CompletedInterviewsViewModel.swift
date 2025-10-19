//
//  CompletedInterviewsViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 8/10/2025.
//


import SwiftUI
import SwiftData

// MARK: - CompletedInterviewsViewModel
/// This viewmodel is responsible for querying and displaying the completed interviews and deleting interviews
@MainActor
class CompletedInterviewsViewModel: ObservableObject {
    /// List of interviews stored in swiftdata
    @Published var completedInterviews: [Interview] = []
    @Published var errorMessage: String?
    
    private var modelContext: ModelContext?
    
    /// Setup viewmodel
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCompletedInterviews()
    }
    
    /// This function fetches interviews from modelcontext and sorts them by ``Interview/completionDate``
    func loadCompletedInterviews() {
        guard let modelContext = modelContext else { return }
        
        do {
            completedInterviews = try modelContext.fetch(FetchDescriptor<Interview>(
                predicate: #Predicate { $0.completed == true },
                sortBy: [SortDescriptor(\.completionDate, order: .reverse)]
            ))
        } catch {
            errorMessage = "Failed to load interviews: \(error.localizedDescription)"
            print(errorMessage ?? "")
        }
    }
    
    /// This function delets a question from modelcontext, with all the videos for the questions
    /// It then calls ``CompletedInterviewsViewModel/loadCompletedInterviews()`` to update the list
    /// - Parameter interview: Interview to delete
    func deleteInterview(_ interview: Interview) {
        guard let modelContext = modelContext else { return }
        
        for question in interview.questions {
            if let recordingPath = question.recordingPath {
                let videoURL = URL(fileURLWithPath: recordingPath)
                try? FileManager.default.removeItem(at: videoURL)
            }
        }
        
        modelContext.delete(interview)
        
        do {
            try modelContext.save()
            loadCompletedInterviews()
        } catch {
            errorMessage = "Failed to delete interview: \(error.localizedDescription)"
        }
    }
}






