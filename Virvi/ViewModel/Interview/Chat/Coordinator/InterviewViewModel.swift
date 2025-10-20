//
//  InterviewViewModel.swift
//  Virvi
//
//  Updated to expose feedback message
//

import SwiftUI
import SwiftData
import Combine

@MainActor
class InterviewViewModel: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var showingCamera: Bool = false
    @Published var recordedVideoURL: URL?
    
    private var strategy: InterviewStrategy?
    private var interview: Interview?
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    
    var videoVM = VideoViewModel()
    
    var hasMoreQuestions: Bool {
        strategy?.hasMoreQuestions ?? false
    }
    
    var maxVideoDuration: TimeInterval {
        TimeInterval(interview?.duration ?? 120)
    }
    
    var currentQuestion: Question? {
        strategy?.currentQuestion
    }
    
    var visibleQuestions: [Question] {
        strategy?.visibleQuestions ?? []
    }
    
    var questions: [Question] {
        interview?.questions.sorted { $0.order < $1.order } ?? []
    }
    
    var isGeneratingQuestion: Bool {
        strategy?.isGeneratingQuestion ?? false
    }
    
    var isProcessingAnswer: Bool {
        strategy?.isProcessingAnswer ?? false
    }
    
    var totalQuestions: Int {
        strategy?.totalQuestions ?? 0
    }
    
    var answeredQuestions: Int {
        strategy?.answeredQuestions ?? 0
    }
    
    var feedbackMessage: String? {
        // First check if the interview itself has feedback stored
        if let feedback = interview?.feedback {
            return feedback
        }
        // Otherwise check the dynamic strategy's current feedback
        if let dynamicStrategy = strategy as? DynamicInterviewStrategy {
            return dynamicStrategy.feedbackMessage
        }
        return nil
    }
    
    func setup(with interview: Interview, modelContext: ModelContext, isDynamicMode: Bool = false) {
        self.interview = interview
        self.modelContext = modelContext
        
        if isDynamicMode {
            let dynamicStrategy = DynamicInterviewStrategy()
            
            dynamicStrategy.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
            
            strategy = dynamicStrategy
        } else {
            let staticStrategy = StaticInterviewStrategy()
            
            staticStrategy.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &cancellables)
            
            strategy = staticStrategy
        }
        
        strategy?.setup(with: interview, modelContext: modelContext)
    }
    
    func startRecording() {
        showingCamera = true
    }
    
    func endInterviewEarly() {
        strategy?.endInterview()
    }
    
    func handleVideoRecorded(url: URL, isDynamicMode: Bool) async {
        isRecording = true
        showingCamera = false
        
        await videoVM.transcribeVideo(at: url)
        
        let transcript = videoVM.transcription
        let permanentURL = videoVM.permanentVideoURL
        
        await strategy?.handleAnswerSubmitted(
            transcript: transcript.isEmpty ? "" : transcript,
            videoURL: permanentURL
        )
        
        isRecording = false
        recordedVideoURL = nil
    }
}
