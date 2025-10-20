//
//  QuestionUpdateService.swift
//  Virvi
//
//  Created by Ethan Zhang on 20/10/2025.
//


class QuestionUpdateService {
    private let geminiService = GeminiService()
    
    func updateDailyQuestion() async {
        do {
            let question = try await geminiService.generateQuestionOfTheDay()
            
            // Save to shared cache
            SharedQuestionCache.saveDailyQuestion(question)
            
            print("Daily question updated: \(question)")
        } catch {
            print("Failed to update daily question: \(error)")
        }
    }
    
    func updateQuestionIfNeeded() async {
        if SharedQuestionCache.needsNewQuestion() {
            await updateDailyQuestion()
        }
    }
}
