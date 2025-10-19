//
//  InterviewQuestionOfTheDay.swift
//  InterviewStatsWidget
//
//  Created by Ethan Zhang on 10/10/2025.
//

import Foundation
import SwiftUI

/// This config enum returns values within the secrets.plist file
enum Config {
    private static let configDict: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return [:]
        }
        return dict
    }()
    
    /// Returns the gemini api key
    static var geminiAPIKey: String {
        configDict["GEMINI_API_KEY"] as? String ?? ""
    }
}


class GeminiService {
    
    /// Generate a single interview question of the day using Gemini API
    /// - Returns: A single question string
    func generateQuestion() async throws -> String {
        
        // We can force unwrap here since we're supplying the string
        let url = URL(string:"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
        
        // Create the schema for a single question object
        let responseSchema = GeminiRequest.ResponseSchema(
            type: "OBJECT",
            properties: [
                "question": GeminiRequest.ResponseSchema.PropertyDefinition(
                    type: "STRING"
                )
            ]
        )
        
        // Prompt to be sent to gemini
        let fullPrompt = """
        Generate 1 interesting and thought-provoking interview question
        
        - Make it the "question of the day" - something engaging and relevant
        - Keep the question clear, concise and under 15 words
        - No whiteboarding or coding required
        """
        
        // Create the request body and specify we want a json with the customized response schema
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Part(text: fullPrompt)]
                )
            ],
            generationConfig: GeminiRequest.GenerationConfig(
                responseMimeType: "application/json",
                responseSchema: responseSchema
            )
        )
        
        // Create URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.geminiAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode the body
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        
        do {
            // Make the request
            let (data, _) = try await URLSession.shared.data(for: request)
            // Decode response
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            // Extract text
            guard let firstCandidate = geminiResponse.candidates.first,
                  let firstPart = firstCandidate.content.parts.first else {
                throw NSError(domain: "Invalid Gemini Response", code: 1, userInfo: nil)
            }
            
            // Parse the JSON string into our QuestionItem
            let jsonData = Data(firstPart.text.utf8)
            let questionItem = try JSONDecoder().decode(QuestionItem.self, from: jsonData)
            
            // Return the question string
            return questionItem.question
        } catch {
            print("Gemini API call failed: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Gemini API Models
struct GeminiRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct GenerationConfig: Codable {
        let responseMimeType: String
        let responseSchema: ResponseSchema
    }
    
    struct ResponseSchema: Codable {
        let type: String
        let properties: [String: PropertyDefinition]
        
        struct PropertyDefinition: Codable {
            let type: String
        }
    }
}

struct GeminiResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
        }
        
        struct Part: Codable {
            let text: String
        }
    }
}

// MARK: - Question Response Model
struct QuestionItem: Codable {
    let question: String
}

