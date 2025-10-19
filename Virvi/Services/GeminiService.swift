//
//  GeminiService.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftUI

/// This config enum returns values within the secrets.plist file
enum Config {
    private static let configDict: [String: Any] = {
        // Get path to Secrets.plist
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              // Load the dictionary
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            // Return empty dictionary dictionary if error
            return [:]
        }
        // Return dictionary
        return dict
    }()
    
    /// Returns the gemni api key
    static var geminiAPIKey: String {
        // Access the GEMINI_API_KEY in the dictionary
        configDict["GEMINI_API_KEY"] as? String ?? ""
    }
}


class GeminiService {
    
    /// Generate interview questions using gemni api
    /// - Parameters:
    ///   - title: Interview title
    ///   - prompt: Optional description of what the interview should contain
    ///   - count: number of questions
    ///   - duration: duration of interview question
    /// - Returns: Array of questions as strings
    func generateQuestions(title: String, prompt: String, count: Int = 5, duration: Int = 30) async throws -> [String] {
        
        // We can force unwrap here since we supplying the string
        let url = URL(string:"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent")!
        
        // Create the schema for questions array
        // We want to be returned an array of strings
        let responseSchema = GeminiRequest.ResponseSchema(
            type: "ARRAY",
            items: GeminiRequest.ResponseSchema.SchemaItem(
                type: "OBJECT",
                properties: [
                    "question": GeminiRequest.ResponseSchema.PropertyDefinition(
                        type: "STRING",
                    )
                ]
            )
        )
        
        // Prompt to be sent to gemini
        let fullPrompt = """
        Generate \(count) interview questions for a \(title) role that can be answered verbally on a phone in \(duration) seconds or less.

        - Keep questions clear and concise
        - Focus on experience and practical knowledge initially
        - No whiteboarding or coding required
        \(prompt.isEmpty ? "" : "\n\(prompt)")
        """
        
        // Create the request body and specify we want a json with the custmoised reponse schema
        // Array of prompts to supply, however we only need to provide the prompt string
        let requestBody = GeminiRequest(
            contents: [
                GeminiRequest.Content(
                    parts: [GeminiRequest.Part(text: fullPrompt)],
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
        
        do{
            // Make the request
            let (data, _) = try await URLSession.shared.data(for: request)
            // Decode response
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            // Extract text
            guard let firstCandidate = geminiResponse.candidates.first,
                  let firstPart = firstCandidate.content.parts.first else {
                throw NSError(domain: "Invalid Gemini Response", code: 1, userInfo: nil)
            }
            
            // Parse the JSON string into our QuestionItem array
            let jsonData = Data(firstPart.text.utf8)
            let questionItems = try JSONDecoder().decode([QuestionItem].self, from: jsonData)
            
            // Extract just the question strings
            return questionItems.map { $0.question }
        } catch {
            print("Gemini API call failed: \(error.localizedDescription)")
            return []
        }
    }
}
//{
//  "contents": [
//    {
//      "parts": [
//        {
//          "text": "Generate 5 interview questions..."
//        }
//      ]
//    }
//  ],
//  "generationConfig": {
//    "responseMimeType": "application/json",
//    "responseSchema": {
//      "type": "ARRAY",
//      "items": {
//        "type": "OBJECT",
//        "properties": {
//          "question": {
//            "type": "STRING"
//          }
//        }
//      }
//    }
//  }
//}
// MARK: - Gemini API Models
struct GeminiRequest: Codable {
    
    // Prompts to send
    let contents: [Content]
    // How gemini should generate responses such as format
    let generationConfig: GenerationConfig
    // Array of message parts, in our case we only need one string entry. Can also send image
    struct Content: Codable {
        let parts: [Part]
    }
    // We only need to send text

    struct Part: Codable {
        let text: String
    }
    
    struct GenerationConfig: Codable {
        // Format to return
        let responseMimeType: String
        // The exact json structure to return
        let responseSchema: ResponseSchema
    }
    
    struct ResponseSchema: Codable {
        // The root json type. In our case "ARRAY"
        let type: String
        // what is inside the array, in our case a question object
        let items: SchemaItem
        
        struct SchemaItem: Codable {
            // This object should have a string for the question
            let type: String
            let properties: [String: PropertyDefinition]
        }
        // the type of the question property
        struct PropertyDefinition: Codable {
            let type: String
        }
    }
}

struct GeminiResponse: Codable {
    // Responses from gemini
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        // The generated contnt
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
