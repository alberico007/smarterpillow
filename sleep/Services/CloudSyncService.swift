//
//  CloudSyncService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Foundation
import CloudKit
import os

@Observable
final class CloudSyncService {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let lastSyncDate = "cloudSync_lastSyncDate"
    }

    // MARK: - Constants

    private static let containerID = "iCloud.smarter-pillow.sleep"
    private static let sessionRecordType = "SleepSession"
    private static let audioRecordType = "AudioRecording"
    private static let zoneName = "SleepDataZone"

    // MARK: - Observable State

    var isSyncing = false
    var lastSyncDate: Date? {
        didSet { UserDefaults.standard.set(lastSyncDate, forKey: Keys.lastSyncDate) }
    }
    var isCloudAvailable = false
    var syncError: String?

    // MARK: - Private

    private var _container: CKContainer?
    private var container: CKContainer? {
        if _container == nil, Self.hasCloudKitEntitlement {
            _container = CKContainer.default()
        }
        return _container
    }
    private var privateDatabase: CKDatabase? { container?.privateCloudDatabase }
    private let recordZoneID = CKRecordZone.ID(zoneName: "SleepDataZone", ownerName: CKCurrentUserDefaultName)

    /// Check if the app has the iCloud entitlement before touching CKContainer.
    /// CKContainer.default() triggers SIGTRAP if the entitlement is missing — cannot be caught.
    /// iCloud entitlement (com.apple.developer.icloud-container-identifiers) is not
    /// currently in sleep.entitlements. Re-enable when iCloud capability is added.
    private static var hasCloudKitEntitlement: Bool {
        return false
    }

    // MARK: - Init

    init() {
        self.lastSyncDate = UserDefaults.standard.object(forKey: Keys.lastSyncDate) as? Date
        // Only attempt setup if iCloud is available
        if Self.hasCloudKitEntitlement {
            Task { await setup() }
        } else {
            AppLogger.cloudSync.info("☁️ iCloud entitlement not present — cloud sync disabled")
        }
    }

    // MARK: - Setup

    private func setup() async {
        await checkCloudStatus()

        guard isCloudAvailable, let db = privateDatabase else { return }

        // Ensure custom zone exists
        do {
            let zone = CKRecordZone(zoneID: recordZoneID)
            _ = try await db.save(zone)
        } catch {
            // Zone may already exist, which is fine
            let ckError = error as? CKError
            if ckError?.code != .serverRecordChanged {
                AppLogger.cloudSync.error("Failed to create record zone: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Check Cloud Status

    func checkCloudStatus() async {
        guard let container = container else {
            await MainActor.run { isCloudAvailable = false }
            AppLogger.cloudSync.info("☁️ iCloud container not available (no entitlement)")
            return
        }
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                isCloudAvailable = (status == .available)
            }
        } catch {
            AppLogger.cloudSync.error("Failed to check iCloud account status: \(error.localizedDescription)")
            await MainActor.run { isCloudAvailable = false }
        }
    }

    // MARK: - Sync Sessions

    func syncSessions(_ sessions: [SleepSession]) async {
        AppLogger.cloudSync.info("☁️ Syncing \(sessions.count) sessions")
        guard isCloudAvailable, let privateDatabase = privateDatabase else {
            syncError = "iCloud is not available"
            return
        }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            // Fetch existing record IDs to avoid duplicates
            let existingIDs = try await fetchExistingSessionIDs()

            // Convert sessions to CKRecords, skipping already-synced ones
            var recordsToSave: [CKRecord] = []

            for session in sessions {
                let recordID = CKRecord.ID(
                    recordName: sessionRecordName(for: session),
                    zoneID: recordZoneID
                )

                if existingIDs.contains(recordID.recordName) { continue }

                let record = CKRecord(recordType: Self.sessionRecordType, recordID: recordID)
                record["startTime"] = session.startTime as CKRecordValue
                record["endTime"] = session.endTime as CKRecordValue
                record["qualityRating"] = session.qualityRating as CKRecordValue
                record["notes"] = session.notes as CKRecordValue
                record["durationSeconds"] = session.durationSeconds as CKRecordValue
                record["averageMovement"] = session.averageMovement as CKRecordValue
                record["snoringCount"] = session.snoringCount as CKRecordValue
                record["morningMood"] = session.morningMood as CKRecordValue
                record["sleepScore"] = session.sleepScore as CKRecordValue

                // Store encoded stage data if available
                if let stageData = session.stageData {
                    record["stageData"] = stageData as CKRecordValue
                }
                if let movementData = session.movementData {
                    record["movementData"] = movementData as CKRecordValue
                }
                if let snoringData = session.snoringData {
                    record["snoringData"] = snoringData as CKRecordValue
                }

                recordsToSave.append(record)
            }

            // Batch save using modify operation
            if !recordsToSave.isEmpty {
                let batchSize = 400 // CKModifyRecordsOperation limit
                for batchStart in stride(from: 0, to: recordsToSave.count, by: batchSize) {
                    let batchEnd = min(batchStart + batchSize, recordsToSave.count)
                    let batch = Array(recordsToSave[batchStart..<batchEnd])

                    let (saveResults, _) = try await privateDatabase.modifyRecords(
                        saving: batch,
                        deleting: [],
                        savePolicy: .changedKeys
                    )

                    // Check for individual record errors
                    for (_, result) in saveResults {
                        if case .failure(let error) = result {
                            AppLogger.cloudSync.error("Failed to save record: \(error.localizedDescription)")
                        }
                    }
                }
            }

            await MainActor.run {
                lastSyncDate = Date()
            }

        } catch {
            AppLogger.cloudSync.error("Cloud sync failed: \(error.localizedDescription)")
            await MainActor.run {
                syncError = error.localizedDescription
            }
        }
    }

    // MARK: - Backup Audio Recordings

    func backupAudioRecordings() async {
        guard isCloudAvailable, let privateDatabase = privateDatabase else { return }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            // Find local audio files
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            guard let audioDirectory = documentsURL?.appendingPathComponent("recordings") else { return }

            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: audioDirectory.path) else { return }

            let audioFiles = try fileManager.contentsOfDirectory(
                at: audioDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: .skipsHiddenFiles
            )

            for fileURL in audioFiles {
                let recordID = CKRecord.ID(
                    recordName: "audio_\(fileURL.lastPathComponent)",
                    zoneID: recordZoneID
                )

                let record = CKRecord(recordType: Self.audioRecordType, recordID: recordID)
                record["fileName"] = fileURL.lastPathComponent as CKRecordValue

                let asset = CKAsset(fileURL: fileURL)
                record["audioFile"] = asset

                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    record["recordingDate"] = creationDate as CKRecordValue
                }

                _ = try await privateDatabase.save(record)
            }

            await MainActor.run { lastSyncDate = Date() }

        } catch {
            AppLogger.cloudSync.error("Audio backup failed: \(error.localizedDescription)")
            await MainActor.run { syncError = error.localizedDescription }
        }
    }

    // MARK: - Restore From Cloud

    func restoreFromCloud() async -> [SleepSession] {
        guard isCloudAvailable, let privateDatabase = privateDatabase else { return [] }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        var restoredSessions: [SleepSession] = []

        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: Self.sessionRecordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

            let (results, _) = try await privateDatabase.records(
                matching: query,
                inZoneWith: recordZoneID,
                resultsLimit: CKQueryOperation.maximumResults
            )

            for (_, result) in results {
                if case .success(let record) = result {
                    if let session = sleepSession(from: record) {
                        restoredSessions.append(session)
                    }
                }
            }
        } catch {
            AppLogger.cloudSync.error("Cloud restore failed: \(error.localizedDescription)")
            await MainActor.run { syncError = error.localizedDescription }
        }

        return restoredSessions
    }

    // MARK: - Delete All Cloud Data

    func deleteAllCloudData() async {
        guard isCloudAvailable, let privateDatabase = privateDatabase else { return }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            // Delete the entire zone to remove all records at once
            _ = try await privateDatabase.modifyRecordZones(
                saving: [],
                deleting: [recordZoneID]
            )

            // Recreate the zone for future use
            let zone = CKRecordZone(zoneID: recordZoneID)
            _ = try await privateDatabase.save(zone)

            await MainActor.run {
                lastSyncDate = nil
            }
        } catch {
            AppLogger.cloudSync.error("Failed to delete cloud data: \(error.localizedDescription)")
            await MainActor.run { syncError = error.localizedDescription }
        }
    }

    // MARK: - Helpers

    private func sessionRecordName(for session: SleepSession) -> String {
        let timestamp = Int(session.startTime.timeIntervalSince1970)
        return "session_\(timestamp)"
    }

    private func fetchExistingSessionIDs() async throws -> Set<String> {
        guard let db = privateDatabase else { return [] }
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: Self.sessionRecordType, predicate: predicate)

        var existingIDs = Set<String>()

        let (results, _) = try await db.records(
            matching: query,
            inZoneWith: recordZoneID,
            desiredKeys: [],
            resultsLimit: CKQueryOperation.maximumResults
        )

        for (recordID, _) in results {
            existingIDs.insert(recordID.recordName)
        }

        return existingIDs
    }

    private func sleepSession(from record: CKRecord) -> SleepSession? {
        guard let startTime = record["startTime"] as? Date,
              let endTime = record["endTime"] as? Date else {
            return nil
        }

        let qualityRating = record["qualityRating"] as? Int ?? 3
        let quality = SleepQuality(rawValue: qualityRating) ?? .fair
        let notes = record["notes"] as? String ?? ""
        let morningMood = record["morningMood"] as? Int ?? 0

        var movementPoints: [MovementDataPoint] = []
        var snoringEvents: [SnoringEvent] = []
        var sleepStages: [SleepStageEntry] = []

        if let movementData = record["movementData"] as? Data {
            movementPoints = (try? JSONDecoder().decode([MovementDataPoint].self, from: movementData)) ?? []
        }
        if let snoringData = record["snoringData"] as? Data {
            snoringEvents = (try? JSONDecoder().decode([SnoringEvent].self, from: snoringData)) ?? []
        }
        if let stageData = record["stageData"] as? Data {
            sleepStages = (try? JSONDecoder().decode([SleepStageEntry].self, from: stageData)) ?? []
        }

        return SleepSession(
            startTime: startTime,
            endTime: endTime,
            quality: quality,
            notes: notes,
            movementPoints: movementPoints,
            snoringEvents: snoringEvents,
            sleepStages: sleepStages,
            morningMood: morningMood
        )
    }
}
