//
//  ProfileView.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import SwiftUI
import CryptoKit
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var dependencies: AppDependencies
    @ObservedObject var syncManager: SyncManager
    
    @State private var showingAccountSettings = false
    @State private var interviewCount = 0
    @State private var applicationCount = 0
    @State private var isLoadingCounts = false
    
    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    profileCardSection(user: user)
                    
                    syncStatusSection
                    
                    dataStatsSection
                    
                } else {
                    notSignedInSection
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showingAccountSettings) {
                if let user = auth.user {
                    AccountSettingsView(
                        user: user,
                        applicationRepository: dependencies.applicationRepository,
                        syncManager: syncManager,
                        interviewCount: interviewCount,
                        applicationCount: applicationCount,
                        onDataDeleted: {
                            Task {
                                await loadDataCounts()
                            }
                        }
                    )
                }
            }
            .task {
                await loadDataCounts()
            }
        }
    }
    
    // MARK: - View Components
    
    private func profileCardSection(user: AppUser) -> some View {
        Section {
            Button {
                showingAccountSettings = true
            } label: {
                HStack(spacing: 16) {
                    Circle()
                        .fill(LinearGradient(
                            colors: gradientColors(for: user),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text(user.displayInitial)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if !user.email.isEmpty && user.shouldShowEmail {
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                   .contentShape(Rectangle())
               }
               .buttonStyle(.plain)
           }
       }
    
    private var syncStatusSection: some View {
        Section {
            HStack {
                Image(systemName: "cloud")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                Text("Cloud Sync")
                Spacer()
                if syncManager.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            if let lastSync = syncManager.lastSyncDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    Text("Last synced")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            if let error = syncManager.syncError {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text(error)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            Button {
                Task {
                    await syncManager.fullSyncNow()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 24)
                    Text("Sync Now")
                    Spacer()
                }
            }
            .disabled(syncManager.isSyncing)
        } header: {
            Text("Sync Status")
        } footer: {
            Text("Your job applications are automatically synced to the cloud when you're signed in.")
        }
    }
    
    private var dataStatsSection: some View {
        Section {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                Text("Applications")
                Spacer()
                if isLoadingCounts {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("\(applicationCount)")
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                Text("Interviews")
                Spacer()
                if isLoadingCounts {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("\(interviewCount)")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Your Data")
        }
    }
    
    private var notSignedInSection: some View {
        Section {
            VStack(spacing: 16) {
                Circle()
                    .fill(LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                
                Text("Using Offline Mode")
                    .font(.headline)
                
                Text("Sign in to sync your job applications across devices and back it up to the cloud.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                SignInWithAppleButton()
                    .padding(.horizontal)
                
                GoogleSignInButton {
                    auth.signInWithGoogle()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Data Operations
    
    private func loadDataCounts() async {
        isLoadingCounts = true
        
        do {
            // Load interview count using interview repository
            let interviewRepo = SwiftDataInterviewRepository(modelContext: dependencies.modelContext)
            let interviews = try interviewRepo.getCompleted()
            interviewCount = interviews.count
            
            // Load application count using application repository
            applicationCount = try await dependencies.applicationRepository.getApplicationCount()
            
        } catch {
            print("Failed to load data counts: \(error)")
        }
        
        isLoadingCounts = false
    }
    
    private func gradientColors(for user: AppUser) -> [Color] {
        let input = user.email + user.displayName
        let digest = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(digest)
        
        let hue1 = Double(bytes[0]) / 255.0
        let hue2 = Double(bytes[1]) / 255.0
        
        return [
            Color(hue: hue1, saturation: 0.7, brightness: 0.8),
            Color(hue: hue2, saturation: 0.6, brightness: 0.7)
        ]
    }
}

// MARK: - Account Settings View

struct AccountSettingsView: View {
    let user: AppUser
    let applicationRepository: ApplicationRepository
    @ObservedObject var syncManager: SyncManager
    let interviewCount: Int
    let applicationCount: Int
    let onDataDeleted: () -> Void
    
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    
    @State private var isDeletingAccount = false
    @State private var isDeletingData = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteDataAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountError = false
    @State private var deleteAccountError = ""
    @State private var showingReauthSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section
                Section {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text("Name")
                        Spacer()
                        Text(user.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    if !user.email.isEmpty && user.shouldShowEmail {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Account Information")
                }
                
                // MARK: - Data Management Section
                Section {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text("Applications")
                        Spacer()
                        Text("\(applicationCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        Text("Interviews")
                        Spacer()
                        Text("\(interviewCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        showingDeleteDataAlert = true
                    } label: {
                        HStack {
                            if isDeletingData {
                                ProgressView()
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                            }
                            Text("Delete All Data")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .disabled(isDeletingData)
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Delete all applications and interviews from this device and the cloud.")
                }
                
                // MARK: - Sign Out Section
                Section {
                    Button {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .frame(width: 24)
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("Your interviews will remain on this device after signing out.")
                }
                
                // MARK: - Danger Zone
                Section {
                    Button {
                        showingDeleteAccountAlert = true
                    } label: {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                            }
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .disabled(isDeletingAccount)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Permanently delete your account and all associated data. This action cannot be undone.")
                }
            }
            .navigationTitle("Account Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out") {
                    signOut()
                }
            } message: {
                Text("Your interviews will remain on this device.")
            }
            .alert("Delete All Data", isPresented: $showingDeleteDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    Task {
                        await deleteAllData()
                    }
                }
            } message: {
                Text("This will permanently delete all applications and interviews from this device and the cloud. This action cannot be undone.")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all data from the cloud and this device. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingDeleteAccountError) {
                Button("OK", role: .cancel) {}
                Button("Try Again", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text(deleteAccountError)
            }
            .sheet(isPresented: $showingReauthSheet) {
                ReauthenticationView(
                    onSuccess: {
                        showingReauthSheet = false
                        Task {
                            await deleteAccount()
                        }
                    },
                    onCancel: {
                        showingReauthSheet = false
                        isDeletingAccount = false
                    }
                )
            }
        }
    }
    
    private func signOut() {
        auth.signOut()
        dismiss()
    }
    
    private func deleteAllData() async {
        isDeletingData = true
        
        do {
            print("Deleting all local data...")
            
            // Delete all interviews
            let interviewRepo = SwiftDataInterviewRepository(modelContext: dependencies.modelContext)
            try interviewRepo.deleteAll()
            
            // Delete all applications
            try await applicationRepository.deleteAllApplications()
            
            await syncManager.fullSyncNow()
            
            print("All data deleted successfully")
            isDeletingData = false
            onDataDeleted()
            
        } catch {
            print("Failed to delete data: \(error)")
            isDeletingData = false
        }
    }
    
    private func deleteAccount() async {
        isDeletingAccount = true
        
        do {
            print("Starting account deletion process...")
            
            await deleteAllData()
            
            if let userId = auth.user?.id {
                print("Fetching cloud applications for user \(userId)...")
                let firestoreRepo = FirestoreApplicationRepository()
                let cloudApps = try await firestoreRepo.fetchApplications(for: userId)
                print("Found \(cloudApps.count) applications to delete from Firestore")
                
                for appWithStages in cloudApps {
                    if let appId = appWithStages.application.id {
                        print("Deleting cloud application: \(appId)")
                        try await firestoreRepo.deleteApplication(id: appId, for: userId)
                    }
                }
            }
            
            print("Performing final sync...")
            await syncManager.fullSyncNow()
            
            print("Disabling sync...")
            await dependencies.disableSync()
            
            print("Deleting Firebase Auth account...")
            try await auth.deleteAccount()
            
            print("Account deletion completed successfully")
            isDeletingAccount = false
            onDataDeleted()
            dismiss()
            
        } catch let error as NSError {
            print("Failed to delete account: \(error)")
            print("Error domain: \(error.domain), code: \(error.code)")
            isDeletingAccount = false
            
            // Check if error requires reauthentication
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                print("Reauthentication required")
                showingReauthSheet = true
            } else {
                showingDeleteAccountError = true
                deleteAccountError = error.localizedDescription
            }
        }
    }
}

// MARK: - Reauthentication View

struct ReauthenticationView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var isReauthenticating = false
    @State private var errorMessage: String?
    
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Confirm Your Identity")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("For security, you need to sign in again before deleting your account.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                SignInWithAppleButton()
                    .padding(.horizontal)
                
                GoogleSignInButton {
                    Task {
                        await reauthenticateWithGoogle()
                    }
                }
                .padding(.horizontal)
                .disabled(isReauthenticating)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Reauthenticate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
    
    private func reauthenticateWithGoogle() async {
        isReauthenticating = true
        errorMessage = nil
        
        do {
            _ = try await auth.authService.signInWithGoogle()
            onSuccess()
        } catch {
            errorMessage = error.localizedDescription
            isReauthenticating = false
        }
    }
}
//
//// MARK: - Previews
//
//#Preview("Signed In") {
//    let container = try! ModelContainer(for: SDApplication.self, Interview.self)
//    let dependencies = AppDependencies(
//        modelContext: container.mainContext,
//        authService: MockAuthService()
//    )
//    
//    return ProfileView(syncManager: dependencies.syncManager)
//        .environmentObject({
//            let auth = AuthViewModel(authService: MockAuthService())
//            auth.user = AppUser(id: "123", firstName: "John", email: "john@example.com")
//            return auth
//        }())
//        .environmentObject(dependencies)
//        .modelContainer(container)
//}
//
//#Preview("Signed Out") {
//    let container = try! ModelContainer(for: SDApplication.self, Interview.self)
//    let dependencies = AppDependencies(
//        modelContext: container.mainContext,
//        authService: MockAuthService()
//    )
//    
//    return ProfileView(syncManager: dependencies.syncManager)
//        .environmentObject(AuthViewModel(authService: MockAuthService()))
//        .environmentObject(dependencies)
//        .modelContainer(container)
//}
//
//#Preview("Account Settings") {
//    let container = try! ModelContainer(for: SDApplication.self, Interview.self)
//    let dependencies = AppDependencies(
//        modelContext: container.mainContext,
//        authService: MockAuthService()
//    )
//    
//    return AccountSettingsView(
//        user: AppUser(id: "123", firstName: "John", email: "john@example.com"),
//        applicationRepository: dependencies.applicationRepository,
//        syncManager: dependencies.syncManager,
//        interviewCount: 5,
//        applicationCount: 12,
//        onDataDeleted: {}
//    )
//    .environmentObject({
//        let auth = AuthViewModel(authService: MockAuthService())
//        auth.user = AppUser(id: "123", firstName: "John", email: "john@example.com")
//        return auth
//    }())
//    .environmentObject(dependencies)
//    .modelContainer(container)
//}
