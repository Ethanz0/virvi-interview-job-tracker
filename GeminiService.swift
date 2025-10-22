//
//  GeminiService.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftUI
import FirebaseAI

class GeminiService {
    
    private let ai = FirebaseAI.firebaseAI(backend: .googleAI())
    
    /// Generate interview questions using Firebase AI
    /// - Parameters:
    ///   - title: Interview title
    ///   - prompt: Optional description of what the interview should contain
    ///   - count: number of questions
    ///   - duration: duration of interview question
    /// - Returns: Array of questions as strings
    func generateQuestions(title: String, prompt: String, count: Int = 5, duration: Int = 30) async throws -> [String] {
        
        // Construct the prompt
        let fullPrompt = """
        Generate \(count) interview questions for a \(title) role that can be answered verbally on a phone in \(duration) seconds or less.

        - Keep questions clear and concise
        - Focus on experience and practical knowledge initially
        - No whiteboarding or coding required
        \(prompt.isEmpty ? "" : "\n\(prompt)")
        
        Return the questions as a JSON array with this exact format:
        [
          {"question": "Question text here"},
          {"question": "Another question here"}
        ]
        
        Return ONLY the JSON array, no additional text.
        """
        
        // Configure the model with JSON response mode
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash-lite",
            generationConfig: GenerationConfig(
                responseMIMEType: "application/json"
            )
        )
        
        do {
            // Generate content
            let response = try await model.generateContent(fullPrompt)
            
            // Extract the response text
            guard let responseText = response.text else {
                throw NSError(
                    domain: "GeminiService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No response text from Firebase AI"]
                )
            }
            
            // Parse the JSON response
            let jsonData = Data(responseText.utf8)
            let questionItems = try JSONDecoder().decode([QuestionItem].self, from: jsonData)
            
            // Extract just the question strings
            return questionItems.map { $0.question }
            
        } catch {
            print("Firebase AI call failed: \(error.localizedDescription)")
            return []
        }
    }
    /// Generate a single "question of the day" for the widget
    /// - Returns: A single engaging interview question
    func generateQuestionOfTheDay() async throws -> String {
        let fullPrompt = """
        Generate 1 engaging interview question that works as a "question of the day".
        
        - Keep it thought-provoking and relevant to technical or professional interviews
        - Keep the question clear, concise, and under 15 words
        - Make it suitable for verbal response in 30-60 seconds
        - No whiteboarding or coding required
        
        Return the question as a JSON object with this exact format:
        {"question": "Question text here"}
        
        Return ONLY the JSON object, no additional text.
        """
        
        let model = ai.generativeModel(
            modelName: "gemini-2.5-flash-lite",
            generationConfig: GenerationConfig(
                responseMIMEType: "application/json"
            )
        )
        
        do {
            let response = try await model.generateContent(fullPrompt)
            
            guard let responseText = response.text else {
                throw NSError(
                    domain: "GeminiService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No response text from Firebase AI"]
                )
            }
            
            let jsonData = Data(responseText.utf8)
            let questionItem = try JSONDecoder().decode(QuestionItem.self, from: jsonData)
            
            return questionItem.question
            
        } catch {
            print("Firebase AI call failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Question Response Model
struct QuestionItem: Codable {
    let question: String
}
