//
//  WatchModels.swift
//  sleepWatch
//
//  Lightweight copies of iPhone model structs for watch target.
//  JSON encoding must match SleepSession.swift exactly.

import SwiftUI

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

// MARK: - SleepStageEntry

struct SleepStageEntry: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var stage: SleepStageType
}
