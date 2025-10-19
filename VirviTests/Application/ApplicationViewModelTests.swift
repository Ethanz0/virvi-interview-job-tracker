//
//  ApplicationViewModelTests.swift
//  VirviTests
//
//  Created by Ethan Zhang on 11/10/2025.
//

import Testing
@testable import Virvi

@MainActor
@Suite struct ApplicationViewModelTests {
    
    var viewModel: ApplicationsListViewModel
    var mockRepository: MockApplicationRepository
    
    // Initiallise mock and viewmodel
    init() throws {
        mockRepository = MockApplicationRepository()
        viewModel = ApplicationsListViewModel(repository: mockRepository)
    }
    
    @Test("Company name filter")
     func searchFilterCompany() {
         viewModel.applications = [
             //Apple
             ApplicationTestData.applicationWithNoStages,
             // Google
             ApplicationTestData.earlyStageApplication
         ]
         
         // Search apple and apply filter
         viewModel.searchText = "Apple"
         viewModel.applyFilters()
         
         // Expect only one result with application company apple
         #expect(viewModel.filteredApplications.count == 1)
         #expect(viewModel.filteredApplications.first?.application.company == "Apple")
    }
    
    @Test("Empty view model when no data is in db")
    func loadEmptypplications() async {
        await viewModel.loadApplications(userId: "test-user")
        
        // There should be no errors and applications because we didnt put any
        #expect(viewModel.applications.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }
    
    @Test("Load applications from db")
    func loadApplications() async {
        // Setup mock data
        mockRepository.applications = [
            ApplicationTestData.applicationWithNoStages,
            ApplicationTestData.earlyStageApplication,
            ApplicationTestData.fullProgressApplication
        ]
        
        await viewModel.loadApplications(userId: "test-user")
        
        // Should see 3 applications
        #expect(viewModel.applications.count == 3)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("Update status with invalid ID sets error")
    func updateStatusInvalidId() async {
        // No applications initially
        mockRepository.applications = []
        await viewModel.loadApplications(userId: "test-user")
        
        // Try to update application (when none exist)
        await viewModel.updateStatus(
            applicationId: "invalid-id",
            to: .interview,
            userId: "test-user"
        )
        
        // Error message should appear
        #expect(viewModel.errorMessage == "Application not found")
    }
    
    @Test("Getting next status is capped at rejected and does not access out of bounds")
    func getNextStatusCapped() {
        // Call next status function with applicationstatus offer
        let nextStatus = viewModel.getNextStatus(current: ApplicationStatus.offer)
        // Expect nextstatus to return with rejected
        #expect(nextStatus == ApplicationStatus.rejected)
        
        // Call getnextstatus again with rejected status
        let finalStatus = viewModel.getNextStatus(current: nextStatus)
        // Expect rejected status again
        #expect(finalStatus == ApplicationStatus.rejected)
        
    }
    
}
