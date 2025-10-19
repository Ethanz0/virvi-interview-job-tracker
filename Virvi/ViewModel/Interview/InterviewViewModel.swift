//
//  InterviewViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 3/10/2025.
//
import SwiftUI
import SwiftData
import AVFoundation
import AVKit
import Combine

// MARK: - ViewModel
@MainActor
class InterviewViewModel: ObservableObject {
    @Published var currentQuestionIndex: Int = 0
    @Published var isRecording: Bool = false
    @Published var showingCamera: Bool = false
    @Published var recordedVideoURL: URL?
    @Published var isDynamicMode: Bool = false
    
    var interview: Interview?
    var questions: [Question] = []
    private var modelContext: ModelContext?
    var videoVM = VideoViewModel()
    private var cancellables = Set<AnyCancellable>()

    @Published var dynamicVM: DynamicInterviewViewModel?
    
    /// Check if interview is completed
    var hasMoreQuestions: Bool {
        if isDynamicMode {
            return dynamicVM?.interviewCompleted == false
        } else {
            return currentQuestionIndex < questions.count
        }
    }
    var maxVideoDuration: TimeInterval {
        TimeInterval(interview?.duration ?? 120)
    }
    /// Returns the currentQuestion from dynamicVM or from the questions list
    var currentQuestion: Question? {
        if isDynamicMode {
            return dynamicVM?.currentQuestion
        } else {
            guard currentQuestionIndex < questions.count else { return nil }
            return questions[currentQuestionIndex]
        }
    }
    
    // Get all questions up to and including current question for display
    var visibleQuestions: [Question] {
        if isDynamicMode {
            return dynamicVM?.allQuestions ?? []
        } else {
            return Array(questions.prefix(currentQuestionIndex + 1))
        }
    }
    
    func setup(with interview: Interview, modelContext: ModelContext, isDynamicMode: Bool = false) {
        self.interview = interview
        self.modelContext = modelContext
        self.isDynamicMode = isDynamicMode
        
        if isDynamicMode {
            // Initialize dynamic interview viewmodel
            let dynamicViewModel = DynamicInterviewViewModel()
            dynamicViewModel.setup(with: interview, modelContext: modelContext)
            
            // Update the view to generate the first question
            dynamicViewModel.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
            
            self.dynamicVM = dynamicViewModel
            self.questions = []
            self.currentQuestionIndex = 0
            
            Task {
                await dynamicViewModel.startInterview()
            }
        } else {
            // Load existing questions from the interview
            self.questions = interview.questions.sorted { $0.order < $1.order }
            self.currentQuestionIndex = 0
            
            // Show first question if it exists by setting index
            if !questions.isEmpty {
                self.currentQuestionIndex = 0
            }
        }
    }
        
    func startRecording() {
        showingCamera = true
    }
    
    func endInterviewEarly() {
        if isDynamicMode {
            dynamicVM?.endInterviewEarly()
        } else {
            // Mark as complete even if not all questions answered
            interview?.completed = true
            interview?.completionDate = Date()
            try? modelContext?.save()
        }
    }
    
    /// Called when video has been recorded
    /// - Parameters:
    ///   - url: URL of recorded video
    ///   - isDynamicMode: Whether in dynamic mode
    func handleVideoRecorded(url: URL, isDynamicMode: Bool) async {
        // UI update for record button (now showing: Processing your answer)
        isRecording = true
        // Dismiss camera (already happened, but we also do it here)
        showingCamera = false
        
        // Save temp url to permanant URL
        // Extract audio from video
        // Transcribe video
        await videoVM.transcribeVideo(at: url)
        
        // Get the results
        let transcript = videoVM.transcription
        let permanentURL = videoVM.permanentVideoURL
        
        if isDynamicMode {
            // Dynamic mode: Submit answer and get next question
            await dynamicVM?.handleAnswerSubmitted(
                transcript: transcript.isEmpty ? "Recording saved (no speech detected)" : transcript,
                videoURL: permanentURL
            )
            
            isRecording = false
            recordedVideoURL = nil
            
        } else {
            // We need main actor to update the UI as soon as transcription is completed
            // Previously for transcription, we did not need main actor as video processing can be done in background
            await MainActor.run {
                // Get the current question we just answered
                let currentQuestion = questions[currentQuestionIndex]
                // If no speech detected, set as empty string
                // Set the current question's transcript (answer) and recording path
                currentQuestion.transcript = transcript.isEmpty ? "" : transcript
                currentQuestion.recordingPath = permanentURL?.path
                
                // UI change, (Processing is now record button)
                isRecording = false
                recordedVideoURL = nil
                
                // Move to next question
                // In view, this will update progress bar and a new question bubble will appear
                currentQuestionIndex += 1
                
                // Check if any more questions left, otherwise save and complete
                if !hasMoreQuestions {
                    // Mark interview as completed
                    interview?.completed = true
                    interview?.completionDate = Date()
                    // Save to database
                    do {
                        try modelContext?.save()
                    } catch {
                        print("Failed to save interview: \(error)")
                    }
                }
            }
        }
    }
}

