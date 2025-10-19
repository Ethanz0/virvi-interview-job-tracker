//
//  VirviTests.swift
//  VirviTests
//
//  Created by Ethan Zhang on 11/10/2025.
//

import Testing
import SwiftData
@testable import Virvi


@MainActor
@Suite struct InterviewFormViewModelTests {
    
    var viewModel: InterviewFormViewModel
    var modelContext: ModelContext
    
    init() throws {
        let container = try ModelContainer(
            for: Interview.self, Question.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        modelContext = ModelContext(container)
        viewModel = InterviewFormViewModel()
        viewModel.setup(with: modelContext)
    }
    
    // Test state of viewmodel before and after running createInterview() with values inserted
    @Test func createInterviewManualMode() async throws {
        
        // Test published variables initially are default
        #expect(viewModel.interviewTitle == "")
        #expect(viewModel.duration == QuestionDuration.seconds30)
        #expect(viewModel.numQuestions == 3)
        #expect(viewModel.additionalNotes == "")
        #expect(viewModel.isGenerating == false)
        #expect(viewModel.showError == false)
        #expect(viewModel.errorMessage == "")
        #expect(viewModel.questionMode == QuestionMode.manual)
        
        // Update published values to simulate form being changed
        viewModel.interviewTitle = "Test Interview"
        viewModel.duration = QuestionDuration.minute1
        viewModel.questionMode = QuestionMode.manual
        
        let interview = await viewModel.createInterview()
        
        #expect(interview != nil)
        #expect(interview?.title == "Test Interview")
        #expect(interview?.duration == 60)
        #expect(interview?.completed == false)
        #expect(interview?.maxQuestions == nil)
        #expect(interview?.questions.isEmpty == true)
    }
    
    // Test api call to gemini generating questions
    @Test func createInterviewAI() async throws {
        
        // Test with 2 questions
        viewModel.interviewTitle = "Test Interview"
        viewModel.duration = QuestionDuration.minute1
        viewModel.numQuestions = 2
        viewModel.questionMode = QuestionMode.aiGenerated
        
        let interview = await viewModel.createInterview()
        
        // Expect 2 questions in question array
        #expect(interview != nil)
        #expect(interview?.questions.count == 2)
    }
}
