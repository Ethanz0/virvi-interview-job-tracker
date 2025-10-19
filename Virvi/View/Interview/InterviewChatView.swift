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

struct InterviewChatView: View {
    let interview: Interview
    let isReviewMode: Bool
    let isDynamicMode: Bool
    var path: Binding<NavigationPath>?
    var onComplete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = InterviewViewModel()
    @State private var permissionsGranted = false
    @State private var showingPermissionAlert = false
    
    init(interview: Interview,
         isReviewMode: Bool = false,
         isDynamicMode: Bool = false,
         path: Binding<NavigationPath>? = nil,
         onComplete: (() -> Void)? = nil) {
        
        self.interview = interview
        self.isReviewMode = isReviewMode
        self.isDynamicMode = isDynamicMode
        self.path = path
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !isReviewMode {
                progressView
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    let questionsToShow = isReviewMode ? viewModel.questions : viewModel.visibleQuestions
                    
                    if questionsToShow.isEmpty && !isReviewMode {
                        loadingFirstQuestion
                    } else {
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
        .navigationBarBackButtonHidden(!isReviewMode)
        .toolbar(isReviewMode ? .visible : .hidden, for: .tabBar)
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
        .toolbar {
            if !isReviewMode {
                ToolbarItem(placement: .primaryAction) {
                    Button("End") {
                        viewModel.endInterviewEarly()
                        dismiss()
                        onComplete?()
                        if let path = path {
                            path.wrappedValue = NavigationPath()
                        }
                    }
                }
            }
        }
        .alert("Permissions Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text("Please grant camera and microphone permissions in Settings to record your interview.")
        }
        .fullScreenCover(isPresented: $viewModel.showingCamera) {
            VideoPicker(
                videoURL: $viewModel.recordedVideoURL,
                maxDuration: viewModel.maxVideoDuration
            )
            .ignoresSafeArea()
        }
        .onChange(of: viewModel.recordedVideoURL) { _, newValue in
            if let url = newValue {
                Task {
                    await viewModel.handleVideoRecorded(url: url, isDynamicMode: isDynamicMode)
                }
            }
        }
    }
    
    @ViewBuilder
    var recordingControls: some View {
        VStack(spacing: 12) {
            if viewModel.hasMoreQuestions && !viewModel.isRecording && !viewModel.isProcessingAnswer {
                Button(action: {
                    if permissionsGranted {
                        viewModel.startRecording()
                    } else {
                        showingPermissionAlert = true
                    }
                }) {
                    recordButton
                }
                .padding(.horizontal)
                
            } else if viewModel.hasMoreQuestions && (viewModel.isRecording || viewModel.isProcessingAnswer) {
                Text("Processing your answer...")
                    .font(.headline)
                    .foregroundColor(.orange)
                    .padding()
                    
            } else if !viewModel.hasMoreQuestions {
                VStack(spacing: 12) {
                    Text("Interview Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Button(action: {
                        dismiss()
                        onComplete?()
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
    
    @ViewBuilder
    private var progressView: some View {
        HStack(spacing: 8) {
            ProgressView(value: Double(viewModel.answeredQuestions),
                        total: Double(viewModel.totalQuestions))
                .tint(.blue)
            
            Text("\(viewModel.answeredQuestions)/\(viewModel.totalQuestions)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }
        .padding()
        .background(Color(.systemBackground))
        
        Divider()
    }
    
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
