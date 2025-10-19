//
//  EditApplicationView.swift
//  Virvi
//
//  Created by Ethan Zhang on 3/10/2025.
//


import SwiftUI
import FirebaseFirestore


// MARK: - Edit Application View
/// A form view for creating and editing a ``Application`` and a corresponding list of ``ApplicationStage``.
///
/// ## Features
/// - Job details editing
/// - Stage details editing
/// - Intelligent stage progression defaults
/// - Role and Company must have values to submit
struct EditApplicationView: View {
    /// The authenticated user's view model, injected via environment.
    @EnvironmentObject var auth: AuthViewModel
    
    /// The view model managing application data and business logic.
    @StateObject var viewModel: EditApplicationViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Constructors
    /// Creates a new application form for the specified user.
    ///
    /// - Parameters:
    ///   - userId: The unique identifier of the user creating the application
    ///   - repository: The repository for dealing with application data, defaults to FireStore
    init(userId: String, repository: ApplicationRepository = FirestoreApplicationRepository()) {
        _viewModel = StateObject(wrappedValue: EditApplicationViewModel(
            applicationWithStages: nil,
            userId: userId,
            repository: repository
        ))
    }
    /// Creates an edit form for an existing application.
    ///
    /// - Parameters:
    ///   - applicationWithStages: The existing application to edit, including all stages
    ///   - userId: The unique identifier of the user who owns this application
    ///   - repository: The repository for dealing with application data. Defaults to FireStore
    init(
        applicationWithStages: ApplicationWithStages,
        userId: String,
        repository: ApplicationRepository = FirestoreApplicationRepository()
    ) {
        _viewModel = StateObject(wrappedValue: EditApplicationViewModel(
            applicationWithStages: applicationWithStages,
            userId: userId,
            repository: repository
        ))
    }
    
    var body: some View {
        NavigationStack {
            // MARK: - Form Items
            Form {
                jobDetailsSection
                stagesSection
                notesSection
                deleteButton
            }
            .navigationTitle(viewModel.applicationId == nil ? "New Application" : "Edit Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Cancel button
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    // Save button
                    Button("Save") {
                        Task {
                            let success = await viewModel.saveApplication()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    // Prevent saving if company and role not filled
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)
            // Loading, if application being saved
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            
        }
    }

    // MARK: - Job Details Sections
    private var jobDetailsSection: some View {
        Section("Job Details") {
            // Role
            TextField("Job Role", text: $viewModel.role)
                .textInputAutocapitalization(.words)
            // Company
            TextField("Company", text: $viewModel.company)
                .textInputAutocapitalization(.words)
            // Date picker
            DatePicker("Date Applied", selection: $viewModel.date, displayedComponents: .date)
            // Status of application
            Picker("Status", selection: $viewModel.status) {
                ForEach(viewModel.statuses, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            
        }
    }
    // MARK: - Stage Section
    private var stagesSection: some View {
        Group {
            // Existing stages list
            Section("Stages") {
                if viewModel.stages.isEmpty {
                    Text("No stages added yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    // Sort stages by sortOrder attribute
                    ForEach(viewModel.stages.sorted(by: { $0.sortOrder < $1.sortOrder })) { stage in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stage.stage.rawValue)
                                    .foregroundColor(.primary)
                                Text(stage.status.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatDate(stage.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        // Edit stage if tapped
                        .onTapGesture {
                            viewModel.editStage(stage)
                        }
                    }
                    // Delete stage
                    .onDelete { offsets in
                        viewModel.deleteStages(at: offsets)
                    }
                }
            }
            
            // MARK: - Add/Edit stage section
            if viewModel.showingStageSection {
                // Main form details
                Section(viewModel.isEditingExistingStage ? "Edit Stage" : "Add New Stage") {
                    // Update tempStage in vm for stage
                    Picker("Stage", selection: $viewModel.tempStage.stage) {
                        ForEach(viewModel.stageTypes, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    // Update tempStage in vm for status
                    Picker("Status", selection: $viewModel.tempStage.status) {
                        ForEach(viewModel.stageStatuses, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    // Update date
                    DatePicker("Date", selection: Binding(
                        get: { viewModel.tempStage.date.toDate() ?? Date() },
                        set: { viewModel.tempStage.date = $0.toDateString() }
                    ), displayedComponents: .date)
                    
                    // Additional notes
                    TextField("Additional notes (optional)", text: $viewModel.tempStage.note)
                    
                    HStack {
                        // Cancel editing/add stage
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.red)
                        .onTapGesture(){
                            viewModel.cancelStageEdit()
                        }
                        // Save stage
                        HStack {
                            Image(systemName: viewModel.isEditingExistingStage ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(viewModel.isEditingExistingStage ? "Update Stage" : "Add Stage")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.green)
                        .onTapGesture(){
                            viewModel.addOrUpdateStage()
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
            } else {
                // Add new stage button
                Section {
                    Button {
                        viewModel.showAddStageSection()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Stage")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.blue)
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 12)
                }
            }
        }
    }
    // View builder needed because using if statement outside
    @ViewBuilder
    private var deleteButton: some View {
        // Delete button for existing applications
        if !viewModel.isNewApplication {
            Section {
                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteApplication()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Delete Application")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
    }
    // Additional Notes
    private var notesSection: some View {
        Section("Additional Notes") {
            TextField("Notes (optional)", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    private func formatDate(_ dateString: String) -> String {
        guard let date = dateString.toDate() else { return dateString }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("New Application") {
    EditApplicationView(userId: "preview-user", repository: MockApplicationRepository())
        .environmentObject(AuthViewModel())
}

