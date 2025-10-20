//
//  EditApplicationViewModel.swift
//  Virvi
//

import SwiftUI

/// ViewModel for editing and creating applications
@MainActor
class EditApplicationViewModel: ObservableObject {
    // Application form data
    @Published var role: String
    @Published var company: String
    @Published var date: Date
    @Published var status: ApplicationStatus
    @Published var starred: Bool
    @Published var note: String
    
    // Stage management
    @Published var stages: [SDApplicationStage] = []
    @Published var stagesToDelete: [SDApplicationStage] = []
    
    @Published var showingStageSection = false
    @Published var isEditingExistingStage = false
    @Published var tempStageData: TempStageData = TempStageData()
    
    // UI state
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    
    let repository: ApplicationRepository
    let application: SDApplication?
    let isNewApplication: Bool
    
    var statuses: [ApplicationStatus] { ApplicationStatus.allCases }
    var stageTypes: [StageType] { StageType.allCases }
    var stageStatuses: [StageStatus] { StageStatus.allCases }
    
    // Temporary struct for stage editing (since we can't modify class properties directly in form)
    struct TempStageData {
        var stage: StageType = .applied
        var status: StageStatus = .inProgress
        var date: Date = Date()
        var note: String = ""
        var sortOrder: Int = 0
        var editingStage: SDApplicationStage?
    }
    
    init(
        applicationWithStages: ApplicationWithStages?,
        repository: ApplicationRepository
    ) {
        self.repository = repository
        self.application = applicationWithStages?.application
        self.isNewApplication = applicationWithStages == nil
        
        if let appWithStages = applicationWithStages {
            self.role = appWithStages.application.role
            self.company = appWithStages.application.company
            self.date = appWithStages.application.date
            self.status = appWithStages.application.status
            self.starred = appWithStages.application.starred
            self.note = appWithStages.application.note
            self.stages = appWithStages.stages.sorted(by: { $0.sortOrder < $1.sortOrder })
        } else {
            self.role = ""
            self.company = ""
            self.date = Date()
            self.status = .applied
            self.starred = false
            self.note = ""
        }
    }
    
    var isFormValid: Bool {
        !role.trimmingCharacters(in: .whitespaces).isEmpty &&
        !company.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Stage Management
    
    func showAddStageSection() {
        let (defaultStage, defaultStatus) = getDefaultStageAndStatus()
        tempStageData = TempStageData(
            stage: defaultStage,
            status: defaultStatus,
            date: Date(),
            note: "",
            sortOrder: stages.count,
            editingStage: nil
        )
        isEditingExistingStage = false
        showingStageSection = true
    }
    
    func editStage(_ stage: SDApplicationStage) {
        tempStageData = TempStageData(
            stage: stage.stage,
            status: stage.status,
            date: stage.date,
            note: stage.note,
            sortOrder: stage.sortOrder,
            editingStage: stage
        )
        isEditingExistingStage = true
        showingStageSection = true
    }
    
    func addOrUpdateStage() {
        if isEditingExistingStage, let editingStage = tempStageData.editingStage {
            // Update existing stage
            editingStage.stage = tempStageData.stage
            editingStage.status = tempStageData.status
            editingStage.date = tempStageData.date
            editingStage.note = tempStageData.note
            editingStage.sortOrder = tempStageData.sortOrder
        } else {
            // Create new stage (will be saved later)
            let newStage = SDApplicationStage(
                stageRawValue: tempStageData.stage.rawValue,
                statusRawValue: tempStageData.status.rawValue,
                date: tempStageData.date,
                note: tempStageData.note,
                sortOrder: stages.count,
                needsSync: true,
                isDeleted: false
            )
            stages.append(newStage)
        }
        cancelStageEdit()
    }
    
    func cancelStageEdit() {
        showingStageSection = false
        isEditingExistingStage = false
        tempStageData = TempStageData()
    }
    
    func deleteStages(at offsets: IndexSet) {
        for offset in offsets {
            let stage = stages[offset]
            // Only track for deletion if it has a firestoreId (exists in database)
            if stage.firestoreId != nil {
                stagesToDelete.append(stage)
            }
        }
        
        stages.remove(atOffsets: offsets)
        
        // Update sort order
        for (index, stage) in stages.enumerated() {
            stage.sortOrder = index
        }
    }
    
    // MARK: - Save/Delete Application
    
    func deleteApplication() async {
        guard let app = application else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await repository.deleteApplication(app)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func saveApplication() async -> Bool {
        guard isFormValid else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let savedApp: SDApplication
            
            if let existingApp = application {
                // Update existing application
                existingApp.role = role.trimmingCharacters(in: .whitespaces)
                existingApp.company = company.trimmingCharacters(in: .whitespaces)
                existingApp.date = date
                existingApp.status = status
                existingApp.starred = starred
                existingApp.note = note.trimmingCharacters(in: .whitespaces)
                
                try await repository.updateApplication(existingApp)
                savedApp = existingApp
                
                // Delete removed stages
                for stage in stagesToDelete {
                    try await repository.deleteStage(stage)
                }
                
                // Update or create stages
                for stage in stages {
                    if stage.firestoreId != nil || stage.application != nil {
                        // Existing stage - update
                        try await repository.updateStage(stage)
                    } else {
                        // New stage - create
                        let _ = try await repository.createStage(
                            for: savedApp,
                            stage: stage.stage,
                            status: stage.status,
                            date: stage.date,
                            note: stage.note,
                            sortOrder: stage.sortOrder
                        )
                    }
                }
            } else {
                // Create new application
                savedApp = try await repository.createApplication(
                    role: role.trimmingCharacters(in: .whitespaces),
                    company: company.trimmingCharacters(in: .whitespaces),
                    date: date,
                    status: status,
                    starred: starred,
                    note: note.trimmingCharacters(in: .whitespaces)
                )
                
                // Create all stages
                for stage in stages {
                    let _ = try await repository.createStage(
                        for: savedApp,
                        stage: stage.stage,
                        status: stage.status,
                        date: stage.date,
                        note: stage.note,
                        sortOrder: stage.sortOrder
                    )
                }
            }
            
            showSuccess = true
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Intelligent Stage Defaults
    
    func getDefaultStageAndStatus() -> (stage: StageType, status: StageStatus) {
        if stages.isEmpty {
            return (.applied, .complete)
        }
        
        guard let mostRecentStage = stages.max(by: { $0.sortOrder < $1.sortOrder }) else {
            return (.applied, .complete)
        }
        
        switch mostRecentStage.stage {
        case .applied:
            return (.onlineAssessment, .inProgress)
        case .onlineAssessment:
            return (.phoneScreening, .inProgress)
        case .phoneScreening:
            return (.virtualInterview, .inProgress)
        case .virtualInterview:
            return (.interview, .inProgress)
        case .assessmentCentre:
            return (.interview, .inProgress)
        case .interview:
            return (.awaitingOffer, .inProgress)
        case .awaitingOffer:
            return (.offer, .inProgress)
        case .offer:
            return (.offer, .complete)
        case .rejected:
            return (.rejected, .complete)
        }
    }
}
