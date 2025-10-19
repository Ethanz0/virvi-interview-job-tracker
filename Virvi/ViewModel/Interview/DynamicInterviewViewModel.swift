//
//  DynamicInterviewViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 10/10/2025.
//

import Foundation
import SwiftUI
import SwiftData
import FirebaseAI

/// This viewmodel is responsible for coordinating between firebase AI and the ``InterviewViewModel``
@MainActor
class DynamicInterviewViewModel: ObservableObject {
    @Published var currentQuestion: Question?
    // History of questions
    @Published var allQuestions: [Question] = []
    // For showing loading state in UI
    @Published var isGeneratingQuestion: Bool = false
    // For showing processing UI
    @Published var isProcessingAnswer: Bool = false
    @Published var errorMessage: String?
    @Published var interviewCompleted: Bool = false
    
    // Firebae AI instance with googleAI backend
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    // The ongoing conversation
    private var chat: Chat?
    private var interview: Interview?
    private var modelContext: ModelContext?
    private var maxQuestions: Int = 10
    private var duration: Int = 60
    
    // Provided once at the beginning
    private let systemPrompt = """
    You are an experienced job interviewer conducting a professional interview. Your role is to:
    
    1. Ask relevant, thoughtful follow-up questions based on the candidate's previous answers
    2. Keep questions focused on the job role and requirements mentioned in the interview context
    3. Ask questions that help evaluate the candidate's skills, experience, and fit for the role
    4. Maintain a professional yet conversational tone
    5. Each question should be concise (1-2 sentences maximum)
    6. Do not repeat similar questions
    7. Progress naturally through different aspects: experience, skills, scenarios, culture fit
    8. Every 2 or 3 question, ensure to move on to a new question that is irrelevant the the candidate's answers.
    9. Once the user is on their second last question, provide feedback. e.g if Maximum questions is 3, provide the feedback on the third question. 
    10. Ignore 9 if there is only 1 question
    
    Response format: Return ONLY the next interview question as plain text. No preambles, explanations, or formatting.
    """
    
    /// Setup this viewmodel
    /// - Parameters:
    ///   - interview: Interview object to initialise attibutes such as ``Interview/duration`` and ``Interview/maxQuestions``
    ///   - modelContext: Model context for swiftdata
    func setup(with interview: Interview, modelContext: ModelContext) {
        self.interview = interview
        self.modelContext = modelContext
        self.maxQuestions = interview.maxQuestions ?? 10
        self.duration = interview.duration
        
        // Initialize Gemini chat with the prompt we created before
        // Role: means this is from the system not actual user doing interview
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash",
            systemInstruction: ModelContent(role: "system", parts: systemPrompt)
        )
        
        // Start chat with interview context
        let contextMessage = """
        Interview Context:
        Position: \(interview.title)
        Additional Information: \(interview.additionalContext ?? "General interview")
        Maximum Questions: \(maxQuestions)
        Individual Question Answer Time: \(duration) seconds
        
        Start the interview by asking an opening question. Remember to ask only one question at a time.
        """
        // Start a chat with context for history
        // The messages for here are from the user
        chat = model.startChat(history: [
            ModelContent(role: "user", parts: contextMessage)
        ])
    }
    
    /// Start the interview by generating the first question
    func startInterview() async {
        isGeneratingQuestion = true
        errorMessage = nil
        
        do {
            // Ensure we have a valid chat session
            guard let chat = chat else {
                throw NSError(domain: "DynamicInterview", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Chat not initialized"])
            }
            // Tell AI to start interview
            let response = try await chat.sendMessage("Begin the interview.")
            
            // Process returned question
            if let questionText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !questionText.isEmpty {
                // Create new question object with question text
                let question = Question(
                    question: questionText,
                    order: 0
                )
                
                currentQuestion = question
                allQuestions.append(question)
                interview?.questions.append(question)
                // Save to modelcontext
                try? modelContext?.save()
            }
            
        } catch {
            errorMessage = "Failed to generate first question: \(error.localizedDescription)"
        }
        
        isGeneratingQuestion = false
    }
    
    /// Called when user makes answer to question
    /// - Parameters:
    ///   - transcript: Transcription of answer
    ///   - videoURL: URL of video to save
    func handleAnswerSubmitted(transcript: String, videoURL: URL?) async {
        guard let currentQuestion = currentQuestion else { return }
        
        isProcessingAnswer = true
        errorMessage = nil
        
        // Save answer to current question
        currentQuestion.transcript = transcript
        if let videoURL = videoURL {
            currentQuestion.recordingPath = videoURL.path
        }
        
        try? modelContext?.save()
        
        // Check if we've reached max questions
        if allQuestions.count >= maxQuestions {
            endInterviewEarly()
            isProcessingAnswer = false
            return
        }
        
        // Generate next question based on the answer
        await generateNextQuestion(answer: transcript)
        
        isProcessingAnswer = false
    }
    
    /// This function is responsible for generating the question based on the current answer
    /// - Parameter answer: Answer the previous question
    private func generateNextQuestion(answer: String) async {
        isGeneratingQuestion = true
        errorMessage = nil
        
        do {
            guard let chat = chat else {
                throw NSError(domain: "DynamicInterview", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Chat not initialized"])
            }
            
            // Give candidates answer and ask for relevant interview question
            let prompt = """
            Candidate's answer: "\(answer)"
            
            Based on this answer, ask the next relevant interview question. Remember: one question only, concise and professional.
            Questions remaining: \(maxQuestions - allQuestions.count)
            """
            // Send the message and recieve response
            let response = try await chat.sendMessage(prompt)
            
            // Clean up response
            if let questionText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Save next question to model context
                let nextQuestion = Question(
                    question: questionText,
                    order: allQuestions.count
                )
                
                currentQuestion = nextQuestion
                allQuestions.append(nextQuestion)
                interview?.questions.append(nextQuestion)
                
                try? modelContext?.save()
            }
            
        } catch {
            errorMessage = "Failed to generate next question: \(error.localizedDescription)"
        }
        
        isGeneratingQuestion = false
    }
    
    /// End interview early by saving to model context and marking interview as completed
    func endInterviewEarly() {
        interviewCompleted = true
        interview?.completed = true
        interview?.completionDate = Date()
        try? modelContext?.save()
    }
}
