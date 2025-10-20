import SwiftUI
import SwiftData

enum InterviewDestination: Hashable {
    case questionList(Interview)
    case dynamicInterview(Interview)
    case interview(Interview)
}

struct ContentView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTab = 0
    @State private var interviewPath = NavigationPath()
    @State private var syncManager: SyncManager?
    @State private var formResetTrigger = UUID()
    
    private var applicationRepository: ApplicationRepository {
        SwiftDataApplicationRepository(
            modelContext: modelContext,
            syncManager: syncManager
        )
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ApplicationsListView(repository: applicationRepository)
                .tabItem {
                    Label("Applications", systemImage: "list.bullet")
                }
                .tag(0)
            
            NavigationStack(path: $interviewPath) {
                InterviewForm(
                    path: $interviewPath,
                    resetTrigger: formResetTrigger
                )
                .navigationDestination(for: InterviewDestination.self) { destination in
                    switch destination {
                    case .questionList(let interview):
                        QuestionListView(
                            interview: interview,
                            path: $interviewPath
                        )
                    case .dynamicInterview(let interview):
                        InterviewChatView(
                            interview: interview,
                            isDynamicMode: true,
                            path: $interviewPath,
                            onComplete: resetInterviewForm
                        )
                    case .interview(let interview):
                        InterviewChatView(
                            interview: interview,
                            isDynamicMode: false,
                            path: $interviewPath,
                            onComplete: resetInterviewForm
                        )
                    }
                }
            }
            .tabItem {
                Label("New Interview", systemImage: "plus.circle.fill")
            }
            .tag(1)
            
            CompletedInterviewsView()
                .tabItem {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                }
                .tag(2)
            
            if let syncManager = syncManager {
                ProfileView(syncManager: syncManager)
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(3)
            } else {
                ProfileView(syncManager: SyncManager(modelContext: modelContext))
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(3)
            }
        }
        .onAppear {
            if syncManager == nil {
                Task{
                    await setupSyncManager()

                }
            }
        }
        .onChange(of: auth.user) { oldUser, newUser in
            Task{
                await handleAuthChange(oldUser: oldUser, newUser: newUser)
            }
        }
    }
    
    private func resetInterviewForm() {
        formResetTrigger = UUID()
    }
    
    private func setupSyncManager() async {
        let manager = SyncManager(modelContext: modelContext)
        syncManager = manager
        
        if let user = auth.user {
            await manager.enableSync(for: user.id)
            Task {
                await manager.performInitialSync(userId: user.id)
            }
        }
    }
    
    private func handleAuthChange(oldUser: AppUser?, newUser: AppUser?) async {
        guard let manager = syncManager else { return }
        
        if let user = newUser {
            await manager.enableSync(for: user.id)
            Task {
                await manager.performInitialSync(userId: user.id)
            }
        } else if oldUser != nil {
            await manager.disableSync()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel(authService: MockAuthService()))
        .modelContainer(for: [SDApplication.self, Interview.self], inMemory: true)
}
