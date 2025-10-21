//
//  ContentView.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

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
    @EnvironmentObject var dependencies: AppDependencies
    
    @State private var selectedTab = 0
    @State private var interviewPath = NavigationPath()
    @State private var formResetTrigger = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            ApplicationsListView(repository: dependencies.applicationRepository)
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
            
            ProfileView(syncManager: dependencies.syncManager)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .onAppear {
            scheduleBackgroundTask()
//            print("SwiftData DB Location: \(URL.applicationSupportDirectory.path())")
//            let dirPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
//
//            let docsDir = dirPaths[0]
//
//            print(docsDir)
            print(dependencies.modelContext.sqliteCommand)

        }
        .task {
            await dependencies.questionService.updateQuestionIfNeeded()
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
}
extension ModelContext {
    var sqliteCommand: String {
        if let url = container.configurations.first?.url.path(percentEncoded: false) {
            "sqlite3 \"\(url)\""
        } else {
            "No SQLite database found."
        }
    }
}
#Preview {
    let container = try! ModelContainer(
        for: SDApplication.self, Interview.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let dependencies = AppDependencies(
        modelContext: container.mainContext,
        authService: MockAuthService()
    )
    
    ContentView()
        .environmentObject(AuthViewModel(authService: MockAuthService()))
        .environmentObject(dependencies)
        .modelContainer(container)
}
