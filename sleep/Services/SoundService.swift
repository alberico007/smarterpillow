//
//  SoundService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AVFoundation
import Foundation
import os
import SwiftData

// MARK: - SoundMixerSlot

struct SoundMixerSlot: Identifiable {
    let id: String
    var sound: SoundItem
    var volume: Float // 0.0 – 1.0
}

// MARK: - SoundService

@Observable
final class SoundService {

    // MARK: - Observable State

    var isPlaying = false
    var activeSlots: [SoundMixerSlot] = []
    var timerRemaining: TimeInterval = 0

    // MARK: - Private

    private var players: [String: AVAudioPlayer] = [:]
    private var countdownTimer: Timer?
    private let maxSlots = 4

    // MARK: - Session Configuration

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: - Add Sound

    func addSound(_ sound: SoundItem, volume: Float = 0.7) {
        guard activeSlots.count < maxSlots else { return }
        guard !activeSlots.contains(where: { $0.sound.id == sound.id }) else { return }

        let slot = SoundMixerSlot(id: sound.id, sound: sound, volume: volume)
        activeSlots.append(slot)
        AppLogger.sound.info("🔊 Added sound: \(sound.name)")

        // Create and prepare a looping player
        if let url = Bundle.main.url(forResource: sound.fileName, withExtension: "m4a", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "mp3", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "wav", subdirectory: "Sounds")
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "m4a")
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "mp3")
            ?? Bundle.main.url(forResource: sound.fileName, withExtension: "wav") {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1 // Loop forever
                player.volume = volume
                player.prepareToPlay()
                players[sound.id] = player
                if isPlaying { player.play() }
            } catch {
                AppLogger.sound.error("SoundService: failed to create player for \(sound.fileName): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Remove Sound

    func removeSound(id: String) {
        AppLogger.sound.info("🔊 Removed sound: \(id)")
        players[id]?.stop()
        players.removeValue(forKey: id)
        activeSlots.removeAll { $0.id == id }
        if activeSlots.isEmpty { stop() }
    }

    // MARK: - Update Volume

    func updateVolume(id: String, volume: Float) {
        if let idx = activeSlots.firstIndex(where: { $0.id == id }) {
            activeSlots[idx].volume = volume
        }
        players[id]?.volume = volume
    }

    // MARK: - Play / Pause / Stop

    func play(timerMinutes: Int = 0) {
        AppLogger.sound.info("🔊 Playing sound mix — timer: \(timerMinutes) minutes")
        configureAudioSession()
        isPlaying = true
        for player in players.values { player.play() }

        if timerMinutes > 0 {
            timerRemaining = TimeInterval(timerMinutes * 60)
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                Task { @MainActor [weak self] in
                    guard let self else { timer.invalidate(); return }
                    self.timerRemaining -= 1
                    if self.timerRemaining <= 0 {
                        timer.invalidate()
                        self.fadeOutAndStop()
                    }
                }
            }
        }
    }

    func pause() {
        isPlaying = false
        for player in players.values { player.pause() }
        countdownTimer?.invalidate()
    }

    func stop() {
        isPlaying = false
        timerRemaining = 0
        countdownTimer?.invalidate()
        for player in players.values { player.stop() }
    }

    func stopAndClear() {
        stop()
        players.removeAll()
        activeSlots.removeAll()
    }

    // MARK: - Presets

    func saveCurrentAsPreset(name: String, modelContext: ModelContext) {
        let items = activeSlots.map { SoundPresetItem(id: $0.sound.id, volume: $0.volume) }
        let preset = SoundPreset(name: name, items: items)
        modelContext.insert(preset)
        try? modelContext.save()
    }

    func loadPreset(_ preset: SoundPreset) {
        stopAndClear()
        for item in preset.items {
            if let sound = SoundLibrary.all.first(where: { $0.id == item.id }) {
                addSound(sound, volume: item.volume)
            }
        }
    }

    // MARK: - Fade out

    private func fadeOutAndStop() {
        let fadeDuration: TimeInterval = 10
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)

        for player in players.values {
            let startVolume = player.volume
            var step = 0

            Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
                step += 1
                let fraction = Float(step) / Float(steps)
                player.volume = startVolume * (1 - fraction)
                if step >= steps {
                    timer.invalidate()
                    Task { @MainActor [weak self] in
                        self?.stop()
                    }
                }
            }
        }
    }
}
