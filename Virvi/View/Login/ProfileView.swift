import SwiftUI
import SwiftData

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var syncManager: SyncManager
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - User Info Section
                if let user = auth.user {
                    Section {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.blue, .indigo],
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
                    
                    // MARK: - Sign Out Section
                    Section {
                        Button {
                            showingSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("Your data will remain on this device after signing out.")
                    }
                } else {
                    // MARK: - Not Signed In Section
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "cloud.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            
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
                        }
                        .padding(.vertical)
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("Your data is stored locally")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.green)
                            Text("Complete privacy - no account required")
                                .font(.subheadline)
                        }
                        
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.green)
                            Text("Works offline")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task {
                        // Final sync to save everything to cloud
                        await syncManager.fullSyncNow()
                        
                        // Sign out (this calls disableSync which clears data)
                        await syncManager.disableSync()
                        auth.signOut()
                    }
                }
                
            } message: {
                Text("Your data will remain on this device. You can sign in again anytime to sync.")
            }
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
