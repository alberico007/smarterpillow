//
//  AudioService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AVFoundation
import Accelerate
import Foundation
import os

// MARK: - Audio Analysis Result (produced off main thread)

private struct AudioAnalysis: Sendable {
    let amplitude: Double
    let snoringBandRatio: Double // energy in 100-500Hz vs total
    let sampleRate: Double
}

@Observable
final class AudioService {
    var isTracking = false
    var currentAmplitude: Double = 0.0
    var snoringBandEnergy: Double = 0.0
    var snoringEvents: [SnoringEvent] = []

    // Adaptive baseline
    private var ambientBaseline: Double = 0.0
    private var baselineSamples: [Double] = []
    private var baselineCalibrated = false
    private let baselineCalibrationSeconds: TimeInterval = 15
    private var trackingStartTime: Date?

    // Configurable thresholds — set via configure(settings:)
    private var relativeThresholdMultiplier: Double = 1.8
    private var absoluteMinimumThreshold: Double = 0.015
    private var minimumSnoringBandRatio: Double = 0.20
    private var minimumBurstDuration: TimeInterval = 0.8

    // Burst detection
    private var recentBursts: [(time: Date, duration: TimeInterval, amplitude: Double)] = []
    private let burstGroupingWindow: TimeInterval = 30.0
    private let burstsRequiredForEvent: Int = 1

    private var burstStartTime: Date?
    private var burstAmplitudes: [Double] = []

    private var audioEngine: AVAudioEngine?

    // Snoring clip recording via buffer capture (avoids AVAudioRecorder/AVAudioEngine conflict)
    private var audioBufferRing: [AVAudioPCMBuffer] = []
    private var audioBufferFormat: AVAudioFormat?
    private let maxBufferSeconds: Int = 15 // keep last 15 seconds
    private var isRecordingClip = false

    /// Configure detection thresholds from user settings
    func configure(sensitivity: Double, minDuration: Double) {
        // sensitivity: 0.0 = very sensitive, 1.0 = least sensitive
        relativeThresholdMultiplier = 1.3 + (sensitivity * 1.7) // 1.3 to 3.0
        minimumSnoringBandRatio = 0.15 + (sensitivity * 0.20)   // 0.15 to 0.35
        absoluteMinimumThreshold = 0.01 + (sensitivity * 0.02)  // 0.01 to 0.03
        minimumBurstDuration = minDuration
        AppLogger.audio.info("🎙️ Snoring thresholds — multiplier: \(self.relativeThresholdMultiplier), bandRatio: \(self.minimumSnoringBandRatio), minDuration: \(minDuration)")
    }

