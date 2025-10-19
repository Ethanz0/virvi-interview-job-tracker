//
//  CompletedInterviewsViewModelTests.swift
//  VirviTests
//
//  Created by Ethan Zhang on 11/10/2025.
//

import Testing
import SwiftData
@testable import Virvi


@MainActor
@Suite struct CompletedInterviewsViewModelTests {
    
    var viewModel: CompletedInterviewsViewModel
    var modelContext: ModelContext
    
    init() throws {
        let container = try ModelContainer(
            for: Interview.self, Question.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        modelContext = ModelContext(container)
        viewModel = CompletedInterviewsViewModel()
    }

    @Test("Initialising viewModel correctly loads interviews")
    func initialiseViewModel() async throws {
        // Insert interviews into modelContext
        modelContext.insert(InterviewTestData.completedInterview)
        
        #expect(viewModel.completedInterviews.isEmpty)

        viewModel.setup(modelContext: modelContext)
        
        // Interview list should have 1 interviews
        #expect(viewModel.completedInterviews.count == 1)

    }
    @Test("completedInterviews should be empty if a uncomplete interview is added")
    func uncompletedInterview() async throws {
        // Insert uncompleted interview into modelContext
        modelContext.insert(InterviewTestData.uncompleteInterview)
        
        #expect(viewModel.completedInterviews.isEmpty)

        viewModel.setup(modelContext: modelContext)
        
        // Interview list should have 0 interviews
        #expect(viewModel.completedInterviews.isEmpty)

    }
    
    @Test("Initialising viewModel when model context has no interviews")
    func emptyModelContext() async throws {
        // Setup viewmodel with nothing in modelcontext
        viewModel.setup(modelContext: modelContext)
        
        // Interview list should have 0 interviews
        #expect(viewModel.completedInterviews.isEmpty)
        // No errors should exist
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("Deleting an interview from the model context updates the view model")
    func deleteInterview() async throws {
        // Insert a interview
        modelContext.insert(InterviewTestData.completedInterview)
        
        // Setup interview
        viewModel.setup(modelContext: modelContext)
        
        // Delete a interview
        let interviewToDelete = viewModel.completedInterviews[0]
        viewModel.deleteInterview(interviewToDelete)
        
        // Expect completed interviews list to be empty
        #expect(viewModel.completedInterviews.isEmpty)
        #expect(viewModel.errorMessage == nil)
        
        let fetchDescriptor = FetchDescriptor<Interview>()
        let interviews = try modelContext.fetch(fetchDescriptor)
        
        // Expect there to be no interviews in model
        #expect(interviews.isEmpty)
    }

}
