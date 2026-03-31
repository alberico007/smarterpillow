//
//  SoundPreset.swift
//  sleep
//
//

import Foundation
import SwiftData

// MARK: - SoundPreset

@Model
final class SoundPreset {
    var name: String
    var soundConfigs: Data? // JSON encoded [SoundPresetItem]
    var createdAt: Date

    // MARK: - Computed Properties

    var items: [SoundPresetItem] {
        get {
            guard let data = soundConfigs else { return [] }
            return (try? JSONDecoder().decode([SoundPresetItem].self, from: data)) ?? []
        }
        set {
            soundConfigs = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Init

    init(name: String, items: [SoundPresetItem] = []) {
        self.name = name
        self.createdAt = Date()
        self.soundConfigs = try? JSONEncoder().encode(items)
    }
}

// MARK: - SoundPresetItem

struct SoundPresetItem: Codable, Identifiable {
    var id: String // sound ID
    var volume: Float
}
