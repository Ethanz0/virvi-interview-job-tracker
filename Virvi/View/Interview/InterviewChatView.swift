//
//  VideoPlayerView.swift
//  Virvi
//
//  Created by Ethan Zhang on 8/10/2025.
//

import SwiftUI
import SwiftData
import AVFoundation
import AVKit

// MARK: - Video Player View
struct VideoPlayerView: View {
    let videoURL: URL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .navigationTitle("Recorded Answer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
// MARK: - Interview Chat View
/// This view is responsible for displaying the chat UI and main page of completing the interview
struct InterviewChatView: View {
    let interview: Interview
    let isReviewMode: Bool
    let isDynamicMode: Bool
    /// Path used for navigating between ``InterviewForm``, ``InterviewChatView`` and ``QuestionListView``
    var path: Binding<NavigationPath>?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = InterviewViewModel()
    @State private var permissionsGranted = false
    @State private var showingPermissionAlert = false
    
    /// Initialise this view with defaults
    /// - Parameters:
    ///   - interview: Interview model
    ///   - isReviewMode: Interview completed and just browsing default false
    ///   - isDynamicMode: Use firebase AI for dynamic questions, default false
    ///   - path: Navigation path to return to root, default nil
    init(interview: Interview,
         isReviewMode: Bool = false,
         isDynamicMode: Bool = false,
         path: Binding<NavigationPath>? = nil) {
        
        self.interview = interview
        self.isReviewMode = isReviewMode
        self.isDynamicMode = isDynamicMode
        self.path = path
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Always show progress view when not in review mode
            if !isReviewMode {
                progressView
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    // Only show all questions if in review mode
                    let questionsToShow = isReviewMode ? viewModel.questions : viewModel.visibleQuestions
                    
                    // Show loading state if no questions yet
                    if questionsToShow.isEmpty && !isReviewMode {
                        loadingFirstQuestion
                    } else {
                        // Show each question and its answer with question bubble view
                        ForEach(questionsToShow) { question in
                            QuestionBubble(
                                question: question,
                                showAnswer: isReviewMode || question.transcript != nil
                            )
                            .id(question.id)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            if !isReviewMode {
                Divider()
                recordingControls
            }
        }
        .navigationTitle(interview.title)
        .navigationBarTitleDisplayMode(.inline)
        // Disable back button if not in review mode
        .navigationBarBackButtonHidden(!isReviewMode)
        // Show tab bar (bottom thing) only if review mode is on
        .toolbar(isReviewMode ? .visible : .hidden, for: .tabBar)
        // Setup viewmodel
        .onAppear {
            viewModel.setup(with: interview,
                          modelContext: modelContext,
                          isDynamicMode: isDynamicMode)
            
            if !isReviewMode {
                Task {
                    permissionsGranted = await viewModel.videoVM.requestPermissions()
                }
            }
        }
        // Allow ending interview early, provided not in review mode
        .toolbar {
            if !isReviewMode {
                ToolbarItem(placement: .primaryAction) {
                    Button("End") {
                        viewModel.endInterviewEarly()
                        dismiss()
                        // Reset path to go to root
                        if let path = path {
                            path.wrappedValue = NavigationPath()
                        }
                    }
                }
            }
        }
        // Camera and mic permissions
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text("Please grant camera and microphone permissions in Settings to record your interview.")
        }
        // Full screen view camera view
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            VideoPicker(
                videoURL: $viewModel.recordedVideoURL,
                maxDuration: viewModel.maxVideoDuration
            )
            .ignoresSafeArea()
        }
        // Once we detect recordedVideoURL has changed from VideoPicker, get this URL and call handlevideoRecorded
        .onChange(of: viewModel.recordedVideoURL) { _, newValue in
            if let url = newValue {
                Task {
                    await viewModel.handleVideoRecorded(url: url, isDynamicMode: isDynamicMode)
                }
            }
        }
    }
    //MARK: - Recording Button
    /// This view is responsible for the record/Done button at the bottom of the chat
    @ViewBuilder
    var recordingControls: some View {
        VStack(spacing: 12) {
            // Normal state of not recording and questions remaining
            if viewModel.hasMoreQuestions && !viewModel.isRecording {
                Button(action: {
                    if permissionsGranted {
                        // Bring up camera view
                        viewModel.startRecording()
                    } else {
                        // Ask for camera perms
                        showingPermissionAlert = true
                    }
                }) {
                    // View for
                    recordButton
                }
                .padding(.horizontal)
                
                // In recording mode and transcribinng
            } else if viewModel.hasMoreQuestions && viewModel.isRecording {
                Text("Processing your answer...")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
                    
                // Finished interview
            } else if !viewModel.hasMoreQuestions {
                VStack(spacing: 12) {
                    Text("Interview Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Button(action: {
                        dismiss()
                        if let path = path {
                            path.wrappedValue = NavigationPath()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    // MARK: - Progress view
    @ViewBuilder
    private var progressView: some View {
        let answeredCount = viewModel.visibleQuestions.filter { $0.transcript != nil }.count
        let totalQuestions = isDynamicMode ? (interview.maxQuestions ?? 10) : viewModel.questions.count
        
        HStack(spacing: 8) {
            ProgressView(value: Double(answeredCount), total: Double(totalQuestions))
                .tint(.blue)
            
            Text("\(answeredCount)/\(totalQuestions)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }
        .padding()
        .background(Color(.systemBackground))
        
        Divider()
    }
    //MARK: - Loading first question
    @ViewBuilder
    private var loadingFirstQuestion: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Preparing your interview...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(isDynamicMode ? "Generating first question" : "Loading questions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    /// View for record button
    private var recordButton: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
            }
            
            Text("Record Answer")
                .font(.headline)
                .foregroundColor(.red)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview("Dynamic Interview") {
    @Previewable @State var path = NavigationPath()
    
    // Mock container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Interview.self, Question.self, configurations: config)
    
    // Mock interview
    let interview = Interview(
        title: "iOS Developer Interview",
        duration: 60,
        questions: [],
        completed: false,
        additionalContext: "Looking for senior iOS developer with SwiftUI experience",
        maxQuestions: 5
    )
    
    // Insert interview into mock containerr
    container.mainContext.insert(interview)
    
    // return view with path
    return NavigationStack(path: $path) {
        InterviewChatView(
            interview: interview,
            isDynamicMode: true,
            path: $path
        )
    }
    .modelContainer(container)
}

#Preview("Static Interview") {
    @Previewable @State var path = NavigationPath()
    
    // Mock container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Interview.self, Question.self, configurations: config)
    
    // Mock interview
    let interview = Interview(
        title: "iOS Developer Interview",
        duration: 60,
        questions: [],
        completed: false
    )
    
    // Mock questions generated by AI
    let q1 = Question(question: "Tell me about yourself", order: 0)
    let q2 = Question(question: "What's your biggest strength?", order: 1)
    let q3 = Question(question: "Describe a challenging project", order: 2)
    
    // Insert mock interview and questions into container
    interview.questions = [q1, q2, q3]
    container.mainContext.insert(interview)
    
    // Return view with path
    return NavigationStack(path: $path) {
        InterviewChatView(
            interview: interview,
            isReviewMode: false,
            path: $path
        )
    }
    .modelContainer(container)
}
