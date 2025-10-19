
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


struct InterviewForm: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = InterviewFormViewModel()
    @Binding var path: NavigationPath
    let resetTrigger: UUID
    
    var body: some View {
        Form {
            Section("Interview Title") {
                TextField("Interview Title", text: $viewModel.interviewTitle)
            }
            
            Section("Question Time Limit") {
                Picker("Duration", selection: $viewModel.duration) {
                    ForEach(QuestionDuration.allCases) { duration in
                        Text(duration.displayText).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Question Generation") {
                Picker("Method", selection: $viewModel.questionMode) {
                    ForEach(QuestionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
            
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    hideKeyboard()
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.setup(with: modelContext)
        }
        .onChange(of: resetTrigger) { _, _ in
            hideKeyboard()
            viewModel.resetForm()
        }

    }
    
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
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                       to: nil, from: nil, for: nil)
    }
}
