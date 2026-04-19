//
//  AudioService.swift
//  sleep
//
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

    /// Optional environmental-sound classifier. When set, each candidate
    /// snoring event is cross-checked — events overlapping with fan/AC/dog/
    /// speech detections are suppressed. Inject via `attachClassifier`.
    private(set) weak var classifier: SoundClassificationService?

    /// When this reports `isPlaying == true` we ignore any candidate
    /// snoring event — the mic is hearing our own Apple Music / podcast
    /// playback bleed, not the sleeper. Set via `attachMediaPlayback`.
    private(set) weak var mediaPlayback: MediaPlaybackService?

    /// Whether the user has enabled environmental filtering in Settings.
    /// Set at tracking start from SleepSettings.environmentalNoiseFilteringEnabled.
    var environmentalFilteringEnabled: Bool = true

    /// Configure detection thresholds from user settings
    func configure(sensitivity: Double, minDuration: Double) {
        // sensitivity: 0.0 = very sensitive, 1.0 = least sensitive.
        // Band ratio thresholds loosened because the snore band is now
        // 80–900Hz (wider) and the classifier already filters out most
        // non-snore noise; we don't need the FFT to be a second-gate.
        relativeThresholdMultiplier = 1.3 + (sensitivity * 1.4) // 1.3 to 2.7
        minimumSnoringBandRatio = 0.10 + (sensitivity * 0.15)   // 0.10 to 0.25
        absoluteMinimumThreshold = 0.008 + (sensitivity * 0.02) // 0.008 to 0.028
        minimumBurstDuration = minDuration
        AppLogger.audio.info("🎙️ Snoring thresholds — multiplier: \(self.relativeThresholdMultiplier), bandRatio: \(self.minimumSnoringBandRatio), minAmp: \(self.absoluteMinimumThreshold), minDuration: \(minDuration)")
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

        // Attach environmental classifier before starting the engine so the
        // first buffers flow through both the FFT analyzer and SoundAnalysis.
        classifier?.attach(to: engine)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { @Sendable [weak self] buffer, time in
            let analysis = Self.analyzeBuffer(buffer: buffer, sampleRate: format.sampleRate)
            // Hand the same buffer to the environmental classifier. The
            // classifier runs off the main thread; it only reads the buffer.
            self?.classifier?.analyze(buffer, at: time)
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

    /// Inject the environmental-noise classifier. Call before `startTracking`.
    func attachClassifier(_ classifier: SoundClassificationService) {
        self.classifier = classifier
    }

    /// Inject the MediaPlaybackService so we can suppress snoring events
    /// while the user's chosen sleep audio is actively playing. Call once at
    /// app startup — this is a weak reference so it won't leak.
    func attachMediaPlayback(_ service: MediaPlaybackService) {
        self.mediaPlayback = service
    }

    func stopTracking() {
        AppLogger.audio.info("🎙️ Audio tracking stopped")
        finalizeBurst()
        flushBurstsToEvent()
        classifier?.detach()
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
        // Widened from 100–500Hz to 80–900Hz. Real snores have fundamentals
        // anywhere from ~60Hz (deep throat snores) up to ~800Hz (nasal
        // vibration and harmonics). The narrower 100–500Hz band was missing
        // many legitimate snore sounds, especially from users testing with
        // their mouth rather than an actual sleep snore.
        let lowBin = max(1, Int(80.0 / freqPerBin))
        let highBin = min(fftSize / 2 - 1, Int(900.0 / freqPerBin))

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
        let passesAmp = amplitude >= adaptiveThreshold
        let passesBand = snoringBandRatio >= minimumSnoringBandRatio
        // Every ~2 seconds log a snapshot of what the mic sees so users /
        // testers can diagnose why snores aren't detected. Uses a coarse
        // counter to keep log volume reasonable (~5 lines / 10s).
        diagnosticSampleCounter += 1
        if diagnosticSampleCounter >= diagnosticSampleLogEvery {
            diagnosticSampleCounter = 0
            AppLogger.audio.debug("🎙️ mic sample — amp=\(String(format: "%.4f", amplitude)) bandRatio=\(String(format: "%.2f", snoringBandRatio)) baseline=\(String(format: "%.4f", self.ambientBaseline)) ampNeeded=\(String(format: "%.4f", adaptiveThreshold)) bandNeeded=\(String(format: "%.2f", self.minimumSnoringBandRatio)) → amp\(passesAmp ? "✅" : "❌") band\(passesBand ? "✅" : "❌")")
        }
        return passesAmp && passesBand
    }

    // Log throttle counters for detectSnoring diagnostics.
    private var diagnosticSampleCounter: Int = 0
    private let diagnosticSampleLogEvery: Int = 22 // ~2s at 11 samples/sec

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

        // Media-playing gate. If the user is falling asleep to Apple Music,
        // a podcast, or a sleep sound, the mic picks up our own speaker.
        // Rather than suppressing ALL bursts (which drops real snores that
        // happen over quiet media), require the classifier to see a real
        // snoring signal before we accept the event.
        var classification = "snoring"
        var confidence = 1.0
        let mediaIsPlaying = mediaPlayback?.isPlaying ?? false

        if mediaIsPlaying, let classifier = classifier {
            let snoringConf = classifier.snoringConfidence(forWindow: eventStart, duration: totalDuration)
            if snoringConf < SoundClassificationService.affirmSnoringConfidenceWhileMediaPlaying {
                AppLogger.audio.info("🔇 Dropped snore candidate — media is playing and classifier saw no snore signal (\(String(format: "%.2f", snoringConf)))")
                recentBursts.removeAll()
                return
            }
            // Signal is strong enough — let the event through and annotate.
            classification = "snoring"
            confidence = snoringConf
            AppLogger.audio.info("✅ Snore through media — snoring confidence \(String(format: "%.2f", snoringConf))")
        } else if mediaIsPlaying, classifier == nil {
            // No classifier attached — fall back to the old behavior of
            // blanket-suppressing while media is playing.
            AppLogger.audio.info("🔇 Dropped snore candidate — media is playing and no classifier available")
            recentBursts.removeAll()
            return
        }

        // Environmental noise gate. If the classifier is attached and the
        // user has opted into filtering, veto candidate events that the
        // classifier flags as fan / AC / dog / speech / other domestic noise.
        if environmentalFilteringEnabled, let classifier = classifier {
            let verdict = classifier.verdict(forWindow: eventStart, duration: totalDuration)
            classification = verdict.label
            confidence = verdict.confidence
            if !verdict.keep {
                AppLogger.audio.info("🔇 Dropped snore candidate — classified as \(verdict.label) (\(String(format: "%.2f", verdict.confidence)))")
                recentBursts.removeAll()
                return
            }
        }

        var event = SnoringEvent(startTime: eventStart, duration: totalDuration, averageAmplitude: avgAmplitude)
        event.classification = classification
        event.classificationConfidence = confidence
        snoringEvents.append(event)
        AppLogger.audio.notice("😴 Snoring event — amp: \(avgAmplitude), dur: \(totalDuration), label: \(classification) (\(String(format: "%.2f", confidence)))")
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
        guard !isRecordingClip, !audioBufferRing.isEmpty, let format = audioBufferFormat else {
            AppLogger.audio.info("🎙️ Skip clip — isRecording=\(self.isRecordingClip), bufferCount=\(self.audioBufferRing.count), hasFormat=\(self.audioBufferFormat != nil)")
            return
        }
        isRecordingClip = true

        let clipsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnoringClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: clipsDir, withIntermediateDirectories: true)

        // Unique enough to avoid collisions when multiple snores occur in
        // the same wall-clock second (previously two snores in a single
        // second would overwrite each other's WAV files).
        let fileName = "snore_\(Int(event.startTime.timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).wav"
        let fileURL = clipsDir.appendingPathComponent(fileName)

        // Snapshot the buffers so we write a consistent set even if the
        // main tap fires more during the write.
        let buffersToWrite = audioBufferRing

        do {
            // Explicitly specify commonFormat + interleaved so the WAV file
            // matches the AVAudioPCMBuffer format exactly. Without this
            // AVAudioFile(forWriting:settings:) can silently create a file
            // header that disagrees with the buffer layout (float32 vs int16),
            // producing a WAV whose AVAudioPlayer reports duration 0 and
            // plays silence.
            let audioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: format.settings,
                commonFormat: format.commonFormat,
                interleaved: format.isInterleaved
            )
            var totalFrames: AVAudioFrameCount = 0
            for buffer in buffersToWrite {
                try audioFile.write(from: buffer)
                totalFrames += buffer.frameLength
            }

            let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
            AppLogger.audio.info("🎙️ Snoring clip saved: \(fileName) (\(buffersToWrite.count) buffers, \(totalFrames) frames, \(fileSize) bytes)")

            guard totalFrames > 0, fileSize > 64 else {
                AppLogger.audio.error("🎙️ Clip file looks empty — skipping URL assignment")
                try? FileManager.default.removeItem(at: fileURL)
                isRecordingClip = false
                return
            }

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
