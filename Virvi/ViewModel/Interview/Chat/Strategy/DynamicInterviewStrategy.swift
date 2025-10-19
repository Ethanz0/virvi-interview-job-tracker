//
//  DynamicInterviewStrategy.swift
//  Virvi
//
//  Created by Ethan Zhang on 20/10/2025.
//


//
//  DynamicInterviewStrategy.swift
//  Virvi
//
//  Strategy for handling AI-generated dynamic interview questions
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
    
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    private var chat: Chat?
    private var interview: Interview?
    private var modelContext: ModelContext?
    private var maxQuestions: Int = 10
    private var duration: Int = 60
    
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
    8. Every 2 or 3 question, ensure to move on to a new question that is irrelevant the the candidate's answers.
    9. Once the user is on their second last question, provide feedback. e.g if Maximum questions is 3, provide the feedback on the third question. 
    10. Ignore 9 if there is only 1 question
    
    Response format: Return ONLY the next interview question as plain text. No preambles, explanations, or formatting.
    """
    
    func setup(with interview: Interview, modelContext: ModelContext) {
        self.interview = interview
        self.modelContext = modelContext
        self.maxQuestions = interview.maxQuestions ?? 10
        self.duration = interview.duration
        
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash",
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
        
        do {
            guard let chat = chat else {
                throw NSError(domain: "DynamicInterview", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Chat not initialized"])
            }
            
            let response = try await chat.sendMessage("Begin the interview.")
            
            if let questionText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines),
               !questionText.isEmpty {
                let question = Question(question: questionText, order: 0)
                
                currentQuestion = question
                allQuestions.append(question)
                interview?.questions.append(question)
                try? modelContext?.save()
            }
            
        } catch {
            errorMessage = "Failed to generate first question: \(error.localizedDescription)"
        }
        
        isGeneratingQuestion = false
    }
    
    func handleAnswerSubmitted(transcript: String, videoURL: URL?) async {
        guard let currentQuestion = currentQuestion else { return }
        
        isProcessingAnswer = true
        errorMessage = nil
        
        currentQuestion.transcript = transcript
        if let videoURL = videoURL {
            currentQuestion.recordingPath = videoURL.path
        }
        
        try? modelContext?.save()
        
        if allQuestions.count >= maxQuestions {
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
            
            let response = try await chat.sendMessage(prompt)
            
            if let questionText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) {
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
    
    func endInterview() {
        interviewCompleted = true
        interview?.completed = true
        interview?.completionDate = Date()
        try? modelContext?.save()
    }
}