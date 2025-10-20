//
//  CompletedInterviewsViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 8/10/2025.
//

import SwiftUI
import SwiftData

@MainActor
class CompletedInterviewsViewModel: ObservableObject {
    @Published var completedInterviews: [Interview] = []
    @Published var errorMessage: String?
    
    private var repository: InterviewRepositoryProtocol?
    
    func setup(modelContext: ModelContext) {
        self.repository = SwiftDataInterviewRepository(modelContext: modelContext)
        loadCompletedInterviews()
    }
    
    func loadCompletedInterviews() {
        guard let repository = repository else { return }
        
        do {
            completedInterviews = try repository.getCompleted()
        } catch {
            errorMessage = "Failed to load interviews: \(error.localizedDescription)"
            print(errorMessage ?? "")
        }
    }
    
    func deleteInterview(_ interview: Interview) {
        guard let repository = repository else { return }
        
        do {
            try repository.delete(interview: interview)
            loadCompletedInterviews()
        } catch {
            errorMessage = "Failed to delete interview: \(error.localizedDescription)"
        }
    }
}
