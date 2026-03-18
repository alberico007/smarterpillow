//
//  ActiveTrackingView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct ActiveTrackingView: View {

    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(SoundService.self) private var soundService
    @Environment(SleepSettings.self) private var settings
    @State private var showingSoundPicker = false
    @State private var soundTimerMinutes: Int = 30

    private var batteryService: BatteryService {
        trackingService.batteryService
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Elapsed time
                    Text(FormatHelpers.elapsedTime(trackingService.elapsedTime))
                        .font(.system(size: 56, weight: .thin, design: .monospaced))
                        .foregroundStyle(.cyan)

                    Text("Tracking Sleep")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Battery warning
                    if batteryService.warningLevel != .normal {
                        BatteryWarningBanner(warningLevel: batteryService.warningLevel)
                    }

                    // Sleep sounds player
                    SleepSoundBar(
                        soundService: soundService,
                        timerMinutes: $soundTimerMinutes,
                        showingSoundPicker: $showingSoundPicker
                    )

                    // Motion level
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "move.3d")
                                    .foregroundStyle(.green)
                                Text("Motion Level")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.3f", trackingService.motionService.currentIntensity))
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: min(trackingService.motionService.currentIntensity, 1.0))
                                .tint(.green)
                        }
                    }

                    // Audio level
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.yellow)
                                Text("Audio Level")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.3f", trackingService.audioService.currentAmplitude))
                                    .font(.subheadline.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: min(trackingService.audioService.currentAmplitude, 1.0))
                                .tint(.yellow)
                        }
                    }

                    // Snoring events counter
                    GlassCard {
                        HStack {
                            Image(systemName: "zzz")
                                .foregroundStyle(.purple)
                            Text("Snoring Events")
                                .font(.subheadline)
                            Spacer()
                            Text("\(trackingService.audioService.snoringEvents.count)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                        }
                    }

                    // Stop button
                    GlassButton(title: "Wake Up", icon: "stop.fill") {
                        soundService.stopAndClear()
                        trackingService.stopTracking()
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
            .sheet(isPresented: $showingSoundPicker) {
                NavigationStack {
                    SoundMixerView()
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }

            // Smart alarm overlay
            if trackingService.smartAlarmService.alarmTriggered {
                SmartAlarmOverlay()
            }
        }
    }
}

// MARK: - Battery Warning Banner

private struct BatteryWarningBanner: View {

    let warningLevel: BatteryWarningLevel

    private var bannerColor: Color {
        switch warningLevel {
        case .normal: .clear
        case .low: .orange
        case .critical: .red
        }
    }

    private var message: String {
        switch warningLevel {
        case .normal: ""
        case .low: "Low battery. Plug in to ensure uninterrupted tracking."
        case .critical: "Critical battery! Tracking may stop soon."
        }
    }

    var body: some View {
        HStack {
            Image(systemName: "battery.25percent")
                .foregroundStyle(bannerColor)
            Text(message)
                .font(.caption)
                .foregroundStyle(bannerColor)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(bannerColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Smart Alarm Overlay

private struct SmartAlarmOverlay: View {

    @Environment(SleepTrackingService.self) private var trackingService

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Smart Alarm")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Optimal wake-up time detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 20) {
                    Button {
                        trackingService.smartAlarmService.snooze(minutes: 5)
                    } label: {
                        Text("Snooze")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        trackingService.smartAlarmService.dismiss()
                        trackingService.stopTracking()
                    } label: {
                        Text("Dismiss")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal)

                Button {
                    trackingService.smartAlarmService.continueSleeping()
                } label: {
                    Text("Continue Sleeping")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}

// MARK: - Sleep Sound Bar

private struct SleepSoundBar: View {

    let soundService: SoundService
    @Binding var timerMinutes: Int
    @Binding var showingSoundPicker: Bool

    private let timerOptions = [15, 30, 45, 60, 0] // 0 = all night

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(.cyan)
                    Text("Sleep Sounds")
                        .font(.subheadline)
                    Spacer()
                    Button {
                        showingSoundPicker = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    }
                }

                if soundService.activeSlots.isEmpty {
                    Text("Tap + to add a sleep sound")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    // Active sounds
                    ForEach(soundService.activeSlots) { slot in
                        HStack {
                            Image(systemName: slot.sound.icon)
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text(slot.sound.name)
                                .font(.caption)
                            Spacer()
                            Button {
                                soundService.removeSound(id: slot.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Timer picker
                    HStack {
                        Text("Timer:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(timerOptions, id: \.self) { mins in
                            Button {
                                timerMinutes = mins
                            } label: {
                                Text(mins == 0 ? "All Night" : "\(mins)m")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(timerMinutes == mins ? Color.cyan : Color.clear)
                                    .background(.ultraThinMaterial)
                                    .foregroundStyle(timerMinutes == mins ? .white : .secondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    // Play/Stop
                    HStack(spacing: 16) {
                        if soundService.isPlaying {
                            Button {
                                soundService.stop()
                            } label: {
                                Label("Stop", systemImage: "stop.fill")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            if soundService.timerRemaining > 0 {
                                Text(FormatHelpers.elapsedTime(soundService.timerRemaining))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                soundService.play(timerMinutes: timerMinutes)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(.cyan)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }
}
