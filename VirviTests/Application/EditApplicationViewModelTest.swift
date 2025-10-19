//
//  EditApplicationViewModelTest.swift
//  VirviTests
//
//  Created by Ethan Zhang on 11/10/2025.
//

import Testing
@testable import Virvi

@MainActor
@Suite struct EditApplicationViewModelTest {
    
    var mockRepository: MockApplicationRepository
    
    // Mock repository instead of firestore
    init() throws {
        mockRepository = MockApplicationRepository()
    }
    
    @Test("Initialize new application with empty fields")
    func initializeNewApplication() {
        // Start the viewmodel with nothing (meaning new application)
        let viewModel = EditApplicationViewModel(
            applicationWithStages: nil,
            userId: "testUserId",
            repository: mockRepository
        )
        // Expect defaults in form fields
        #expect(viewModel.isNewApplication == true)
        #expect(viewModel.role.isEmpty)
        #expect(viewModel.company.isEmpty)
        #expect(viewModel.status == .applied)
        #expect(viewModel.starred == false)
        #expect(viewModel.stages.isEmpty)
    }
    
    @Test("Existing application populates form fields")
    func initializeExistingApplication() {
        // Application with stages
        let appWithStages = ApplicationTestData.fullProgressApplication
        
        // Start viewmodel with this application with stages
        let viewModel = EditApplicationViewModel(
            applicationWithStages: appWithStages,
            userId: "testUserId",
            repository: mockRepository
        )
        // Expect the form to be loaded with same values
        #expect(viewModel.isNewApplication == false)
        #expect(viewModel.role == appWithStages.application.role)
        #expect(viewModel.company == appWithStages.application.company)
        #expect(viewModel.status == appWithStages.application.status)
        #expect(viewModel.starred == appWithStages.application.starred)
        #expect(viewModel.stages.count == appWithStages.stages.count)
    }
    
    @Test("Save with invalid form")
    func saveInvalidForm() async {
        // Start application with nothing (meaning new application)
        let viewModel = EditApplicationViewModel(
            applicationWithStages: nil,
            userId: "testUserId",
            repository: mockRepository
        )
        
        // Fill the role and company fields with empty strings
        viewModel.role = ""
        viewModel.company = ""
        
        let success = await viewModel.saveApplication()
        
        // Expect false success and mock repository to still be empty
        #expect(success == false)
        #expect(mockRepository.applications.isEmpty)
    }
    @Test("Save existing application")
     func saveExistingApplication() async {
         let appWithStages = ApplicationTestData.applicationWithNoStages
         mockRepository.applications = [appWithStages]
         
         let viewModel = EditApplicationViewModel(
             applicationWithStages: appWithStages,
             userId: "testUserId",
             repository: mockRepository
         )
         // Fill form role field with updated role
         viewModel.role = "Updated Role"
         
         let success = await viewModel.saveApplication()
         
         // Expect repository to now have this new update
         #expect(success == true)
         #expect(mockRepository.applications[0].application.role == "Updated Role")
     }
     
}
