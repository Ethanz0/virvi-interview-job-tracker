//
//  EditApplicationView.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//


import SwiftUI

struct EditApplicationView: View {
    @StateObject var viewModel: EditApplicationViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(
        applicationWithStages: ApplicationWithStages?,
        repository: ApplicationRepository
    ) {
        _viewModel = StateObject(wrappedValue: EditApplicationViewModel(
            applicationWithStages: applicationWithStages,
            repository: repository
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                jobDetailsSection
                stagesSection
                notesSection
                deleteButton
            }
            .navigationTitle(viewModel.isNewApplication ? "New Application" : "Edit Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        print("application save button pressed")
                        Task {
                            let success = await viewModel.saveApplication()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isLoading)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Job Details Section
    
    private var jobDetailsSection: some View {
        Section("Job Details") {
            TextField("Job Role", text: $viewModel.role)
                .textInputAutocapitalization(.words)
            
            TextField("Company", text: $viewModel.company)
                .textInputAutocapitalization(.words)
            
            DatePicker("Date Applied", selection: $viewModel.date, displayedComponents: .date)
            
            Picker("Status", selection: $viewModel.status) {
                ForEach(viewModel.statuses, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
        }
    }
    
    // MARK: - Stages Section
    
    private var stagesSection: some View {
        Group {
            Section("Stages") {
                if viewModel.stages.isEmpty {
                    Text("No stages added yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.stages.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { stage in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(stage.stage.rawValue)
                                    .foregroundColor(.primary)
                                Text(stage.status.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(stage.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.editStage(stage)
                        }
                    }
                    .onDelete { offsets in
                        Task{
                            await viewModel.deleteStages(at: offsets)

                        }
                    }
                }
            }
            
            // MARK: - Add/Edit Stage Section
            
            if viewModel.showingStageSection {
                Section(viewModel.isEditingExistingStage ? "Edit Stage" : "Add New Stage") {
                    Picker("Stage", selection: $viewModel.tempStageData.stage) {
                        ForEach(viewModel.stageTypes, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Status", selection: $viewModel.tempStageData.status) {
                        ForEach(viewModel.stageStatuses, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    
                    DatePicker("Date", selection: $viewModel.tempStageData.date, displayedComponents: .date)
                    
                    TextField("Additional notes (optional)", text: $viewModel.tempStageData.note)
                    
                    HStack {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.red)
                        .onTapGesture {
                            viewModel.cancelStageEdit()
                        }
                        
                        HStack {
                            Image(systemName: viewModel.isEditingExistingStage ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(viewModel.isEditingExistingStage ? "Update Stage" : "Add Stage")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.green)
                        .onTapGesture {
                            viewModel.addOrUpdateStage()
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
            } else {
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
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section("Additional Notes") {
            TextField("Notes (optional)", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Delete Button
    
    @ViewBuilder
    private var deleteButton: some View {
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
}
