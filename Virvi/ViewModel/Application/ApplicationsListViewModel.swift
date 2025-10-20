//
//  ApplicationsListViewModel.swift
//  Virvi
//

import SwiftUI

/// ViewModel for managing the list of job applications
@MainActor
class ApplicationsListViewModel: ObservableObject {
    @Published var applications: [ApplicationWithStages] = []
    @Published var filteredApplications: [ApplicationWithStages] = []
    @Published var searchText = ""
    @Published var selectedStatusFilter: ApplicationStatus?
    @Published var showStarredOnly = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var expandedApplicationId: String?
    @Published var selectedApplicationToEdit: ApplicationWithStages?
    
    let repository: ApplicationRepository
    var statuses: [ApplicationStatus] { ApplicationStatus.allCases }
    
    init(repository: ApplicationRepository) {
        self.repository = repository
    }
    
    func loadApplications() async {
        isLoading = true
        errorMessage = nil
        
        do {
            applications = try await repository.fetchApplications()
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func refreshApplications() async {
        await loadApplications()
    }
    
    func deleteApplication(_ application: SDApplication) async {
        do {
            try await repository.deleteApplication(application)
            applications.removeAll { $0.id == application.id }
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleStar(_ application: SDApplication) async {
        do {
            try await repository.toggleStar(application)
            applyFilters()
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
    
    func toggleStatusFilter(_ status: ApplicationStatus) {
        if selectedStatusFilter == status {
            selectedStatusFilter = nil
        } else {
            selectedStatusFilter = status
            showStarredOnly = false
        }
        applyFilters()
    }
    
    func toggleStarredFilter() {
        showStarredOnly.toggle()
        if showStarredOnly {
            selectedStatusFilter = nil
        }
        applyFilters()
    }
    
    func toggleExpansion(for applicationId: String?) {
        if expandedApplicationId == applicationId {
            expandedApplicationId = nil
        } else {
            expandedApplicationId = applicationId
        }
    }
    
    func updateStatus(application: SDApplication, to newStatus: ApplicationStatus) async {
        do {
            application.status = newStatus
            try await repository.updateApplication(application)
            applyFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func getNextStatus(current: ApplicationStatus) -> ApplicationStatus {
        guard let currentIndex = statuses.firstIndex(of: current) else {
            return current
        }
        
        if currentIndex < statuses.count - 1 {
            return statuses[currentIndex + 1]
        }
        
        return current
    }
    
    func getPreviousStatus(current: ApplicationStatus) -> ApplicationStatus {
        guard let currentIndex = statuses.firstIndex(of: current) else {
            return current
        }
        
        if currentIndex > 0 {
            return statuses[currentIndex - 1]
        }
        
        return current
    }
}
