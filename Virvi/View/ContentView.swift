import SwiftUI
import BackgroundTasks
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
    @State private var questionService = QuestionUpdateService()
    @State private var applicationRepository: SwiftDataApplicationRepository?

    var body: some View {
        Group {
            if let repository = applicationRepository {
                TabView(selection: $selectedTab) {
                    ApplicationsListView(repository: repository)
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
            } else {
                Color.black
                    .ignoresSafeArea()
                    .tabItem {
                        Label("Applications", systemImage: "list.bullet")
                    }
                    .tag(0)
            }
        }
        .onAppear {
            if syncManager == nil || applicationRepository == nil {
                Task {
                    await setupSyncManager()
                }
            }
            scheduleBackgroundTask()
        }
        .task {
            await questionService.updateQuestionIfNeeded()
        }
        .onChange(of: auth.user) { oldUser, newUser in
            Task {
                await handleAuthChange(oldUser: oldUser, newUser: newUser)
            }
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.virvi.app.refresh-question")
        request.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled successfully")
        } catch {
            print("Failed to schedule: \(error)")
        }
    }
    
    private func resetInterviewForm() {
        formResetTrigger = UUID()
    }
    
    private func setupSyncManager() async {
        print("Setting up SyncManager...")
        
        let manager = SyncManager(modelContext: modelContext)
        syncManager = manager
        
        // Create repository with sync manager
        let repo = SwiftDataApplicationRepository(
            modelContext: modelContext,
            syncManager: manager
        )
        applicationRepository = repo
        
        print("SyncManager and Repository initialized")
        
        if let user = auth.user {
            print("👤 Enabling sync for user: \(user.id)")
            await manager.enableSync(for: user.id)
        }
    }
    
    private func handleAuthChange(oldUser: AppUser?, newUser: AppUser?) async {
        guard let manager = syncManager else {
            print("handleAuthChange: syncManager is nil")
            return
        }
        
        if let user = newUser {
            print("Auth change: Enabling sync for user: \(user.id)")
            await manager.enableSync(for: user.id)
        } else if oldUser != nil {
            print("Auth change: Disabling sync (user signed out)")
            await manager.disableSync()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel(authService: MockAuthService()))
        .modelContainer(for: [SDApplication.self, Interview.self], inMemory: true)
}
