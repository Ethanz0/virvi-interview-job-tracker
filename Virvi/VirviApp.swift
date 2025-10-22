import SwiftUI
import FirebaseCore
import FirebaseAppCheck  // Add this import
import GoogleSignIn
import SwiftData
import BackgroundTasks

@main
struct Virvi: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth: AuthViewModel
    @StateObject private var dependencies: AppDependencies
    
    // SwiftData container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SDApplication.self,
            SDApplicationStage.self,
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
    
    init() {
        // Configure App Check FIRST
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory = AppAttestProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        // Then configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        // Configure Google Sign-In
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        
        // Create dependencies with the model context
        let context = sharedModelContainer.mainContext
        let deps = AppDependencies(modelContext: context)
        _dependencies = StateObject(wrappedValue: deps)
        
        // Create auth view model
        _auth = StateObject(wrappedValue: AuthViewModel(authService: deps.authService))
    }
    
    var body: some Scene {
            WindowGroup {
                ContentView()
                    .environmentObject(auth)
                    .environmentObject(dependencies)
                    .task {
                        if let user = auth.user {
                            await dependencies.enableSync(for: user.id)
                        }
                    }
                    .onChange(of: auth.user) { oldValue, newValue in
                        Task {
                            if newValue != nil, oldValue == nil {
                                // User just logged in
                                await dependencies.enableSync(for: newValue!.id)
                            } else if newValue == nil, oldValue != nil {
                                // User just logged out
                                await dependencies.disableSync()
                            }
                        }
                    }
            }
            .modelContainer(sharedModelContainer)

        }

    private func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.virvi.app.refresh-question")
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

// AppDelegate stays the same
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
    [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundRefresh()
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.virvi.app.refresh-question")
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

