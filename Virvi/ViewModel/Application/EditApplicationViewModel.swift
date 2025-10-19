//
//  EditApplicationViewModel.swift
//  Virvi
//
//  Created by Ethan Zhang on 4/10/2025.
//
import SwiftUI
import FirebaseFirestore


/// This viewModel handles the editing and adding of a ``Application`` and its associated collectinon of ``ApplicationStage``
@MainActor
class EditApplicationViewModel: ObservableObject {
    // MARK: - Published variables
    // Application form data
    @Published var role: String
    @Published var company: String
    @Published var date: Date
    @Published var status: ApplicationStatus
    @Published var starred: Bool
    @Published var note: String
    
    /// Array of ``ApplicationStage`` for the application
    @Published var stages: [ApplicationStage] = []
    /// Published array of deleted stage ID's
    @Published var deletedStageIds: [String] = []
    /// Published array of newly added stage ID's
    @Published var newlyAddedStageIds: Set<String> = []
    
    /// Published boolean for wether to show stage form section in ``EditApplicationView``
    @Published var showingStageSection = false
    /// Boolean for whether editing appliucation is new or existing
    @Published var isEditingExistingStage = false
    /// Temp stage when adding a new stage
    @Published var tempStage = ApplicationStage(
        id: nil,
        stage: StageType.applied,
        status: StageStatus.inProgress,
        date: Date().toDateString(),
        note: "",
        sortOrder: 0
    )
    
    // UI state
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    
    let repository: ApplicationRepository
    let userId: String
    let applicationId: String?
    let isNewApplication: Bool
    
    var statuses: [ApplicationStatus] { ApplicationStatus.allCases }
    var stageTypes: [StageType] { StageType.allCases }
    var stageStatuses: [StageStatus] { StageStatus.allCases }
    
    /// Constructor that initialises a editing application sheet with values to fill with
    /// - Parameters:
    ///   - applicationWithStages: Array of ``ApplicationWithStages`` to prepopulate form
    ///   - userId: User ID
    ///   - repository: Firestore repository to dependency inject
    init(
        applicationWithStages: ApplicationWithStages?,
        userId: String,
        repository: ApplicationRepository = FirestoreApplicationRepository()
    ) {
        self.repository = repository
        self.userId = userId
        self.isNewApplication = applicationWithStages == nil
        
        if let appWithStages = applicationWithStages {
            self.applicationId = appWithStages.application.id
            self.role = appWithStages.application.role
            self.company = appWithStages.application.company
            self.date = appWithStages.application.date.toDate() ?? Date()
            self.status = appWithStages.application.status
            self.starred = appWithStages.application.starred
            self.note = appWithStages.application.note
            self.stages = appWithStages.stages.sorted(by: { $0.sortOrder < $1.sortOrder })
        } else {
            self.applicationId = nil
            self.role = ""
            self.company = ""
            self.date = Date()
            self.status = .applied
            self.starred = false
            self.note = ""
        }
    }
    
