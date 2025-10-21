//
//  InterviewStrategy.swift
//  Virvi
//
//  Created by Ethan Zhang on 20/10/2025.
//

import Foundation
import SwiftData

/// Protocol defining the contract for different interview strategies
@MainActor
protocol InterviewStrategy {
    /// Setup the strategy with interview and context
    func setup(with interview: Interview, modelContext: ModelContext)
    
    /// Get the current question being asked
    var currentQuestion: Question? { get }
    
    /// Get all visible questions up to current point
    var visibleQuestions: [Question] { get }
    
    /// Check if there are more questions remaining
    var hasMoreQuestions: Bool { get }
    
    /// Check if currently generating a question
    var isGeneratingQuestion: Bool { get }
    
    /// Check if currently processing an answer
    var isProcessingAnswer: Bool { get }
    
    /// Handle when a video answer is recorded and transcribed
    func handleAnswerSubmitted(transcript: String, videoURL: URL?) async
    
    /// End the interview early
    func endInterview()
    
    /// Get total number of questions for progress tracking
    var totalQuestions: Int { get }
    
    /// Get number of answered questions
    var answeredQuestions: Int { get }
}
