//
//  CompletedInterviewsView.swift
//  Virvi
//
//  Created by Ethan Zhang on 9/10/2025.
//

import Foundation
import SwiftUI
// MARK: - Completed Interview Row
/// This view is responsible for displaying the ``Interview/title``, ``Interview/questions`` count and ``Interview/completionDate`` for a interview
struct CompletedInterviewRow: View {
    let interview: Interview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Interview title
            Text(interview.title)
                .font(.headline)
            
            HStack(spacing: 8) {
                // Number of questions
                Text("\(interview.questions.count) questions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // If completion date exists, show it
                if let date = interview.completionDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CompletedInterviewsView
/// This view handles the main screen for displaying the list of ``CompletedInterviewRow`` with navigation lists to ``InterviewChatView``
struct CompletedInterviewsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CompletedInterviewsViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                // No interviews exist
                if viewModel.completedInterviews.isEmpty {
                    ContentUnavailableView(
                        "No Completed Interviews",
                        systemImage: "checkmark.circle",
                        description: Text("Complete an interview to see it here")
                    )
                } else {
                    // Show a list of completed interview rows
                    List {
                        ForEach(viewModel.completedInterviews) { interview in
                            // When the row is clicked, navigate to chat view, with review mode on
                            NavigationLink(destination: InterviewChatView(interview: interview, isReviewMode: true)) {
                                CompletedInterviewRow(interview: interview)
                            }
                        }
                        // Delete a interview
                        .onDelete { offsets in
                            offsets.forEach { index in
                                viewModel.deleteInterview(viewModel.completedInterviews[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Completed Interviews")
            // Setup viewmodel with modelcontext
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
            // Allow reloading
            .refreshable {
                viewModel.loadCompletedInterviews()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
}
