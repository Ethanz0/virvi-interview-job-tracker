//
//  SyncManager.swift
//  Virvi
//
//  Created by Ethan Zhang on 5/10/2025.
//

import Foundation
import SwiftData
import FirebaseFirestore

// MARK: - Sync Manager with Stage Cleanup

@MainActor
class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var syncCompleted = false
    
    private let modelContext: ModelContext
    private let firestoreRepo: FirestoreApplicationRepository
    private var userId: String?
    private var syncTask: Task<Void, Never>?
    private var hasPendingChanges = false
    
    private let debounceInterval: TimeInterval = 5.0
    private let minSyncInterval: TimeInterval = 30.0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.firestoreRepo = FirestoreApplicationRepository()
    }
    
    // MARK: - Public API
    
    func enableSync(for userId: String) async {
        self.userId = userId
        await performInitialSync(userId: userId)
    }
    
    func disableSync() async {
        self.userId = nil
        syncTask?.cancel()
        syncTask = nil
        
        await clearAllLocalData()
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
    
    // MARK: - Clear Local Data
    
    private func clearAllLocalData() async {
        do {
            print("Clearing all local data on sign out")
            
            // Explicitly delete all stages first (cascade will handle this, but being explicit)
            let stageDescriptor = FetchDescriptor<SDApplicationStage>()
            let allStages = try modelContext.fetch(stageDescriptor)
            
            for stage in allStages {
                modelContext.delete(stage)
            }
            
            // Delete all applications (cascade will delete remaining stages)
            let appDescriptor = FetchDescriptor<SDApplication>()
            let allApps = try modelContext.fetch(appDescriptor)
            
            for app in allApps {
                modelContext.delete(app)
            }
            
            try modelContext.save()
            print("Cleared \(allApps.count) applications and \(allStages.count) stages")
            
            lastSyncDate = nil
            syncError = nil
            
        } catch {
            print("Error clearing data: \(error)")
            syncError = "Failed to clear data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Sync Methods
    
    func scheduleSync() {
        print("scheduleSync called - userId: \(userId ?? "nil")")
        guard let userId = userId else {
            print("scheduleSync aborted - no userId set")
            return
        }
        
        syncTask?.cancel()
        hasPendingChanges = true
        
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            print("Sync throttled - last sync was \(Int(Date().timeIntervalSince(lastSync)))s ago")
            scheduleDeferredSync(userId: userId)
            return
        }
        print("Sync detected, doing the sync")
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
            
            // Push changes (including deletions) to Firestore
            // PushDeletions now immediately hard-deletes after Firestore deletion
            await pushToFirestore(userId: userId)
            
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
        
        print("Starting full sync (including pull from cloud)")
        
        // Push FIRST to sync any local changes created while offline (including deletions)
        // PushDeletions now immediately hard-deletes after Firestore deletion
        await pushToFirestore(userId: userId)
        
        // Then pull to get any cloud changes
        // Deleted items are already gone, so they can't be resurrected
        await pullFromFirestore(userId: userId)
        
        lastSyncDate = Date()
        syncCompleted.toggle()

        print("Full sync completed successfully")
        
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
        
        if !stagesNeedingSync.isEmpty {
            print("Found \(stagesNeedingSync.count) stages needing sync")
            return true
        }
        return false
    }
    
    // MARK: - Cleanup
    
    // Extended cleanup to include stages and cascade delete
    private func cleanupSyncedDeletions() async throws {
        // Clean up applications first
        let appDescriptor = FetchDescriptor<SDApplication>(
            predicate: #Predicate { app in
                app.isDeleted == true && app.needsSync == false
            }
        )
        
        let syncedDeletedApps = try modelContext.fetch(appDescriptor)
        
        for app in syncedDeletedApps {
            print("Permanently removing synced deleted app: \(app.company)")
            
            // Cascade delete - explicitly delete all stages first
            if let stages = app.stages {
                for stage in stages {
                    modelContext.delete(stage)
                }
            }
            
            modelContext.delete(app)
        }
        
        // Clean up orphaned stages
        let stageDescriptor = FetchDescriptor<SDApplicationStage>(
            predicate: #Predicate { stage in
                stage.isDeleted == true && stage.needsSync == false
            }
        )
        
        let syncedDeletedStages = try modelContext.fetch(stageDescriptor)
        
        for stage in syncedDeletedStages {
            print("Permanently removing synced deleted stage: \(stage.stage.rawValue)")
            modelContext.delete(stage)
        }
        
        if !syncedDeletedApps.isEmpty || !syncedDeletedStages.isEmpty {
            try modelContext.save()
            print("Cleaned up \(syncedDeletedApps.count) apps and \(syncedDeletedStages.count) stages")
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
            // If app is marked for deletion locally, don't resurrect it from cloud
            if existingApp.isDeleted {
                print("Skipping cloud app - locally deleted: \(cloudId)")
                return
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
                // If stage is marked for deletion locally, don't resurrect it from cloud
                if existingStage.isDeleted {
                    print("Skipping cloud stage - locally deleted: \(cloudStageId)")
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
                    print("Updated local stage from cloud: \(cloudStage.stage.rawValue)")
                }
            } else {
                let newStage = SDApplicationStage.from(cloudStage)
                newStage.needsSync = false
                newStage.lastSyncedAt = Date()
                newStage.application = localApp
                modelContext.insert(newStage)
                print("Created new stage from cloud: \(cloudStage.stage.rawValue)")
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
            // Push deleted applications
            let appDescriptor = FetchDescriptor<SDApplication>(
                predicate: #Predicate { app in
                    app.isDeleted == true && app.needsSync == true
                }
            )
            
            let deletedApps = try modelContext.fetch(appDescriptor)
            
            for sdApp in deletedApps {
                if let firestoreId = sdApp.firestoreId {
                    try await firestoreRepo.deleteApplication(id: firestoreId, for: userId)
                    print("Deleted app from Firestore: \(sdApp.company)")
                }
                // Mark as synced (will be cleaned up later)
                sdApp.needsSync = false
                sdApp.lastSyncedAt = Date()
            }
            
            // Push deleted stages separately
            let stageDescriptor = FetchDescriptor<SDApplicationStage>(
                predicate: #Predicate { stage in
                    stage.isDeleted == true && stage.needsSync == true
                }
            )
            
            let deletedStages = try modelContext.fetch(stageDescriptor)
            
            for sdStage in deletedStages {
                if let firestoreId = sdStage.firestoreId,
                   let appFirestoreId = sdStage.application?.firestoreId ?? sdStage.application?.id {
                    try await firestoreRepo.deleteStage(
                        id: firestoreId,
                        for: appFirestoreId,
                        userId: userId
                    )
                    print("Deleted stage from Firestore: \(sdStage.stage.rawValue)")
                }
                // Mark as synced (will be cleaned up later)
                sdStage.needsSync = false
                sdStage.lastSyncedAt = Date()
            }
            
            try modelContext.save()
            
            // Immediately hard-delete after successful Firestore deletion
            // This prevents resurrection during the same sync cycle
            for sdApp in deletedApps {
                if let stages = sdApp.stages {
                    for stage in stages {
                        modelContext.delete(stage)
                    }
                }
                modelContext.delete(sdApp)
                print("Immediately hard-deleted app: \(sdApp.company)")
            }
            
            for sdStage in deletedStages {
                modelContext.delete(sdStage)
                print("Immediately hard-deleted stage: \(sdStage.stage.rawValue)")
            }
            
            if !deletedApps.isEmpty || !deletedStages.isEmpty {
                try modelContext.save()
            }
        } catch {
            print("Deletion push error: \(error)")
        }
    }
    
    private func pushApplication(_ sdApp: SDApplication, userId: String) async throws {
        let application = sdApp.toFSApplication()
        
        // Always check for existing cloud app before creating
        if sdApp.firestoreId == nil {
            print("Looking for existing cloud app: \(sdApp.company) - \(sdApp.role)")
            
            if let existingCloudApp = try await firestoreRepo.findApplication(
                company: sdApp.company,
                role: sdApp.role,
                date: sdApp.date,
                for: userId
            ) {
                print("Found existing cloud app, linking instead of creating: \(sdApp.company)")
                sdApp.firestoreId = existingCloudApp.id
                
                // Merge: use newer version
                if existingCloudApp.updatedAt.dateValue() > sdApp.updatedAt {
                    print("Cloud version is newer, updating local")
                    sdApp.role = existingCloudApp.role
                    sdApp.company = existingCloudApp.company
                    sdApp.date = existingCloudApp.date.dateValue()
                    sdApp.status = existingCloudApp.status
                    sdApp.starred = existingCloudApp.starred
                    sdApp.note = existingCloudApp.note
                    sdApp.updatedAt = existingCloudApp.updatedAt.dateValue()
                } else {
                    print("Local version is newer, will update cloud")
                }
            } else {
                print("No existing cloud app found, will create new")
            }
        }
        
        if sdApp.firestoreId != nil {
            try await firestoreRepo.updateApplication(application, for: userId)
            print("Updated app in Firestore: \(sdApp.company)")
        } else {
            let newId = try await firestoreRepo.createApplication(application, for: userId)
            sdApp.firestoreId = newId
            print("Created new app in Firestore: \(sdApp.company) (ID: \(newId))")
        }
        
        // Only process non-deleted stages
        for sdStage in sdApp.stages ?? [] where !sdStage.isDeleted {
            if sdStage.needsSync {
                try await pushStage(sdStage, applicationId: sdApp.firestoreId ?? sdApp.id, userId: userId)
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
