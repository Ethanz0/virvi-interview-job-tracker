import SwiftUI

struct ApplicationsListView: View {
    let repository: ApplicationRepository
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var dependencies: AppDependencies
    @StateObject private var viewModel: ApplicationsListViewModel
    @State private var showingAddSheet = false
    
    init(repository: ApplicationRepository) {
        self.repository = repository
        self._showingAddSheet = State(initialValue: false)
        self._viewModel = StateObject(wrappedValue: ApplicationsListViewModel(repository: repository))
        self._viewModel = StateObject(wrappedValue: ApplicationsListViewModel(repository: repository))

    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterButtonsSection
                
                if viewModel.isLoading && viewModel.applications.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading applications...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredApplications.isEmpty {
                    emptyStateView
                } else {
                    applicationsList
                }
            }
            .navigationTitle("Job Applications")
            .searchable(text: $viewModel.searchText, prompt: "Search applications")
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.applyFilters()
            }
            .onAppear {
                viewModel.setSyncManager(dependencies.syncManager)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                EditApplicationView(
                    applicationWithStages: nil,
                    repository: viewModel.repository
                )
                .onDisappear {
                    Task {
                        await viewModel.refreshApplications()
                    }
                }
            }
            .sheet(item: $viewModel.selectedApplicationToEdit) { app in
                EditApplicationView(
                    applicationWithStages: app,
                    repository: viewModel.repository
                )
                .onDisappear {
                    viewModel.selectedApplicationToEdit = nil
                    Task {
                        await viewModel.refreshApplications()
                    }
                }
            }
            .task {
                if viewModel.applications.isEmpty {
                    await viewModel.loadApplications()
                }
            }
            .task(id: auth.user?.id) {
                await viewModel.loadApplications()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Applications List
    
    private var applicationsList: some View {
        List {
            ForEach(viewModel.filteredApplications) { appWithStages in
                ApplicationRowView(
                    viewModel: viewModel,
                    applicationWithStages: appWithStages
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .refreshable {
            await viewModel.refreshApplications()
        }
    }
    
    // MARK: - Filter Buttons Section
    
    private var filterButtonsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
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
            return "No \(filter.rawValue) Applications"
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
