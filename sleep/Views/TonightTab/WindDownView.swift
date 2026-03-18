//
//  WindDownView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct WindDownView: View {

    @Environment(SleepSettings.self) private var settings
    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(SoundService.self) private var soundService

    @State private var showingSoundMixer = false
    @State private var showingFactorLog = false

    private var timeUntilBed: TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        let bedtime = settings.scheduledBedtime
        var components = calendar.dateComponents([.hour, .minute], from: bedtime)
        var target = calendar.date(bySettingHour: components.hour ?? 23, minute: components.minute ?? 0, second: 0, of: now)!
        if target < now { target = calendar.date(byAdding: .day, value: 1, to: target)! }
        return target.timeIntervalSince(now)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Bedtime countdown
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.title)
                            .foregroundStyle(.indigo)

                        Text("Bedtime in")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(FormatHelpers.duration(max(0, timeUntilBed)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        Text("Scheduled: \(FormatHelpers.timeOfDay(settings.scheduledBedtime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Sound content carousel
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Sleep Sounds", systemImage: "waveform")
                                .font(.headline)
                            Spacer()
                            Button("Mixer") { showingSoundMixer = true }
                                .font(.caption)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(SoundLibrary.free()) { sound in
                                    SoundChip(sound: sound, isPlaying: soundService.activeSlots.contains(where: { $0.sound.id == sound.id })) {
                                        if soundService.activeSlots.contains(where: { $0.sound.id == sound.id }) {
                                            soundService.removeSound(id: sound.id)
                                        } else {
                                            soundService.addSound(sound)
                                            soundService.play()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Guided Meditations
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Meditations", systemImage: "brain.head.profile.fill")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(SoundLibrary.meditation().prefix(8)) { item in
                                    SoundChip(sound: item)
                                }
                            }
                        }

                        Text("Guided breathing, body scan, and relaxation exercises")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Sleep Stories
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Sleep Stories", systemImage: "book.fill")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(SoundLibrary.stories().prefix(8)) { item in
                                    SoundChip(sound: item)
                                }
                            }
                        }

                        Text("Narrated calming stories to help you drift off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Pre-sleep factor log
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Log Pre-Sleep Factors", systemImage: "list.bullet.clipboard.fill")
                            .font(.headline)

                        Text("What might affect your sleep tonight?")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            showingFactorLog = true
                        } label: {
                            Label("Log Factors", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Start tracking button
                GlassButton(title: "Start Sleep Tracking", icon: "play.fill") {
                    trackingService.startTracking()
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingSoundMixer) {
            SoundMixerView()
        }
        .sheet(isPresented: $showingFactorLog) {
            FactorLoggingView()
        }
    }
}

// MARK: - SoundChip

private struct SoundChip: View {

    let sound: SoundItem
    var isPlaying: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: sound.icon)
                    .font(.title2)
                    .foregroundStyle(isPlaying ? .white : .cyan)
                    .frame(width: 56, height: 56)
                    .background(isPlaying ? Color.cyan : Color.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isPlaying ? Color.cyan : Color.clear, lineWidth: 2)
                    )

                Text(sound.name)
                    .font(.caption2)
                    .foregroundStyle(isPlaying ? .cyan : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}
