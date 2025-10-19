//
//  ApplicationsListViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 4/10/2025.
//

import SwiftUI
import FirebaseFirestore

/// This viewModel manages the list of job applications with filtering and status updates.
@MainActor
class ApplicationsListViewModel: ObservableObject {
    // MARK: - Published Variables
    /// All applications with they stages fetched from the repository stored in ``ApplicationWithStages``
    @Published var applications: [ApplicationWithStages] = []
    /// Applications after applying current filters.
    @Published var filteredApplications: [ApplicationWithStages] = []
    /// Search bar text to filter on
    @Published var searchText = ""
    @Published var selectedStatusFilter: ApplicationStatus?
    /// Boolean to check if starred filter is toggled
    @Published var showStarredOnly = false
    /// Loading bool for UI
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// The currently expanded application ID for detail view.
    @Published var expandedApplicationId: String?
    
    /// Selected application to pass to ``EditApplicationView``
    @Published var selectedApplicationToEdit: ApplicationWithStages?
    /// Repository for firestore database operations
    let repository: ApplicationRepository
    
    /// ``ApplicationStatus`` enums
    var statuses: [ApplicationStatus] { ApplicationStatus.allCases }
    
    // MARK: - Constructor
    /// Contructor that takes in dependency injections
    /// - Parameter repository: Firestore Repository
    init(repository: ApplicationRepository = FirestoreApplicationRepository()) {
        self.repository = repository
    }
    /// Fetches all applications for the specified user, enables isLoading state for loading
    /// - Parameter userId: User ID to fetch for
    func loadApplications(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            applications = try await repository.fetchApplications(for: userId)
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    /// Calls ``loadApplications(userId:)``
    func refreshApplications(userId: String) async {
        await loadApplications(userId: userId)
    }
    
    /// Delete an ``Application`` specified by its ``Application/id``
    /// - Parameters:
    ///   - id: ``Application/id`` of ``Application``
    ///   - userId: Takes a ``AppUser/id``
    func deleteApplication(id: String, userId: String) async {
        do {
            try await repository.deleteApplication(id: id, for: userId)
            applications.removeAll { $0.id == id }
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    /// Toggle the starred of an application
    ///
    /// - Parameters:
    ///   - applicationId: ID of application to star
    ///   - userId: user ID
    func toggleStar(applicationId: String, userId: String) async {
        do {
            try await repository.toggleStar(applicationId: applicationId, for: userId)
            
            // Update local state
            if let index = applications.firstIndex(where: { $0.id == applicationId }) {
                applications[index].application.starred.toggle()
                applyFilters()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    
    func applyFilters() {
        var filtered = applications
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { app in
                app.application.company.localizedCaseInsensitiveContains(searchText) ||
                app.application.role.localizedCaseInsensitiveContains(searchText) ||
                app.application.note.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Status filter
        if let status = selectedStatusFilter {
            filtered = filtered.filter { $0.application.status == status }
        }
        
        // Starred filter
        if showStarredOnly {
            filtered = filtered.filter { $0.application.starred }
        }
        
        filteredApplications = filtered
    }
    
    /// Handles changing and disabling of status filter by accepting a  ``ApplicationStatus``
    /// Input is compared to ``selectedStatusFilter``, and then set to nil if user is clicking to disable
    /// - Parameter status: ``ApplicationStatus``
    func toggleStatusFilter(_ status: ApplicationStatus) {
        if selectedStatusFilter == status {
            selectedStatusFilter = nil
        } else {
            selectedStatusFilter = status
            showStarredOnly = false
        }
        applyFilters()
    }
    
    /// Enable or disable star filter
    func toggleStarredFilter() {
        showStarredOnly.toggle()
        if showStarredOnly {
            selectedStatusFilter = nil
        }
        applyFilters()
    }
    
    /// Enable or disable expanded state of ``ApplicationRowView``
    /// - Parameter applicationId: Selected application ID
    func toggleExpansion(for applicationId: String?) {
        if expandedApplicationId == applicationId {
            expandedApplicationId = nil
        } else {
            expandedApplicationId = applicationId
        }
    }
    
    /// Async function to change the ``ApplicationStatus`` of a ``Application``
    /// - Parameters:
    ///   - applicationId: ID of application to change
    ///   - newStatus: ``ApplicationStatus`` to change to
    ///   - userId: User ID
    func updateStatus(applicationId: String, to newStatus: ApplicationStatus, userId: String) async {
        do {
            // Locate the updating application in VM application array
            guard let index = applications.firstIndex(where: { $0.id == applicationId }) else {
                errorMessage = "Application not found"
                return
            }
            
            // Update the application object
            var updatedApp = applications[index].application
            updatedApp.status = newStatus
            
            // Update in Firestore
            try await repository.updateApplication(updatedApp, for: userId)
            
            // Update local state
            applications[index].application.status = newStatus
            applyFilters()
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Status Change
    /// Function that returns the logical next status based off current ``ApplicationStatus``
    /// - Parameter current: Current ``ApplicationStatus``
    /// - Returns: Logical next ``ApplicationStatus``, with a maximum status of ``ApplicationStatus/rejected``
    func getNextStatus(current: ApplicationStatus) -> ApplicationStatus {
        guard let currentIndex = statuses.firstIndex(of: current) else {
            return current
        }
        
        // Dont go past the last status (Rejected)
        if currentIndex < statuses.count - 1 {
            return statuses[currentIndex + 1]
        }
        
        return current.next() ?? current
    }
    
    /// Function that return the local previous status based off current ``ApplicationStatus``
    /// - Parameter current: Current ``ApplicationStatus``
    /// - Returns: Logical previous ``ApplicationStatus``, with a minumum status of ``ApplicationStatus/notApplied``
    func getPreviousStatus(current: ApplicationStatus) -> ApplicationStatus {
        guard let currentIndex = statuses.firstIndex(of: current) else {
            return current.previous() ?? current
        }
        
        // Don't go before the first status (Not Applied)
        if currentIndex > 0 {
            return statuses[currentIndex - 1]
        }
        
        return current
    }
}
