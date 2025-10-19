//
//  QuestionListView.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - QuestionListView with ViewModel
/// This view is responsible for allowing users to add and remove questions from the question list for the interview
struct QuestionListView: View {
    @Environment(\.modelContext) private var modelContext
    let interview: Interview
    /// Path used for navigating between ``InterviewForm``, ``InterviewChatView`` and ``QuestionListView``
    @Binding var path: NavigationPath
    
    @StateObject private var viewModel = QuestionListViewModel()
    
    var body: some View {
        List {
            // Show each question
            ForEach(Array(viewModel.questionTexts.enumerated()), id: \.offset) { index, text in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question \(index + 1)")
                        .font(.headline)
                        .padding(.top, 8)
                    // Textfield for question
                    TextField("Enter question", text: $viewModel.questionTexts[index], axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .lineLimit(3...10)
                        .padding(.bottom, 8)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
            // Delete question
            .onDelete { offsets in
                viewModel.deleteQuestion(at: offsets)
            }
            // Add question
            Button(action: { viewModel.addQuestion() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Question")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationTitle(interview.title)
        .navigationBarTitleDisplayMode(.inline)
        // Setup viewmodel
        .onAppear {
            viewModel.setup(with: interview, modelContext: modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Ensure questions are properly saved to modelcontext
                    Task {
                        let success = await viewModel.saveQuestions()
                        if success {
                            path.append(InterviewDestination.interview(interview))
                        }
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Start")
                            .fontWeight(.semibold)
                    }
                }
                // Ensure nessecary form fields have been filled out
                .disabled(!viewModel.canStart || viewModel.isSaving)
            }
        }
    }
}

// MARK: - Previews
#Preview("Completed Interviews - Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Interview.self, Question.self, configurations: config)
    
    return CompletedInterviewsView()
        .modelContainer(container)
}

#Preview("Completed Interviews - With Data") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Interview.self, Question.self, configurations: config)
    
    let interview1 = Interview(
        title: "iOS Developer at Apple",
        duration: 60,
        questions: [],
        completed: true
    )
    interview1.completionDate = Date().addingTimeInterval(-86400 * 5)
    let q1 = Question(question: "Why Apple?", order: 0)
    q1.transcript = "Because I love the culture of innovation."
    interview1.questions = [q1]
    
    let interview2 = Interview(
        title: "Senior Engineer at Google",
        duration: 120,
        questions: [],
        completed: true
    )
    interview2.completionDate = Date().addingTimeInterval(-86400 * 2)
    let q2 = Question(question: "Tell me about yourself", order: 0)
    q2.transcript = "I'm passionate about building scalable systems."
    interview2.questions = [q2]
    
    container.mainContext.insert(interview1)
    container.mainContext.insert(interview2)
    
    return CompletedInterviewsView()
        .modelContainer(container)
}

#Preview("Question List") {
    @Previewable @State var path = NavigationPath()
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Interview.self, Question.self, configurations: config)
    
    let interview = Interview(
        title: "iOS Developer Interview",
        duration: 60,
        questions: [],
        completed: false
    )
    container.mainContext.insert(interview)
    
    return NavigationStack(path: $path) {
        QuestionListView(interview: interview, path: $path)
    }
    .modelContainer(container)
}

