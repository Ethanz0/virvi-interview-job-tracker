//
//  ApplicationsListView.swift
//  Virvi
//
//  Created by Ethan Zhang on 3/10/2025.
//

import SwiftUI
import FirebaseFirestore

/// The main application view which displays a page with a list of ``ApplicationRowView``
/// Also has a scrollable filter bar which allows the user to filter based off ``StageType`` of each application
/// Includes functionality for edit a application and add a new application by displaying ``EditApplicationView``
struct ApplicationsListView: View {
    /// Environment Object for tracking userID to save changes to
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel: ApplicationsListViewModel
    @State private var showingAddSheet = false
    
    // MARK: - Constructor
    /// Contructor that dependency injects the firestore ``ApplicationRepository`` into the ``ApplicationsListViewModel``
    /// - Parameter repository: Repository to use for database operations, defaults to Firestore
    init(repository: ApplicationRepository = FirestoreApplicationRepository()) {
        _viewModel = StateObject(wrappedValue: ApplicationsListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter buttons
                filterButtonsSection
                
                // Show loading screen if applications are being loaded
                if viewModel.isLoading && viewModel.applications.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading applications...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Show help message if no applications
                } else if viewModel.filteredApplications.isEmpty {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer()
                                .frame(height: 100)
                            
                            Image(systemName: getEmptyStateIcon())
                                .font(.system(size: 60))
                                .foregroundStyle(viewModel.showStarredOnly ? .yellow.opacity(0.5) : .secondary)
                            
                            Text(getEmptyStateTitle())
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(getEmptyStateMessage())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            Spacer()
                                .frame(height: 200)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    // Show application list
                    applicationsList
                }
            }
            .navigationTitle("Job Applications")
            // Search Bar
            .searchable(text: $viewModel.searchText, prompt: "Search applications")
            // Apply filters on change of search bar text
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.applyFilters()
            }
            // Tool bar for adding a new application
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Sheet for new application
            .sheet(isPresented: $showingAddSheet) {
                EditApplicationView(userId: auth.user?.id ?? "", repository: viewModel.repository)
                // Update applications when sheet closed
                    .onDisappear {
                        Task {
                            await viewModel.refreshApplications(userId: auth.user?.id ?? "")
                        }
                    }
            }
            // Sheet for editing application
            .sheet(item: $viewModel.selectedApplicationToEdit) { app in
                EditApplicationView(
                    applicationWithStages: app,
                    userId: auth.user?.id ?? "",
                    repository: viewModel.repository
                )
                // Update applications when sheet closed
                .onDisappear {
                    viewModel.selectedApplicationToEdit = nil
                    Task {
                        await viewModel.refreshApplications(userId: auth.user?.id ?? "")
                    }
                }
            }
            // Initially, load applications
            .task {
                if viewModel.applications.isEmpty {
                    await viewModel.loadApplications(userId: auth.user?.id ?? "")
                }
            }
        }
    }
    
    // MARK: - Applications List
    private var applicationsList: some View {
        // Use list for simple UI, no arrow on right
        List {
            // Display each application with the applicationrowview
            ForEach(viewModel.filteredApplications) { appWithStages in
                ApplicationRowView(
                    viewModel: viewModel,
                    applicationWithStages: appWithStages,
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        // Allow refreshing
        .refreshable {
            await viewModel.refreshApplications(userId: auth.user?.id ?? "")
        }
    }
    
    // MARK: - Filter Buttons Section
    private var filterButtonsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Starred filter
                Button {
                    viewModel.toggleStarredFilter()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.subheadline)
                        Text("Starred")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundStyle(Color.yellow)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(viewModel.showStarredOnly ? Color.yellow : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 24)
                
                // Status filters
                ForEach(viewModel.statuses, id: \.self) { status in
                    Button {
                        viewModel.toggleStatusFilter(status)
                    } label: {
                        Text(status.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(status.backgroundColor)
                             .foregroundStyle(status.color)
                            .cornerRadius(14)
                            .overlay(
                                // Border if selected
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(viewModel.selectedStatusFilter == status ? status.color : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }



    
    // MARK: - Helper Functions
    
    private func getEmptyStateIcon() -> String {
        if viewModel.applications.isEmpty {
            return "briefcase"
        } else if viewModel.showStarredOnly {
            return "star"
        } else if viewModel.selectedStatusFilter != nil {
            return "magnifyingglass"
        } else {
            return "magnifyingglass"
        }
    }
    
    private func getEmptyStateTitle() -> String {
        if viewModel.applications.isEmpty {
            return "No Applications Yet"
        } else if viewModel.showStarredOnly {
            return "No Starred Applications"
        } else if let filter = viewModel.selectedStatusFilter {
            return "No \(filter) Applications"
        } else {
            return "No Results Found"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        if viewModel.applications.isEmpty {
            return "Start tracking your job applications\nby tapping the + button above"
        } else if viewModel.showStarredOnly {
            return "Star important applications to\nquickly access them here"
        } else if viewModel.selectedStatusFilter != nil {
            return "No applications match this status filter"
        } else {
            return "Try adjusting your search or filters"
        }
    }
}


// MARK: - Status Badge

struct StatusBadge: View {
    let status: ApplicationStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .foregroundStyle(status.color)
            .cornerRadius(12)
    }
}


#Preview {
    ApplicationsListView(repository: MockApplicationRepository())
        .environmentObject(AuthViewModel())
}