    /// Boolean variable that checks if the role and company fields in ``EditApplicationView`` have values
    var isFormValid: Bool {
        !role.trimmingCharacters(in: .whitespaces).isEmpty &&
        !company.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - Application Editing Actions
    
    /// Initialise a new stage, with default stages and status using ``getDefaultStageAndStatus()``
    func showAddStageSection() {
        let (defaultStage, defaultStatus) = getDefaultStageAndStatus()
        // Temp stage to edit
        tempStage = ApplicationStage(
            id: nil,
            stage: defaultStage,
            status: defaultStatus,
            date: Date().toDateString(),
            note: "",
            sortOrder: stages.count
        )
        isEditingExistingStage = false
        showingStageSection = true
    }
    
    func editStage(_ stage: ApplicationStage) {
        tempStage = stage
        isEditingExistingStage = true
        showingStageSection = true
    }
    // MARK: - Add/Update Stage
    /// Called when user saves application and copies temp values to actual values
    func addOrUpdateStage() {
        if isEditingExistingStage {
            // Update existing stage
            if let index = stages.firstIndex(where: { $0.id == tempStage.id }) {
                stages[index] = tempStage
            }
        } else {
            // Add new stage
            var newStage = tempStage
            let stageId = UUID().uuidString
            newStage.id = stageId
            newStage.sortOrder = stages.count
            stages.append(newStage)
            newlyAddedStageIds.insert(stageId)  // Track as newly added
        }
        cancelStageEdit()
    }
    
    /// This function is called when the sheet is exited and resets internal values
    func cancelStageEdit() {
        showingStageSection = false
        isEditingExistingStage = false
        tempStage = ApplicationStage(
            id: nil,
            stage: StageType.applied,
            status: StageStatus.inProgress,
            date: Date().toDateString(),
            note: "",
            sortOrder: 0
        )
    }
    
    /// This function is called when user deletes a stage in ``EditApplicationView``
    /// - Parameter offsets: List of deleted indexes
    func deleteStages(at offsets: IndexSet) {
        // Track IDs of stages being deleted to deletedStageIds var
        for offset in offsets {
            if let stageId = stages[offset].id, !stageId.isEmpty {
                deletedStageIds.append(stageId)
            }
        }
        
        stages.remove(atOffsets: offsets)
        // Update sort order
        for (index, _) in stages.enumerated() {
            stages[index].sortOrder = index
        }
    }
    /// Async function to delete editing ``Application``
    func deleteApplication() async {
        guard let appId = applicationId else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Use repository deleteApplication method for the application
            try await repository.deleteApplication(id: appId, for: userId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    // MARK: - Save Application
    /// Async function that is called when application is saved/form submitted
    /// - Returns: Returns boolean determining if successful
    func saveApplication() async -> Bool {
        guard isFormValid else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create application from filled values in form
            let application = Application(
                id: applicationId,
                role: role.trimmingCharacters(in: .whitespaces),
                company: company.trimmingCharacters(in: .whitespaces),
                date: date.toDateString(),
                status: status,
                starred: starred,
                note: note.trimmingCharacters(in: .whitespaces)
            )
            
            if isNewApplication {
                // Use repo to create application using newly created struct
                let newId = try await repository.createApplication(application, for: userId)
                
                // Create all stages
                for stage in stages {
                    var newStage = stage
                    newStage.id = nil
                    _ = try await repository.createStage(newStage, for: newId, userId: userId)
                }
            } else {
                // Update application if existing application
                try await repository.updateApplication(application, for: userId)
                // Ensure appId is valid
                guard let appId = applicationId else {
                    errorMessage = "Application ID not found"
                    isLoading = false
                    return false
                }
                // Delete stages in deletedStageIds array
                for stageId in deletedStageIds {
                    try await repository.deleteStage(id: stageId, for: appId, userId: userId)
                }
                
                // For each stage, either create or update
                for stage in stages {
                    if let stageId = stage.id, newlyAddedStageIds.contains(stageId) {
                        // New stage: create it
                        var newStage = stage
                        newStage.id = nil
                        _ = try await repository.createStage(newStage, for: appId, userId: userId)
                    } else if stage.id != nil && !stage.id!.isEmpty {
                        // Existing stage: update it
                        try await repository.updateStage(stage, for: appId, userId: userId)
                    }
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
    
    /// Handles setting default stage and status for ``ApplicationStage``
    /// - Returns: The logical next ``StageStatus`` and ``StageType`` as tuple
    func getDefaultStageAndStatus() -> (stage: StageType, status: StageStatus) {
        if stages.isEmpty {
            return (.applied, .complete)
        }
        
        // Get the most recent stage
        guard let mostRecentStage = stages.max(by: { $0.sortOrder < $1.sortOrder }) else {
            return (.applied, .complete)
        }
        
        // Determine next logical stage based on most recent one
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
            // Already at final stage
            return (.offer, .complete)
        case .rejected:
            // No next stage after rejection
            return (.rejected, .complete)
        }
    }

}
