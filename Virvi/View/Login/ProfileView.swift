
import CryptoKit
import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var syncManager: SyncManager
    @State private var showingAccountSettings = false
    @State private var interviewCount = 0
    @State private var showingDeleteAllAlert = false
    private var repository: InterviewRepositoryProtocol {
        SwiftDataInterviewRepository(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            List {
                if let user = auth.user {
                    // MARK: - Profile Card
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
                                        Text(user.firstName.prefix(1).uppercased())
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.firstName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - Sync Status Section
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
                        Text("Your data is automatically synced to the cloud when you're signed in.")
                    }
                    
                    // MARK: - Data Management Section
                    Section {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text("Interviews Stored")
                            Spacer()
                            Text("\(interviewCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        if interviewCount > 0 {
                            Button {
                                showingDeleteAllAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    Text("Delete All Interviews")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        Text("Data Management")
                    }
                    
                } else {
                    // MARK: - Not Signed In Section
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
                            
                            Text("Sign in to sync your data across devices and back it up to the cloud.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                auth.signInWithGoogle()
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Sign In with Google")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain) // Add this to prevent Section's default button styling
                        }
                        .padding(.vertical)
                    }
                    
                    // MARK: - Data Management Section
                    Section {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            Text("Interviews Stored")
                            Spacer()
                            Text("\(interviewCount)")
                                .foregroundColor(.secondary)
                        }
                        
                        if interviewCount > 0 {
                            Button {
                                showingDeleteAllAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .frame(width: 24)
                                    Text("Delete All Interviews")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                            }
                        }
                    } header: {
                        Text("Data Management")
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                updateInterviewCount()
            }
            .alert("Delete All Interviews", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    do {
                        try repository.deleteAll()
                        updateInterviewCount()
                    } catch {
                        print("Failed to delete all interviews: \(error)")
                    }
                }
            } message: {
                Text("Are you sure you want to delete all \(interviewCount) interviews? This action cannot be undone and will delete all recordings.")
            }
            .sheet(isPresented: $showingAccountSettings) {
                if let user = auth.user {
                    AccountSettingsView(
                        user: user,
                        syncManager: syncManager,
                        interviewCount: interviewCount,
                        onDataDeleted: {
                            updateInterviewCount()
                        }
                    )
                }
            }
        }
    }
    
    private func updateInterviewCount() {
        do {
            interviewCount = try repository.getAll().count
        } catch {
            interviewCount = 0
        }
    }

    private func gradientColors(for user: AppUser) -> [Color] {
        let input = user.email + user.firstName
        let digest = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(digest) // convert digest -> [UInt8]
        
        // digest is 32 bytes, so indexing 0 and 1 is safe
        let hue1 = Double(bytes[0]) / 255.0
        let hue2 = Double(bytes[1]) / 255.0
        
        return [
            Color(hue: hue1, saturation: 0.7, brightness: 0.8),
            Color(hue: hue2, saturation: 0.6, brightness: 0.7)
        ]
    }

}

struct AccountSettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let user: AppUser
    let syncManager: SyncManager
    let interviewCount: Int
    let onDataDeleted: () -> Void
    
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAllAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteAccountError = false
    @State private var showingReauthSheet = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError = ""
    
    private var repository: InterviewRepositoryProtocol {
        SwiftDataInterviewRepository(modelContext: modelContext)
    }
    
    private var applicationRepository: ApplicationRepository {
        SwiftDataApplicationRepository(modelContext: modelContext, syncManager: syncManager)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LinearGradient(
                                colors: gradientColors(for: user),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Text(user.firstName.prefix(1).uppercased())
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.firstName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                
                // MARK: - Account Section
                Section {
                    Button {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("Sign Out")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Sign Out")
                }
                
                Section{
                    Button {
                        showingDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isDeletingAccount)
                }
                header: {
                    Text("Delete Account")
                } footer: {
                    Text("Deleting your account will permanently remove all your data from the cloud and this device.")
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
                Button("Sign Out", role: .destructive) {
                    Task {
                        await syncManager.fullSyncNow()
                        await syncManager.disableSync()
                        auth.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("You can sign in again anytime to sync your applications.")
            }

            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Account", role: .destructive) {
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
    
    private func deleteAccount() async {
        isDeletingAccount = true
        
        do {
            // 1. Delete all local data
            try repository.deleteAll()
            
            let appDescriptor = FetchDescriptor<SDApplication>()
            let allApps = try modelContext.fetch(appDescriptor)
            for app in allApps {
                modelContext.delete(app)
            }
            try modelContext.save()
            
            // 2. Delete all cloud data (mark as deleted and sync)
            let cloudApps = try await applicationRepository.fetchApplications()
            for appWithStages in cloudApps {
                try await applicationRepository.deleteApplication(appWithStages.application)
            }
            await syncManager.fullSyncNow()
            
            // 3. Disable sync
            await syncManager.disableSync()
            
            // 4. Delete Firebase Auth account
            try await auth.deleteAccount()
            
            isDeletingAccount = false
            dismiss()
        } catch let error as NSError {
            print("Failed to delete account: \(error)")
            isDeletingAccount = false
            
            // Check if error requires reauthentication
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                // Error code for requires recent login
                showingReauthSheet = true
            } else {
                showingDeleteAccountError = true
                deleteAccountError = error.localizedDescription
            }
        }
    }
    
    private func gradientColors(for user: AppUser) -> [Color] {
        let input = user.email + user.firstName
        let digest = SHA256.hash(data: Data(input.utf8))
        let bytes = Array(digest) // convert digest -> [UInt8]
        
        // digest is 32 bytes, so indexing 0 and 1 is safe
        let hue1 = Double(bytes[0]) / 255.0
        let hue2 = Double(bytes[1]) / 255.0
        
        return [
            Color(hue: hue1, saturation: 0.7, brightness: 0.8),
            Color(hue: hue2, saturation: 0.6, brightness: 0.7)
        ]
    }
}

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
                
                Button {
                    Task {
                        await reauthenticate()
                    }
                } label: {
                    HStack {
                        if isReauthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "globe")
                            Text("Sign In with Google")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isReauthenticating)
                .padding(.horizontal)
                
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
    
    private func reauthenticate() async {
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

#Preview("Signed In") {
    ProfileView(syncManager: SyncManager(modelContext: ModelContext(try! ModelContainer(for: SDApplication.self))))
        .environmentObject({
            let auth = AuthViewModel(authService: MockAuthService())
            auth.user = AppUser(id: "123", firstName: "John", email: "john@example.com")
            return auth
        }())
}

#Preview("Signed Out") {
    ProfileView(syncManager: SyncManager(modelContext: ModelContext(try! ModelContainer(for: SDApplication.self))))
        .environmentObject(AuthViewModel(authService: MockAuthService()))
}

#Preview("Account Settings") {
    AccountSettingsView(
        user: AppUser(id: "123", firstName: "John", email: "john@example.com"),
        syncManager: SyncManager(modelContext: ModelContext(try! ModelContainer(for: SDApplication.self))),
        interviewCount: 5,
        onDataDeleted: {}
    )
    .environmentObject({
        let auth = AuthViewModel(authService: MockAuthService())
        auth.user = AppUser(id: "123", firstName: "John", email: "john@example.com")
        return auth
    }())
}
