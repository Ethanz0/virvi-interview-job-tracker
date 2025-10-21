//
//  DynamicInterviewStrategy.swift
//  Virvi
//
//  Updated with timeout and network error handling
//

import Foundation
import SwiftData
import FirebaseAI

@MainActor
class DynamicInterviewStrategy: InterviewStrategy, ObservableObject {
    @Published var currentQuestion: Question?
    @Published var allQuestions: [Question] = []
    @Published var isGeneratingQuestion: Bool = false
    @Published var isProcessingAnswer: Bool = false
    @Published var errorMessage: String?
    @Published private var interviewCompleted: Bool = false
    @Published var feedbackMessage: String?
    @Published var hasTimedOut: Bool = false
    
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private var chat: Chat?
    private var interview: Interview?
    private var repository: InterviewRepositoryProtocol?
    private var maxQuestions: Int = 10
    private var duration: Int = 60
    
    // Timeout configuration
    private let questionGenerationTimeout: TimeInterval = 10
    private let answerProcessingTimeout: TimeInterval = 20
    
    var visibleQuestions: [Question] {
        allQuestions
    }
    
    var hasMoreQuestions: Bool {
        !interviewCompleted
    }
    
    var totalQuestions: Int {
        maxQuestions
    }
    
    var answeredQuestions: Int {
        allQuestions.filter { $0.transcript != nil }.count
    }
    
    private let systemPrompt = """
    You are an experienced job interviewer conducting a professional interview. Your role is to:
    
    1. Ask relevant, thoughtful follow-up questions based on the candidate's previous answers
    2. Keep questions focused on the job role and requirements mentioned in the interview context
    3. Ask questions that help evaluate the candidate's skills, experience, and fit for the role
    4. Maintain a professional yet conversational tone
    5. Each question should be concise (1-2 sentences maximum)
    6. Do not repeat similar questions
    7. Progress naturally through different aspects: experience, skills, scenarios, culture fit
    8. Every 2 or 3 questions, ensure to move on to a new topic that is not directly related to the candidate's previous answers
    
    Response format: Return ONLY the next interview question as plain text. No preambles, explanations, or formatting.
    """
    
    func setup(with interview: Interview, modelContext: ModelContext) {
        self.interview = interview
        self.repository = SwiftDataInterviewRepository(modelContext: modelContext)
        self.maxQuestions = interview.maxQuestions ?? 10
        self.duration = interview.duration
        
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash-lite",
            systemInstruction: ModelContent(role: "system", parts: systemPrompt)
        )
        
        let contextMessage = """
        Interview Context:
        Position: \(interview.title)
        Additional Information: \(interview.additionalContext ?? "General interview")
        Maximum Questions: \(maxQuestions)
        Individual Question Answer Time: \(duration) seconds
        
        Start the interview by asking an opening question. Remember to ask only one question at a time.
        """
        
        chat = model.startChat(history: [
            ModelContent(role: "user", parts: contextMessage)
        ])
        
