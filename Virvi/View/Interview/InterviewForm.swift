
//
//  InterviewForm.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//
import Foundation
import SwiftUI
// MARK: - Enums
/// This enum is for selecting the duration of each question, used for AI prompt
enum QuestionDuration: Int, CaseIterable, Identifiable {
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes5 = 300

    var id: Int { self.rawValue }

    var displayText: String {
        switch self {
        case .seconds30: return "30s"
        case .minute1: return "1m"
        case .minutes2: return "2m"
        case .minutes5: return "5m"
        }
    }
}

/// This enum is for picking between:
///  ``manual``: User creates their own questions
///  ``aiGenerated``: Use gemini api to generate questions, can be edited
///  ``dynamic``: Questions are contextually generated, cannot be edited
enum QuestionMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case aiGenerated = "AI Generated"
    case dynamic = "AI Dynamic"
    
    var id: String { self.rawValue }
}
// MARK: - Interview Form View
/// This view is the initial form the user fills out to specify the configuration of the interview
struct InterviewForm: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = InterviewFormViewModel()
    /// Path used for navigating between ``InterviewForm``, ``InterviewChatView`` and ``QuestionListView``
    @Binding var path: NavigationPath
    
    var body: some View {
        Form {
            Section("Interview Title") {
                TextField("Interview Title", text: $viewModel.interviewTitle)
            }
            // Use enum to show picker of times
            Section("Question Time Limit") {
                Picker("Duration", selection: $viewModel.duration) {
                    ForEach(QuestionDuration.allCases) { duration in
                        Text(duration.displayText).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Question generation method
            Section("Question Generation") {
                Picker("Method", selection: $viewModel.questionMode) {
                    ForEach(QuestionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Ask for number of questions and optional interview context if using one of the AI modes
            if viewModel.questionMode == .aiGenerated || viewModel.questionMode == .dynamic {
                Section("Number of Questions") {
                    Stepper("Questions: \(viewModel.numQuestions)",
                           value: $viewModel.numQuestions, in: 1...20)
                }
                Section("Interview Context") {
                    TextEditor(text: $viewModel.additionalNotes)
                        .frame(minHeight: 100)
                }
            }
            // MARK: - Continue Button
            // Continue/Generating button if the user is generating quetsions
            Section {
                Button(action: createInterviewAndNavigate) {
                    HStack {
                        Spacer()
                        if viewModel.isGenerating {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(viewModel.isGenerating ? "Generating..." : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(viewModel.interviewTitle.isEmpty || viewModel.isGenerating)
            }
        }
        .navigationTitle("Interview Details")
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        // Setup viewmodel on startup
        .onAppear {
            viewModel.setup(with: modelContext)
        }
    }
    
    /// This function is triggered after the user presses continue on the form
    /// If the question mode is dynamic, append to the navigation path, a enum of type ``QuestionMode/dynamic`` to go immediately to ``InterviewForm``
    /// Otherwise continue to ``QuestionListView``
    func createInterviewAndNavigate() {
        Task { @MainActor in
            if let newInterview = await viewModel.createInterview() {
                if viewModel.questionMode == .dynamic {
                    path.append(InterviewDestination.dynamicInterview(newInterview))
                } else {
                    path.append(InterviewDestination.questionList(newInterview))
                }
            }
        }
    }
}
