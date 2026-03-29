//
//  CloudSyncService.swift
//  sleep
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

@Observable
final class CloudSyncService {

    // MARK: - Observable State

    var isSyncing = false
    var lastSyncDate: Date?
    var isCloudAvailable = false
    var syncError: String?

    // MARK: - Private

    private var db: Firestore { Firestore.firestore() }
    private var currentUserID: String? { Auth.auth().currentUser?.uid }

    // MARK: - Init

    init() {
        // Firebase must be configured before Auth or Firestore are accessed.
        // checkCloudStatus() is called from sleepApp after FirebaseApp.configure().
    }

    // MARK: - Sync Sessions

    func syncSessions(_ sessions: [SleepSession]) async {
        guard let uid = currentUserID else {
            syncError = "Not signed in"
            return
        }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        let sessionsRef = db
            .collection("users")
            .document(uid)
            .collection("sleep_sessions")

        do {
            for session in sessions {
                let docID = "session_\(Int(session.startTime.timeIntervalSince1970))"
                let docRef = sessionsRef.document(docID)

                var data: [String: Any] = [
                    "startTime": Timestamp(date: session.startTime),
                    "endTime": Timestamp(date: session.endTime),
                    "qualityRating": session.qualityRating,
                    "notes": session.notes,
                    "durationSeconds": session.durationSeconds,
                    "averageMovement": session.averageMovement,
                    "snoringCount": session.snoringCount,
                    "morningMood": session.morningMood,
                    "sleepScore": session.sleepScore,
                    "syncedAt": Timestamp(date: Date()),
                    "platform": "ios"
                ]

                if let stageData = session.stageData {
                    data["stageData"] = stageData.base64EncodedString()
                }
                if let movementData = session.movementData {
                    data["movementData"] = movementData.base64EncodedString()
                }
                if let snoringData = session.snoringData {
                    data["snoringData"] = snoringData.base64EncodedString()
                }

                try await docRef.setData(data, merge: true)
            }

            try await db.collection("users").document(uid).setData([
                "lastSynced": Timestamp(date: Date()),
                "platform": "ios"
            ], merge: true)

            await MainActor.run { lastSyncDate = Date() }
            AppLogger.appEvent("Synced \(sessions.count) sessions to Firestore")

        } catch {
            AppLogger.error("Firestore sync failed", error: error)
            await MainActor.run { syncError = error.localizedDescription }
        }
    }

    // MARK: - Restore From Cloud

    func restoreFromCloud() async -> [SleepSession] {
        guard let uid = currentUserID else {
            syncError = "Not signed in"
            return []
        }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("sleep_sessions")
                .order(by: "startTime", descending: true)
                .getDocuments()

            let sessions = snapshot.documents.compactMap { sleepSession(from: $0.data()) }
            AppLogger.appEvent("Restored \(sessions.count) sessions from Firestore")
            return sessions

        } catch {
            AppLogger.error("Firestore restore failed", error: error)
            await MainActor.run { syncError = error.localizedDescription }
            return []
        }
    }

    // MARK: - Check Cloud Status

    func checkCloudStatus() async {
        await MainActor.run {
            isCloudAvailable = Auth.auth().currentUser != nil
        }
    }

    // MARK: - Delete All Cloud Data

    func deleteAllCloudData() async {
        guard let uid = currentUserID else { return }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        defer { Task { @MainActor in isSyncing = false } }

        do {
            let snapshot = try await db
                .collection("users")
                .document(uid)
                .collection("sleep_sessions")
                .getDocuments()

            for doc in snapshot.documents {
                try await doc.reference.delete()
            }

            await MainActor.run { lastSyncDate = nil }
            AppLogger.appEvent("🗑️ Deleted all Firestore sleep sessions")

        } catch {
            AppLogger.error("Firestore delete failed", error: error)
            await MainActor.run { syncError = error.localizedDescription }
        }
    }

    // MARK: - Audio (not supported in Firestore — skipped)

    func backupAudioRecordings() async {
        AppLogger.appEvent("Audio backup not implemented for Firestore")
    }

    // MARK: - Helper

    private func sleepSession(from data: [String: Any]) -> SleepSession? {
        guard let startTimestamp = data["startTime"] as? Timestamp,
              let endTimestamp = data["endTime"] as? Timestamp else { return nil }

        let startTime = startTimestamp.dateValue()
        let endTime = endTimestamp.dateValue()
        let qualityRating = data["qualityRating"] as? Int ?? 3
        let quality = SleepQuality(rawValue: qualityRating) ?? .fair
        let notes = data["notes"] as? String ?? ""
        let morningMood = data["morningMood"] as? Int ?? 0

        var movementPoints: [MovementDataPoint] = []
        var snoringEvents: [SnoringEvent] = []
        var sleepStages: [SleepStageEntry] = []

        if let movementStr = data["movementData"] as? String,
           let movementData = Data(base64Encoded: movementStr) {
            movementPoints = (try? JSONDecoder().decode([MovementDataPoint].self,
                                                        from: movementData)) ?? []
        }
        if let snoringStr = data["snoringData"] as? String,
           let snoringData = Data(base64Encoded: snoringStr) {
            snoringEvents = (try? JSONDecoder().decode([SnoringEvent].self,
                                                       from: snoringData)) ?? []
        }
        if let stageStr = data["stageData"] as? String,
           let stageData = Data(base64Encoded: stageStr) {
            sleepStages = (try? JSONDecoder().decode([SleepStageEntry].self,
                                                     from: stageData)) ?? []
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
