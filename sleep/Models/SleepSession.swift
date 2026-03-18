//
//  SleepSession.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/16/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - SleepQuality

enum SleepQuality: Int, Codable, CaseIterable, Identifiable {
    case veryPoor = 1
    case poor = 2
    case fair = 3
    case good = 4
    case excellent = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .veryPoor: "Very Poor"
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .excellent: "Excellent"
        }
    }

    var icon: String {
        switch self {
        case .veryPoor: "star"
        case .poor: "star.leadinghalf.filled"
        case .fair: "star.fill"
        case .good: "star.fill"
        case .excellent: "star.fill"
        }
    }

    var starCount: Int { rawValue }
}

// MARK: - SleepStageType

enum SleepStageType: String, Codable, CaseIterable, Identifiable {
    case awake
    case light
    case deep
    case rem

    var id: String { rawValue }

    var label: String {
        switch self {
        case .awake: "Awake"
        case .light: "Light"
        case .deep: "Deep"
        case .rem: "REM"
        }
    }

    var color: Color {
        switch self {
        case .awake: .orange
        case .light: .cyan
        case .deep: .indigo
        case .rem: .purple
        }
    }
}

// MARK: - MovementDataPoint

struct MovementDataPoint: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var timestamp: Date
    var intensity: Double
}

// MARK: - SnoringEvent

struct SnoringEvent: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var startTime: Date
    var duration: TimeInterval
    var averageAmplitude: Double
    var audioFileURL: URL?
}

// MARK: - SleepStageEntry

struct SleepStageEntry: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var stage: SleepStageType
}

// MARK: - SleepSession

@Model
final class SleepSession {
    var startTime: Date
    var endTime: Date
    var qualityRating: Int
    var notes: String
    var syncedToHealthKit: Bool

    // JSON-encoded blob storage
    var movementData: Data?
    var snoringData: Data?
    var stageData: Data?

    // Summary scalars for efficient @Query sorting/filtering
    var durationSeconds: Double
    var averageMovement: Double
    var snoringCount: Int

    // Morning mood (1-5 scale, 0 = not set)
    var morningMood: Int

    // Sleep onset latency (seconds from session start to first non-awake stage)
    var onsetLatencySeconds: Double

    var onsetLatencyFormatted: String {
        if onsetLatencySeconds <= 0 { return "N/A" }
        let minutes = Int(onsetLatencySeconds / 60)
        if minutes < 1 { return "<1 min" }
        return "\(minutes) min"
    }

    // MARK: Computed - Quality

    var quality: SleepQuality {
        get { SleepQuality(rawValue: qualityRating) ?? .fair }
        set { qualityRating = newValue.rawValue }
    }

    // MARK: Computed - Movement points

    var movementPoints: [MovementDataPoint] {
        get {
            guard let data = movementData else { return [] }
            return (try? JSONDecoder().decode([MovementDataPoint].self, from: data)) ?? []
        }
        set {
            movementData = try? JSONEncoder().encode(newValue)
            averageMovement = newValue.isEmpty ? 0 : newValue.map(\.intensity).reduce(0, +) / Double(newValue.count)
        }
    }

    // MARK: Computed - Snoring events

    var snoringEvents: [SnoringEvent] {
        get {
            guard let data = snoringData else { return [] }
            return (try? JSONDecoder().decode([SnoringEvent].self, from: data)) ?? []
        }
        set {
            snoringData = try? JSONEncoder().encode(newValue)
            snoringCount = newValue.count
        }
    }

    // MARK: Computed - Sleep stages

    var sleepStages: [SleepStageEntry] {
        get {
            guard let data = stageData else { return [] }
            return (try? JSONDecoder().decode([SleepStageEntry].self, from: data)) ?? []
        }
        set {
            stageData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: Computed - Sleep Score (0-100)

    var sleepScore: Int {
        var score: Double = 0

        // Duration component (max 35 points) — ideal 7-9 hours
        let hours = durationSeconds / 3600.0
        if hours >= 7 && hours <= 9 {
            score += 35
        } else if hours >= 6 && hours < 7 {
            score += 25
        } else if hours > 9 && hours <= 10 {
            score += 28
        } else if hours >= 5 && hours < 6 {
            score += 15
        } else {
            score += max(0, 10 - abs(hours - 8) * 2)
        }

        // Quality component (max 30 points)
        score += Double(qualityRating) / 5.0 * 30.0

        // Movement component (max 20 points) — lower is better
        let movementScore = max(0, 20 - averageMovement * 40)
        score += movementScore

        // Snoring component (max 15 points) — fewer is better
        let snoringPenalty = min(15, Double(snoringCount) * 3)
        score += 15 - snoringPenalty

        return max(0, min(100, Int(score.rounded())))
    }

    // MARK: Init

    // MARK: Computed - Sleep Efficiency

    var sleepEfficiency: Double {
        let totalInBed = durationSeconds
        guard totalInBed > 0 else { return 0 }
        let awakeTime = sleepStages.filter { $0.stage == .awake }
            .reduce(0.0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
        let asleepTime = totalInBed - awakeTime
        return asleepTime / totalInBed
    }

    // MARK: Computed - Awakenings count

    var awakeningCount: Int {
        let stages = sleepStages
        guard stages.count > 1 else { return 0 }
        var count = 0
        for i in 1..<stages.count where stages[i].stage == .awake && stages[i - 1].stage != .awake {
            count += 1
        }
        return count
    }

    // MARK: Init

    init(
        startTime: Date,
        endTime: Date,
        quality: SleepQuality = .fair,
        notes: String = "",
        syncedToHealthKit: Bool = false,
        movementPoints: [MovementDataPoint] = [],
        snoringEvents: [SnoringEvent] = [],
        sleepStages: [SleepStageEntry] = [],
        morningMood: Int = 0,
        onsetLatencySeconds: Double = 0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.qualityRating = quality.rawValue
        self.notes = notes
        self.syncedToHealthKit = syncedToHealthKit
        self.durationSeconds = endTime.timeIntervalSince(startTime)
        self.averageMovement = movementPoints.isEmpty
            ? 0
            : movementPoints.map(\.intensity).reduce(0, +) / Double(movementPoints.count)
        self.snoringCount = snoringEvents.count
        self.morningMood = morningMood
        self.onsetLatencySeconds = onsetLatencySeconds

        self.movementData = movementPoints.isEmpty ? nil : try? JSONEncoder().encode(movementPoints)
        self.snoringData = snoringEvents.isEmpty ? nil : try? JSONEncoder().encode(snoringEvents)
        self.stageData = sleepStages.isEmpty ? nil : try? JSONEncoder().encode(sleepStages)
    }
}