        Task {
            await startInterview()
        }
    }
    
    private func startInterview() async {
        isGeneratingQuestion = true
        errorMessage = nil
        hasTimedOut = false
        
        do {
            guard let chat = chat else {
                throw NSError(domain: "DynamicInterview", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Chat not initialized"])
            }
            
            let response = try await withTimeout(seconds: questionGenerationTimeout) {
                try await chat.sendMessage("Begin the interview.")
            }
            
            if let questionText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !questionText.isEmpty {
                let question = Question(question: questionText, order: 0)
                
                currentQuestion = question
                allQuestions.append(question)
                interview?.questions.append(question)
                try? repository?.saveContext()
            }
            
        } catch is TimeoutError {
            hasTimedOut = true
            errorMessage = "Question generation timed out. Please check your internet connection and try again."
        } catch let urlError as URLError {
            handleNetworkError(urlError)
        } catch {
            errorMessage = "Failed to generate first question: \(error.localizedDescription)"
        }
        
        isGeneratingQuestion = false
    }
    
    func handleAnswerSubmitted(transcript: String, videoURL: URL?) async {
        guard let currentQuestion = currentQuestion else { return }
        
        isProcessingAnswer = true
        errorMessage = nil
        hasTimedOut = false
        
        currentQuestion.transcript = transcript
        currentQuestion.recordingURL = videoURL
        
        try? repository?.saveContext()
        
        if allQuestions.count >= maxQuestions {
            await generateFinalFeedback()
            endInterview()
            isProcessingAnswer = false
            return
        }
        
        await generateNextQuestion(answer: transcript)
        isProcessingAnswer = false
    }
    
    private func generateNextQuestion(answer: String) async {
        isGeneratingQuestion = true
        errorMessage = nil
        hasTimedOut = false
        
        do {
            guard let chat = chat else {
                throw NSError(domain: "DynamicInterview", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Chat not initialized"])
            }
            
            let prompt = """
            Candidate's answer: "\(answer)"
            
            Based on this answer, ask the next relevant interview question. Remember: one question only, concise and professional.
            Questions remaining: \(maxQuestions - allQuestions.count)
            """
            
            let response = try await withTimeout(seconds: questionGenerationTimeout) {
                try await chat.sendMessage(prompt)
            }
            
            if let questionText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let nextQuestion = Question(
                    question: questionText,
                    order: allQuestions.count
                )
                
                currentQuestion = nextQuestion
                allQuestions.append(nextQuestion)
                interview?.questions.append(nextQuestion)
                
                try? repository?.saveContext()
            }
            
        } catch is TimeoutError {
            hasTimedOut = true
            errorMessage = "Question generation timed out. Please check your internet connection and try again."
        } catch let urlError as URLError {
            handleNetworkError(urlError)
        } catch {
            errorMessage = "Failed to generate next question: \(error.localizedDescription)"
        }
        
        isGeneratingQuestion = false
    }
    
    private func generateFinalFeedback() async {
        isGeneratingQuestion = true
        errorMessage = nil
        hasTimedOut = false
        
        do {
            guard let chat = chat else {
                throw NSError(domain: "DynamicInterview", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Chat not initialized"])
            }
            
            let feedbackPrompt = """
            The interview is now complete. Please provide constructive feedback on the candidate's overall performance.
            
            Include:
            1. Key strengths demonstrated
            2. Areas for improvement
            3. Overall impression
            
            Keep the feedback concise (2-3 short paragraphs, each under 50 words) and professional.
            """
            
            let response = try await withTimeout(seconds: answerProcessingTimeout) {
                try await chat.sendMessage(feedbackPrompt)
            }
            
            if let feedback = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
                feedbackMessage = feedback
                interview?.feedback = feedback
                try? repository?.saveContext()
            }
            
        } catch is TimeoutError {
            hasTimedOut = true
            errorMessage = "Feedback generation timed out. The interview has been saved without AI feedback."
        } catch let urlError as URLError {
            handleNetworkError(urlError)
        } catch {
            errorMessage = "Failed to generate feedback: \(error.localizedDescription)"
        }
        
        isGeneratingQuestion = false
    }
    
    private func handleNetworkError(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet:
            errorMessage = "No internet connection. Please connect to the internet and try again."
        case .networkConnectionLost:
            errorMessage = "Network connection lost. Please check your connection and try again."
        case .timedOut:
            hasTimedOut = true
            errorMessage = "Request timed out. Please check your internet connection."
        default:
            errorMessage = "Network error: \(error.localizedDescription)"
        }
    }
    
    func retryCurrentOperation() async {
        if allQuestions.isEmpty {
            await startInterview()
        } else if let lastQuestion = allQuestions.last,
                  lastQuestion.transcript != nil {
            await generateNextQuestion(answer: lastQuestion.transcript ?? "")
        }
    }
    
    func endInterview() {
        interviewCompleted = true
        interview?.completed = true
        interview?.completionDate = Date()
        try? repository?.saveContext()
    }
}

// MARK: - Timeout Helper

struct TimeoutError: Error {
    let message: String = "Operation timed out"
}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
