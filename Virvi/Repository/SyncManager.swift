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
    private let debounceInterval: TimeInterval = 5.0
    private let minSyncInterval: TimeInterval = 30.0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.firestoreRepo = FirestoreApplicationRepository()
    }
    
    // MARK: - Public API
    
    func enableSync(for userId: String) {
        self.userId = userId
    }
    
    func disableSync() {
        self.userId = nil
        syncTask?.cancel()
        syncTask = nil
    }
    
    func syncNow() async {
        guard let userId = userId else { return }
        syncTask?.cancel()
        await performSync(userId: userId)
    }
    
    func fullSyncNow() async {
        guard let userId = userId else { return }
        syncTask?.cancel()
        await performFullSync(userId: userId)
    }
    
    func scheduleSync() {
        guard let userId = userId else { return }
        
        syncTask?.cancel()
        hasPendingChanges = true
        
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            print("Sync throttled - last sync was \(Int(Date().timeIntervalSince(lastSync)))s ago")
            scheduleDeferredSync(userId: userId)
            return
        }
        
        syncTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
                
                if !Task.isCancelled && hasPendingChanges {
                    await performSync(userId: userId)
                    hasPendingChanges = false
                }
            } catch {}
        }
    }
    
    private func scheduleDeferredSync(userId: String) {
        syncTask = Task {
            guard let lastSync = lastSyncDate else { return }
            let timeToWait = minSyncInterval - Date().timeIntervalSince(lastSync)
            
            do {
                try await Task.sleep(nanoseconds: UInt64(timeToWait * 1_000_000_000))
                
                if !Task.isCancelled && hasPendingChanges {
                    await performSync(userId: userId)
                    hasPendingChanges = false
                }
            } catch {}
        }
    }
    
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
            let hasChanges = try await checkForPendingChanges()
            
            if !hasChanges {
                print("No changes to sync - skipping Firestore calls")
                lastSyncDate = Date()
                isSyncing = false
                return
            }
            print("Starting sync - found pending changes")
            
            await pushToFirestore(userId: userId)
            await cleanupSyncedDeletions()
            
            lastSyncDate = Date()
            print("Sync completed successfully")
        } catch {
            syncError = error.localizedDescription
            print("Sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    private func performFullSync(userId: String) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
//        do {
            print("🔄 Starting full sync (including pull from cloud)")
            await pushToFirestore(userId: userId)
            await pullFromFirestore(userId: userId)
            await cleanupSyncedDeletions()
            
            lastSyncDate = Date()
            print("Full sync completed successfully")
//        } catch {
//            syncError = error.localizedDescription
//            print("Full sync error: \(error)")
//        }
        
        isSyncing = false
    }
    
    private func checkForPendingChanges() async throws -> Bool {
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in app.needsSync == true }
        )
        let appsNeedingSync = try modelContext.fetch(appDescriptor)
        
        if !appsNeedingSync.isEmpty {
            print("Found \(appsNeedingSync.count) applications needing sync")
            return true
        }
        
        let stageDescriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { stage in stage.needsSync == true }
        )
        let stagesNeedingSync = try modelContext.fetch(stageDescriptor)
        
        if !stagesNeedingSync.isEmpty{
            print("Found \(stagesNeedingSync.count) stages needing sync")
            return true
        }
        return false
    }
    
    // MARK: - Cleanup
    
    private func cleanupSyncedDeletions() async {
        do {
            let descriptor = FetchDescriptor<SDApplication>(
                predicate: #Predicate { app in
                    app.isDeleted == true && app.needsSync == false
                }
            )
            
            let syncedDeletedApps = try modelContext.fetch(descriptor)
            
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
    
    private func mergeApplication(_ cloudApp: FSApplicationWithStages, userId: String) async throws {
        guard let cloudId = cloudApp.application.id else { return }
        
        let descriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in app.firestoreId == cloudId }
        )
        
        if let existingApp = try modelContext.fetch(descriptor).first {
            if existingApp.isDeleted && existingApp.needsSync {
                print("Skipping cloud app - locally deleted and pending sync: \(cloudId)")
                return
            }
            
            if existingApp.isDeleted && !existingApp.needsSync {
                print("Resurrecting app from cloud (deletion was already synced): \(cloudId)")
                existingApp.isDeleted = false
            }
            
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
            
            
            try await mergeStages(cloudStages: cloudApp.stages, localApp: existingApp)
            
        } else {
            let newApp = SDApplication.from(cloudApp.application)
            newApp.needsSync = false
            newApp.lastSyncedAt = Date()
            modelContext.insert(newApp)
            print("Created new app from cloud: \(cloudApp.application.company)")
            
            for stage in cloudApp.stages {
                let newStage = SDApplicationStage.from(stage)
                newStage.needsSync = false
                newStage.lastSyncedAt = Date()
                newStage.application = newApp
                modelContext.insert(newStage)
            }
        }
    }
    
    private func mergeStages(cloudStages: [FSApplicationStage], localApp: SDApplication) async throws {
        for cloudStage in cloudStages {
            guard let cloudStageId = cloudStage.id else { continue }
            
            let existingStage = localApp.stages?.first { stage in
                stage.firestoreId == cloudStageId
            }
            
            if let existingStage = existingStage {
                if existingStage.isDeleted && existingStage.needsSync {
                    continue
                }
                
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
            await pushDeletions(userId: userId)
            
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
            let descriptor = FetchDescriptor<SDApplication>(
                predicate: #Predicate { app in
                    app.isDeleted == true && app.needsSync == true
                }
            )
            
            let deletedApps = try modelContext.fetch(descriptor)
            
            for sdApp in deletedApps {
                if let firestoreId = sdApp.firestoreId {
                    try await firestoreRepo.deleteApplication(id: firestoreId, for: userId)
                }
                modelContext.delete(sdApp)
            }
            
            try modelContext.save()
        } catch {
            print("Deletion push error: \(error)")
        }
    }
    
    private func pushApplication(_ sdApp: SDApplication, userId: String) async throws {
        let application = sdApp.toFSApplication()
        
        // Check for existing cloud app
        if sdApp.firestoreId == nil {
            if let existingCloudApp = try await firestoreRepo.findApplication(
                company: sdApp.company,
                role: sdApp.role,
                date: sdApp.date,
                for: userId
            ) {
                sdApp.firestoreId = existingCloudApp.id
                print("Linked local app to existing cloud app: \(sdApp.company)")
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
        
        // Create or update in Firestore
        if sdApp.firestoreId != nil {
            try await firestoreRepo.updateApplication(application, for: userId)
            print("Updated app in Firestore: \(sdApp.company)")

        } else {
            let newId = try await firestoreRepo.createApplication(application, for: userId)
            sdApp.firestoreId = newId
            print("Created new app in Firestore: \(sdApp.company) (ID: \(newId))")

        }
        
        // Sync stages
        for sdStage in sdApp.stages ?? [] where !sdStage.isDeleted {
            if sdStage.needsSync {
                try await pushStage(sdStage, applicationId: sdApp.firestoreId ?? sdApp.id, userId: userId)
                
            }
        }
        
        // Push deleted stages
        for sdStage in sdApp.stages ?? [] where sdStage.isDeleted {
            if sdStage.needsSync, let firestoreStageId = sdStage.firestoreId {
                try await firestoreRepo.deleteStage(
                    id: firestoreStageId,
                    for: sdApp.firestoreId ?? sdApp.id,
                    userId: userId
                )
                print("Deleted stage from Firestore")
                sdStage.needsSync = false
                sdStage.lastSyncedAt = Date()
            }
        }
        
        sdApp.needsSync = false
        sdApp.lastSyncedAt = Date()
    }
    
    private func pushStage(_ sdStage: SDApplicationStage, applicationId: String, userId: String) async throws {
        let stage = sdStage.toFSApplicationStage()
        
        if sdStage.firestoreId != nil {
            try await firestoreRepo.updateStage(stage, for: applicationId, userId: userId)
            print("Updated stage in Firestore")
        } else {
            let newId = try await firestoreRepo.createStage(stage, for: applicationId, userId: userId)
            sdStage.firestoreId = newId
            print("Created new stage in Firestore (ID: \(newId))")
        }
        
        sdStage.needsSync = false
        sdStage.lastSyncedAt = Date()
    }
}
