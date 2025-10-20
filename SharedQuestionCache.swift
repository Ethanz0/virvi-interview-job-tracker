
//
//  SharedQuestionCache.swift
//  Shared between Main App and Widget
//
//  Add this file to BOTH targets (Main App + Widget Extension)
//

import Foundation
import WidgetKit

class SharedQuestionCache {
    private static let appGroupID = "group.com.virvi.app"
    
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    // Keys for storage
    private enum Keys {
        static let dailyQuestion = "dailyQuestion"
        static let questionDate = "questionDate"
    }
    
    // MARK: - Save Question (Main App Only)
    
    /// Save today's question to shared storage
    static func saveDailyQuestion(_ question: String) {
        sharedDefaults?.set(question, forKey: Keys.dailyQuestion)
        sharedDefaults?.set(Date(), forKey: Keys.questionDate)
        
        // Tell all widgets to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Read Question (Widget + Main App)
    
    /// Get the cached daily question
    static func getDailyQuestion() -> String? {
        return sharedDefaults?.string(forKey: Keys.dailyQuestion)
    }
    
    /// Get when the question was last updated
    static func getQuestionDate() -> Date? {
        return sharedDefaults?.object(forKey: Keys.questionDate) as? Date
    }
    
    /// Check if we need a new question (older than 24 hours)
    static func needsNewQuestion() -> Bool {
        guard let lastUpdate = getQuestionDate() else {
            return true
        }
        
        let hoursSinceUpdate = Date().timeIntervalSince(lastUpdate) / 3600
        return hoursSinceUpdate >= 24
    }
}
