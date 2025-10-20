import SwiftUI
import FirebaseCore
import GoogleSignIn
import SwiftData
import BackgroundTasks

@main
struct Virvi: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Initialize auth AFTER Firebase is configured
    init() {
        // Configure Firebase FIRST, before anything else
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Configure Google Sign-In
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }
    
    @StateObject private var auth = AuthViewModel()
    
    // SwiftData container with models including existing Interview models
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // New application tracking models
            SDApplication.self,
            SDApplicationStage.self,
            // Existing interview models
            Interview.self,
            Question.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("ModelContainer created with all models")
            return container
        } catch {
            print("ModelContainer creation failed: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onChange(of: auth.user) { oldValue, newValue in
                    // Setup sync when user authenticates
                    if newValue != nil, oldValue == nil {
                        Task {
                            let context = sharedModelContainer.mainContext
                            _ = SyncManager(modelContext: context)
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh("com.virvi.app.refresh-question")) {
            await handleBackgroundQuestionRefresh()
        }
    }
    
    // MARK: - Background Task Handler
    
    private func handleBackgroundQuestionRefresh() async {
        print("🔔 Background task is running!")
        
        scheduleNextBackgroundRefresh()
        
        let service = QuestionUpdateService()
        await service.updateQuestionIfNeeded()
        
        print("✅ Background task completed!")
    }
    private func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.virvi.app.refresh-question")
        
        // Request refresh in 24 hours
        request.earliestBeginDate = Calendar.current.date(
            byAdding: .hour,
            value: 24,
            to: Date()
        )
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled successfully")
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
    [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase is now configured in App init()
        // This just ensures it's available for app delegate methods
        
        // DO NOT register background task here - it's handled by .backgroundTask modifier
        
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Schedule background refresh when app goes to background
        scheduleBackgroundRefresh()
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.virvi.app.refresh-question")
        
        // Request refresh in 24 hours
        request.earliestBeginDate = Calendar.current.date(
            byAdding: .hour,
            value: 24,
            to: Date()
        )
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled from AppDelegate")
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
}