    func startTracking() {
        guard !isTracking else { return }
        snoringEvents = []
        recentBursts = []
        burstStartTime = nil
        burstAmplitudes = []
        ambientBaseline = 0.0
        baselineSamples = []
        baselineCalibrated = false
        trackingStartTime = Date()

        configureAudioSession()

        let engine = AVAudioEngine()
        self.audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        audioBufferFormat = format
        audioBufferRing = []

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable [weak self] buffer, _ in
            let analysis = Self.analyzeBuffer(buffer: buffer, sampleRate: format.sampleRate)
            // Copy buffer for snoring clip recording
            let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength)
            if let copy {
                copy.frameLength = buffer.frameLength
                if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
                    for ch in 0..<Int(buffer.format.channelCount) {
                        dst[ch].update(from: src[ch], count: Int(buffer.frameLength))
                    }
                }
            }
            Task { @MainActor [weak self] in
                self?.processAnalysis(analysis)
                if let copy { self?.appendBuffer(copy) }
            }
        }

        do {
            try engine.start()
            isTracking = true
            AppLogger.audio.info("🎙️ Audio tracking started")
        } catch {
            AppLogger.audio.error("Audio engine failed to start: \(error.localizedDescription)")
        }
    }

    func stopTracking() {
        AppLogger.audio.info("🎙️ Audio tracking stopped")
        finalizeBurst()
        flushBurstsToEvent()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isTracking = false
        currentAmplitude = 0
        snoringBandEnergy = 0
    }

    // MARK: - Static Analysis (runs on background thread)

    nonisolated private static func analyzeBuffer(buffer: AVAudioPCMBuffer, sampleRate: Double) -> AudioAnalysis {
        guard let channelData = buffer.floatChannelData else {
            return AudioAnalysis(amplitude: 0, snoringBandRatio: 0, sampleRate: sampleRate)
        }
        let frameCount = Int(buffer.frameLength)
        let data = channelData[0]
        var rms: Float = 0
        vDSP_rmsqv(data, 1, &rms, vDSP_Length(frameCount))
        let amplitude = Double(rms)
        let snoringBandRatio = computeSnoringBandRatio(data: data, frameCount: frameCount, sampleRate: sampleRate)
        return AudioAnalysis(amplitude: amplitude, snoringBandRatio: snoringBandRatio, sampleRate: sampleRate)
    }

    nonisolated private static func computeSnoringBandRatio(data: UnsafeMutablePointer<Float>, frameCount: Int, sampleRate: Double) -> Double {
        let log2n = vDSP_Length(floor(log2(Double(frameCount))))
        let fftSize = Int(1 << log2n)
        guard fftSize >= 256 else { return 0 }
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return 0 }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realPart = [Float](repeating: 0, count: fftSize / 2)
        var imagPart = [Float](repeating: 0, count: fftSize / 2)
        var windowedData = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(data, 1, &window, 1, &windowedData, 1, vDSP_Length(fftSize))

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)

        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                windowedData.withUnsafeMutableBufferPointer { bufferPtr in
                    bufferPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        let freqPerBin = sampleRate / Double(fftSize)
        let lowBin = max(1, Int(100.0 / freqPerBin))
        let highBin = min(fftSize / 2 - 1, Int(500.0 / freqPerBin))

        var totalEnergy: Float = 0
        vDSP_sve(magnitudes, 1, &totalEnergy, vDSP_Length(magnitudes.count))
        guard totalEnergy > 0 else { return 0 }

        var bandEnergy: Float = 0
        let bandLength = highBin - lowBin + 1
        guard bandLength > 0 else { return 0 }
        magnitudes.withUnsafeBufferPointer { ptr in
            let bandPtr = ptr.baseAddress! + lowBin
            vDSP_sve(bandPtr, 1, &bandEnergy, vDSP_Length(bandLength))
        }
        return Double(bandEnergy / totalEnergy)
    }

    // MARK: - Main Actor Processing

    private func processAnalysis(_ analysis: AudioAnalysis) {
        currentAmplitude = analysis.amplitude
        snoringBandEnergy = analysis.snoringBandRatio
        updateBaseline(amplitude: analysis.amplitude, snoringBandRatio: analysis.snoringBandRatio)
        let isSnoringSound = detectSnoring(amplitude: analysis.amplitude, snoringBandRatio: analysis.snoringBandRatio)
        if isSnoringSound {
            if burstStartTime == nil {
                burstStartTime = Date()
                burstAmplitudes = []
            }
            burstAmplitudes.append(analysis.amplitude)
        } else {
            finalizeBurst()
        }
    }

    private func updateBaseline(amplitude: Double, snoringBandRatio: Double) {
        guard let start = trackingStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        if !baselineCalibrated {
            if snoringBandRatio < 0.25 { baselineSamples.append(amplitude) }
            if elapsed >= baselineCalibrationSeconds {
                if baselineSamples.isEmpty {
                    ambientBaseline = 0.01
                } else {
                    let sorted = baselineSamples.sorted()
                    ambientBaseline = sorted[sorted.count / 2]
                }
                baselineCalibrated = true
            }
        } else {
            if amplitude < ambientBaseline * 1.5 && snoringBandRatio < 0.25 {
                ambientBaseline = ambientBaseline * 0.995 + amplitude * 0.005
            }
        }
    }

    private func detectSnoring(amplitude: Double, snoringBandRatio: Double) -> Bool {
        let adaptiveThreshold = max(ambientBaseline * relativeThresholdMultiplier, absoluteMinimumThreshold)
        guard amplitude >= adaptiveThreshold else { return false }
        guard snoringBandRatio >= minimumSnoringBandRatio else { return false }
        return true
    }

    private func finalizeBurst() {
        guard let start = burstStartTime else { return }
        let duration = Date().timeIntervalSince(start)
        if duration >= minimumBurstDuration && !burstAmplitudes.isEmpty {
            let avgAmplitude = burstAmplitudes.reduce(0, +) / Double(burstAmplitudes.count)
            recentBursts.append((time: start, duration: duration, amplitude: avgAmplitude))
            checkForSnoringEvent()
        }
        burstStartTime = nil
        burstAmplitudes = []
    }

    private func checkForSnoringEvent() {
        let cutoff = Date().addingTimeInterval(-burstGroupingWindow)
        recentBursts.removeAll { $0.time < cutoff }
        if recentBursts.count >= burstsRequiredForEvent { flushBurstsToEvent() }
    }

    private func flushBurstsToEvent() {
        guard !recentBursts.isEmpty else { return }
        let cutoff = Date().addingTimeInterval(-burstGroupingWindow)
        let windowBursts = recentBursts.filter { $0.time >= cutoff }
        guard windowBursts.count >= burstsRequiredForEvent || !isTracking else { return }
        guard !windowBursts.isEmpty else { return }
        let eventStart = windowBursts.first!.time
        let eventEnd = windowBursts.last!.time.addingTimeInterval(windowBursts.last!.duration)
        let totalDuration = eventEnd.timeIntervalSince(eventStart)
        let avgAmplitude = windowBursts.reduce(0.0) { $0 + $1.amplitude } / Double(windowBursts.count)
        let event = SnoringEvent(startTime: eventStart, duration: totalDuration, averageAmplitude: avgAmplitude)
        snoringEvents.append(event)
        AppLogger.audio.notice("😴 Snoring event detected — amplitude: \(avgAmplitude), duration: \(totalDuration)")
        recentBursts.removeAll()

        // Record a 10-second clip of the snoring
        recordSnoringClip(for: event)
    }

    // MARK: - Buffer Ring Management

    private func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        audioBufferRing.append(buffer)
        // Keep only last ~15 seconds of buffers (44100 sample rate / 4096 buffer = ~10.7 buffers/sec)
        let maxBuffers = maxBufferSeconds * 11
        if audioBufferRing.count > maxBuffers {
            audioBufferRing.removeFirst(audioBufferRing.count - maxBuffers)
        }
    }

    // MARK: - Snoring Clip Recording

    private func recordSnoringClip(for event: SnoringEvent) {
        guard !isRecordingClip, !audioBufferRing.isEmpty, let format = audioBufferFormat else { return }
        isRecordingClip = true

        let clipsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnoringClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: clipsDir, withIntermediateDirectories: true)

        let fileName = "snore_\(Int(event.startTime.timeIntervalSince1970)).wav"
        let fileURL = clipsDir.appendingPathComponent(fileName)

        // Write buffered audio to file
        do {
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            for buffer in audioBufferRing {
                try audioFile.write(from: buffer)
            }
            let bufferCount = self.audioBufferRing.count
            AppLogger.audio.info("🎙️ Snoring clip saved: \(fileName) (\(bufferCount) buffers)")

            // Update the last event with the file URL
            if let lastIdx = snoringEvents.indices.last {
                snoringEvents[lastIdx].audioFileURL = fileURL
            }
        } catch {
            AppLogger.audio.error("🎙️ Failed to save snoring clip: \(error.localizedDescription)")
        }

        isRecordingClip = false
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            AppLogger.audio.error("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
}
