import SwiftUI
import FirebaseCore
import GoogleSignIn
import SwiftData

@main
struct Virvi: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthViewModel()
    
    // SwiftData container with ALL models including existing Interview models
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // New application tracking models
            SDApplication.self,
            SDApplicationStage.self,
            // Existing interview models - IMPORTANT: Keep these!
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
                    if let user = newValue, oldValue == nil {
                        Task {
                            let context = sharedModelContainer.mainContext
                            let syncManager = SyncManager(modelContext: context)
                            await syncManager.performInitialSync(userId: user.id)
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
    [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Configure Google Sign-In
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            print("Warning: Missing Firebase clientID")
        }
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
