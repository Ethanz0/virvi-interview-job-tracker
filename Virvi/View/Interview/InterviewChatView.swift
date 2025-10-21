//
//  InterviewChatView.swift
//  Virvi
//
//  Updated with network monitoring banner and alert
//

import SwiftUI
import SwiftData
import AVFoundation
import AVKit

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
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var permissionsGranted = false
    @State private var showingPermissionAlert = false
    @State private var showingNetworkAlert = false
    @State private var loadingStartTime = Date()
    @State private var showTimeoutWarning = false
    
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
            
            if !networkMonitor.isConnected && isDynamicMode && !isReviewMode {
                networkWarningBanner
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
                        
                        if let feedback = viewModel.feedbackMessage {
                            FeedbackBubble(feedback: feedback)
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
            loadingStartTime = Date()
            viewModel.setup(with: interview,
                          modelContext: modelContext,
                          isDynamicMode: isDynamicMode)
            
            if !isReviewMode {
                Task {
                    permissionsGranted = await viewModel.videoVM.requestPermissions()
                }
                
                if isDynamicMode {
                    startTimeoutMonitoring()
                }
            }
        }
        .onChange(of: networkMonitor.isConnected) { _, isConnected in
            if !isConnected && isDynamicMode && !isReviewMode {
                showingNetworkAlert = true
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
        .alert("No Internet Connection", isPresented: $showingNetworkAlert) {
            Button("OK") { }
        } message: {
            Text("An internet connection is required for AI-generated questions. Please connect to Wi-Fi or cellular data.")
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
    private var networkWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            Text("No Internet Connection")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.red)
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
                    if viewModel.isGeneratingQuestion {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Generating feedback...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
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
            
            if showTimeoutWarning {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text("This is taking longer than usual")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text("Please check your internet connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 12)
            }
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
    
    private func startTimeoutMonitoring() {
        Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            
            if viewModel.visibleQuestions.isEmpty && viewModel.isGeneratingQuestion {
                showTimeoutWarning = true
            }
        }
    }
}

struct FeedbackBubble: View {
    let feedback: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Interview Feedback")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            Text(feedback)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .font(.body)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
