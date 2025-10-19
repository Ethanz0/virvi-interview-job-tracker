//
//  TestData.swift
//  Virvi
//
//  Created by Ethan Zhang on 11/10/2025.
//

import SwiftUI
import Foundation

enum InterviewTestData {
    static var emptyInterview: Interview {
        Interview(
            title: "iOS Developer Position",
            duration: 30
        )
    }
    
    static var behavioralInterview: Interview {
        Interview(
            title: "Behavioral Interview",
            duration: 45,
            questions: [
                Question(question: "Tell me about yourself", order: 0),
                Question(question: "What's your greatest strength?", order: 1),
                Question(question: "Describe a challenging project", order: 2)
            ]
        )
    }
    
    
    static var completedInterview: Interview {
        let interview = Interview(
            title: "Junior Developer Role",
            duration: 30,
            questions: [
                Question(question: "What is your experience with Swift?", order: 0),
                Question(question: "Explain MVC vs MVVM", order: 1)
            ],
            completed: true
        )
        interview.completionDate = Date()
        return interview
    }
    
    static var uncompleteInterview: Interview {
        let interview = Interview(
            title: "Junior Developer Role",
            duration: 30,
            questions: [
                Question(question: "What is your experience with Swift?", order: 0),
                Question(question: "Explain MVC vs MVVM", order: 1)
            ],
            completed: false
        )
        return interview
    }
    
    static var technicalInterview: Interview {
        Interview(
            title: "Technical Screening",
            duration: 90,
            questions: [
                Question(question: "Reverse a linked list", order: 0),
                Question(question: "Find duplicates in an array", order: 1),
                Question(question: "Implement a binary search", order: 2)
            ],
            additionalContext: "Focus on data structures and algorithms. Candidate has 5 years experience.",
            maxQuestions: 5
        )
    }
    
    static var interviewWithAnswers: Interview {
        let question = Question(question: "Why do you want this job?", order: 0)
        question.transcript = "I'm passionate about iOS development and love working with SwiftUI..."
        question.recordingPath = "/recordings/question-1.m4a"
        
        return Interview(
            title: "Mock Interview Session",
            duration: 45,
            questions: [question]
        )
    }
}
