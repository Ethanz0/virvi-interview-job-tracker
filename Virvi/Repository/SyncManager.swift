import Foundation
import SwiftData
import FirebaseFirestore

// MARK: - Sync Manager
/// Handles bidirectional sync between SwiftData and Firestore
@MainActor
class SyncManager: ObservableObject {

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let modelContext: ModelContext
    private let firestoreRepo: FirestoreApplicationRepository
    private var userId: String?
    private var syncTask: Task<Void, Never>?
    private var hasPendingChanges = false
    
    // Sync configuration
    private let debounceInterval: TimeInterval = 5.0  // Wait 5 seconds after last change
    private let minSyncInterval: TimeInterval = 30.0  // Don't sync more than once per 30 seconds
        
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.firestoreRepo = FirestoreApplicationRepository()
    }
    
    // MARK: - Public API
    
    /// Enable sync for authenticated user
    func enableSync(for userId: String) {
        self.userId = userId
    }
    
    /// Disable sync (user logged out)
    func disableSync() {
        self.userId = nil
        syncTask?.cancel()
        syncTask = nil
    }
    
    /// Manually trigger sync (ignores debounce/throttle)
    func syncNow() async {
        guard let userId = userId else { return }
        syncTask?.cancel()
        await performSync(userId: userId)
    }
    
    /// Manually trigger a full sync including pull from cloud
    func fullSyncNow() async {
        guard let userId = userId else { return }
        syncTask?.cancel()
        await performFullSync(userId: userId)
    }
    
    /// Schedule a sync after data changes (debounced and throttled)
    func scheduleSync() {
        guard let userId = userId else { return }
        
        // Cancel any pending sync
        syncTask?.cancel()
        
        // Mark that we have changes
        hasPendingChanges = true
        
        // Check if we synced recently
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            // Too soon to sync again, wait longer
            print("Sync throttled - last sync was \(Int(Date().timeIntervalSince(lastSync)))s ago")
            scheduleDeferredSync(userId: userId)
            return
        }
        
        // Schedule sync after debounce interval
        syncTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
                
                // Check if task was cancelled
                if !Task.isCancelled && hasPendingChanges {
                    await performSync(userId: userId)
                    hasPendingChanges = false
                }
            } catch {
                // Task was cancelled or sleep was interrupted
            }
        }
    }
    
    /// Schedule a sync for later if throttled
    private func scheduleDeferredSync(userId: String) {
        syncTask = Task {
            guard let lastSync = lastSyncDate else { return }
            
            // Wait until minimum interval has passed
            let timeToWait = minSyncInterval - Date().timeIntervalSince(lastSync)
            
            do {
                try await Task.sleep(nanoseconds: UInt64(timeToWait * 1_000_000_000))
                
                if !Task.isCancelled && hasPendingChanges {
                    await performSync(userId: userId)
                    hasPendingChanges = false
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    /// Initial sync when user logs in (pull from cloud)
    func performInitialSync(userId: String) async {
        self.userId = userId
        print("Starting initial sync...")
        await performFullSync(userId: userId)
        print("Initial sync completed")
    }
    
    // MARK: - Private Sync Logic
    
    private func performSync(userId: String) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Check if there are actually changes to sync
            let hasChanges = try await checkForPendingChanges()
            
            if !hasChanges {
                print("No changes to sync - skipping Firestore calls")
                lastSyncDate = Date()
                isSyncing = false
                return
            }
            
            print("Starting sync - found pending changes")
            
            // Push deletions and updates to Firestore first
            await pushToFirestore(userId: userId)
            
            // Clean up old soft-deleted items that have been synced
            await cleanupSyncedDeletions()
            
            lastSyncDate = Date()
            print("Sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            print("Sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    /// Full sync including pull from Firestore (used on login and manual refresh)
    private func performFullSync(userId: String) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            print("🔄 Starting full sync (including pull from cloud)")
            
            // Push local changes first
            await pushToFirestore(userId: userId)
            
            // Pull changes from Firestore
            await pullFromFirestore(userId: userId)
            
            // Clean up old soft-deleted items
            await cleanupSyncedDeletions()
            
            lastSyncDate = Date()
            print("Full sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            print("Full sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    /// Check if there are any pending changes that need syncing
    private func checkForPendingChanges() async throws -> Bool {
        // Check for applications that need sync
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.needsSync == true
            }
        )
        
        let appsNeedingSync = try modelContext.fetch(appDescriptor)
        
        if !appsNeedingSync.isEmpty {
            print("Found \(appsNeedingSync.count) applications needing sync")
            return true
        }
        
        // Check for stages that need sync
        let stageDescriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { stage in
                stage.needsSync == true
            }
        )
        
        let stagesNeedingSync = try modelContext.fetch(stageDescriptor)
        
        if !stagesNeedingSync.isEmpty {
            print("Found \(stagesNeedingSync.count) stages needing sync")
            return true
        }
        
        return false
    }
    
    // MARK: - Cleanup
    
    /// Remove soft-deleted items that have been successfully synced to Firestore
    private func cleanupSyncedDeletions() async {
        do {
            // Find deleted items that don't need sync anymore (already synced)
            let descriptor = FetchDescriptor<SDApplication>(
                predicate: #Predicate { app in
                    app.isDeleted == true && app.needsSync == false
                }
            )
            
            let syncedDeletedApps = try modelContext.fetch(descriptor)
            
            // Hard delete them from local database
            for app in syncedDeletedApps {
                print("Permanently removing synced deleted app: \(app.company)")
                modelContext.delete(app)
            }
            
            if !syncedDeletedApps.isEmpty {
                try modelContext.save()
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }
    
    // MARK: - Pull from Firestore
    
    private func pullFromFirestore(userId: String) async {
        do {
            let firestoreApps = try await firestoreRepo.fetchApplications(for: userId)
            
            for appWithStages in firestoreApps {
                try await mergeApplication(appWithStages, userId: userId)
            }
            
            try modelContext.save()
        } catch {
            print("Pull error: \(error)")
        }
    }
    
    private func mergeApplication(_ cloudApp: ApplicationWithStages, userId: String) async throws {
        guard let cloudId = cloudApp.application.id else { return }
        
        // Check if we already have this application
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.firestoreId == cloudId
            }
        )
        
        if let existingApp = try modelContext.fetch(descriptor).first {
            // If local app is deleted and marked for sync, don't resurrect it
            if existingApp.isDeleted && existingApp.needsSync {
                print("Skipping cloud app - locally deleted and pending sync: \(cloudId)")
                return
            }
            
            // If local app is deleted but NOT synced yet, the cloud version wins
            // (This handles the case where deletion wasn't synced before pulling)
            if existingApp.isDeleted && !existingApp.needsSync {
                print("Resurrecting app from cloud (deletion was already synced): \(cloudId)")
                existingApp.isDeleted = false
            }
            
            // Conflict resolution: cloud wins if cloud is newer
            if cloudApp.application.updatedAt.dateValue() > existingApp.updatedAt {
                existingApp.role = cloudApp.application.role
                existingApp.company = cloudApp.application.company
                existingApp.date = cloudApp.application.date.dateValue()
                existingApp.status = cloudApp.application.status
                existingApp.starred = cloudApp.application.starred
                existingApp.note = cloudApp.application.note
                existingApp.updatedAt = cloudApp.application.updatedAt.dateValue()
                existingApp.needsSync = false
                existingApp.lastSyncedAt = Date()
                print("Updated local app from cloud: \(cloudApp.application.company)")
            } else {
                print("Local app is newer, keeping local: \(existingApp.company)")
            }
            
            // Merge stages
            try await mergeStages(cloudStages: cloudApp.stages, localApp: existingApp)
            
        } else {
            // New application from cloud - create it locally
            let newApp = SDApplication.from(cloudApp.application)
            newApp.needsSync = false
            newApp.lastSyncedAt = Date()
            modelContext.insert(newApp)
            print("Created new app from cloud: \(cloudApp.application.company)")
            
            // Insert stages
            for stage in cloudApp.stages {
                let newStage = SDApplicationStage.from(stage)
                newStage.needsSync = false
                newStage.lastSyncedAt = Date()
                newStage.application = newApp
                modelContext.insert(newStage)
            }
        }
    }
    
    private func mergeStages(cloudStages: [ApplicationStage], localApp: SDApplication) async throws {
        for cloudStage in cloudStages {
            guard let cloudStageId = cloudStage.id else { continue }
            
            // Check if stage exists locally
            let existingStage = localApp.stages?.first { stage in
                stage.firestoreId == cloudStageId
            }
            
            if let existingStage = existingStage {
                // Skip if locally deleted and pending sync
                if existingStage.isDeleted && existingStage.needsSync {
                    continue
                }
                
                // Update if cloud is newer
                if cloudStage.updatedAt.dateValue() > existingStage.updatedAt {
                    existingStage.stage = cloudStage.stage
                    existingStage.status = cloudStage.status
                    existingStage.date = cloudStage.date.dateValue()
                    existingStage.note = cloudStage.note
                    existingStage.sortOrder = cloudStage.sortOrder
                    existingStage.updatedAt = cloudStage.updatedAt.dateValue()
                    existingStage.needsSync = false
                    existingStage.lastSyncedAt = Date()
                    existingStage.isDeleted = false
                }
            } else {
                // New stage from cloud
                let newStage = SDApplicationStage.from(cloudStage)
                newStage.needsSync = false
                newStage.lastSyncedAt = Date()
                newStage.application = localApp
                modelContext.insert(newStage)
            }
        }
    }
    
    // MARK: - Push to Firestore
    
    private func pushToFirestore(userId: String) async {
        do {
            // Push deleted items first
            await pushDeletions(userId: userId)
            
            // Then push updates/creates
            let descriptor = FetchDescriptor<SDApplication>(
                predicate: #Predicate { app in
                    app.needsSync == true && app.isDeleted == false
                }
            )
            
            let appsNeedingSync = try modelContext.fetch(descriptor)
            
            for sdApp in appsNeedingSync {
                try await pushApplication(sdApp, userId: userId)
            }
            
            try modelContext.save()
        } catch {
            print("Push error: \(error)")
            syncError = "Failed to sync: \(error.localizedDescription)"
        }
    }
    
    private func pushDeletions(userId: String) async {
        do {
            // Find all deleted applications that need sync
            let descriptor = FetchDescriptor<SDApplication>(
                predicate: #Predicate { app in
                    app.isDeleted == true && app.needsSync == true
                }
            )
            
            let deletedApps = try modelContext.fetch(descriptor)
            
            for sdApp in deletedApps {
                // Delete from Firestore if it has a Firestore ID
                if let firestoreId = sdApp.firestoreId {
                    try await firestoreRepo.deleteApplication(id: firestoreId, for: userId)
                    print("Deleted application from Firestore: \(firestoreId)")
                }
                
                // Now actually delete from SwiftData (hard delete)
                modelContext.delete(sdApp)
            }
            
            try modelContext.save()
        } catch {
            print("Deletion push error: \(error)")
        }
    }
    
    private func pushApplication(_ sdApp: SDApplication, userId: String) async throws {
        let application = sdApp.toApplication()
        
        // 1️⃣ If the local app has no firestoreId, try to find a matching cloud app first
        if sdApp.firestoreId == nil {
            if let existingCloudApp = try await firestoreRepo.findApplication(
                company: sdApp.company,
                role: sdApp.role,
                date: sdApp.date,
                for: userId
            ) {
                // Assign Firestore ID to local app and skip creating a new document
                sdApp.firestoreId = existingCloudApp.id
                print("Linked local app to existing cloud app: \(sdApp.company)")
                
                // Optionally update local app with latest cloud data
                if existingCloudApp.updatedAt.dateValue() > sdApp.updatedAt {
                    sdApp.role = existingCloudApp.role
                    sdApp.company = existingCloudApp.company
                    sdApp.date = existingCloudApp.date.dateValue()
                    sdApp.status = existingCloudApp.status
                    sdApp.starred = existingCloudApp.starred
                    sdApp.note = existingCloudApp.note
                    sdApp.updatedAt = existingCloudApp.updatedAt.dateValue()
                }
            }
        }
        
        // 2️⃣ Create or update in Firestore
        if let firestoreId = sdApp.firestoreId {
            // Update existing in Firestore
            try await firestoreRepo.updateApplication(application, for: userId)
            print("Updated app in Firestore: \(sdApp.company)")
        } else {
            // Create new in Firestore
            let newId = try await firestoreRepo.createApplication(application, for: userId)
            sdApp.firestoreId = newId
            print("Created new app in Firestore: \(sdApp.company) (ID: \(newId))")
        }
        
        // 3️⃣ Sync stages
        for sdStage in sdApp.stages ?? [] where !sdStage.isDeleted {
            if sdStage.needsSync {
                try await pushStage(sdStage, applicationId: sdApp.firestoreId ?? sdApp.id, userId: userId)
            }
        }
        
        // 4️⃣ Push deleted stages
        for sdStage in sdApp.stages ?? [] where sdStage.isDeleted {
            if sdStage.needsSync, let firestoreStageId = sdStage.firestoreId {
                try await firestoreRepo.deleteStage(
                    id: firestoreStageId,
                    for: sdApp.firestoreId ?? sdApp.id,
                    userId: userId
                )
                print("Deleted stage from Firestore")
                // Mark as synced so it can be cleaned up
                sdStage.needsSync = false
                sdStage.lastSyncedAt = Date()
            }
        }
        
        // 5️⃣ Mark application as synced
        sdApp.needsSync = false
        sdApp.lastSyncedAt = Date()
    }

    
    private func pushStage(_ sdStage: SDApplicationStage, applicationId: String, userId: String) async throws {
        let stage = sdStage.toApplicationStage()
        
        if let firestoreId = sdStage.firestoreId {
            // Update existing
            try await firestoreRepo.updateStage(stage, for: applicationId, userId: userId)
            print("Updated stage in Firestore")
        } else {
            // Create new
            let newId = try await firestoreRepo.createStage(stage, for: applicationId, userId: userId)
            sdStage.firestoreId = newId
            print("Created new stage in Firestore (ID: \(newId))")
        }
        
        sdStage.needsSync = false
        sdStage.lastSyncedAt = Date()
    }

}
