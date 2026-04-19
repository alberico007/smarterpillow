//
//  GetReadyForBedView.swift
//  sleep
//
//  Modern full-screen modal that replaces the old "tap Start Tracking → jump
//  straight into calibration" flow. Four conceptual steps:
//
//    A. Intent confirmation — "Let me know when you're in bed"
//    B. Baseline + environment assessment (15s, breathing circle animation)
//       • reuses CalibrationService (motion + audio noise floor)
//       • attaches SoundClassificationService to the audio tap
//       • five taps on the circle → DevLogSheet (unified logs)
//    C. Audio chooser (runs concurrently with the baseline)
//       • Apple Music / Podcasts tabs (hidden if disabled in Settings)
//       • Sounds, Meditations, Stories tabs (from existing SoundLibrary)
//       • Sleep-timer chip row
//    D. Confirm & Start → SleepTrackingService.startTracking()
//

import MusicKit
import os
import SwiftData
import SwiftUI

// MARK: - Audio choice

enum AudioChoice: Equatable {
    case none
    case sound(SoundItem)
    case podcast(PodcastEpisode)
    case appleMusic(id: MusicItemID, title: String, subtitle: String, artworkURL: URL?)

    var summary: String {
        switch self {
        case .none: return "No sleep audio"
        case .sound(let s): return s.name
        case .podcast(let e): return e.title
        case .appleMusic(_, let title, _, _): return title
        }
    }
}

// MARK: - View

struct GetReadyForBedView: View {

    /// Called right before we dismiss — parent uses this to switch tabs so
    /// the user lands on the active tracking UI automatically.
    var onTrackingStarted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepFactor.date, order: .reverse)
    private var existingFactors: [SleepFactor]
    @Environment(SleepSettings.self) private var settings
    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(SoundService.self) private var soundService
    @Environment(MediaPlaybackService.self) private var mediaService
    @Environment(PodcastService.self) private var podcastService
    @Environment(IntelligenceService.self) private var intelligenceService

    private enum Step { case intent, baseline }

    @State private var step: Step = .intent
    @State private var baselineProgress: Double = 0
    @State private var baselineStartDate: Date?
    @State private var baselineTimer: Timer?
    @State private var showingDevLogs = false
    @State private var logoTapCount = 0
    @State private var pulseScale: CGFloat = 1.0

    @State private var audioChoice: AudioChoice = .none
    @State private var selectedTimerMinutes: Int = 30 // overwritten from settings in onAppear

    // Day journal (AI factor extraction)
    @State private var dayJournal: String = ""
    @State private var extractedFactors: [IntelligenceService.ExtractedFactor] = []
    @State private var isExtractingFactors = false
    @State private var showJournalExpanded = false

    // AI personal meditation
    @State private var aiMeditationScript: String? = nil
    @State private var isGeneratingMeditation = false
    @State private var aiMeditationSelected = false

    private let baselineDuration: TimeInterval = 15

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            switch step {
            case .intent:
                intentView
                    .transition(.opacity)
            case .baseline:
                baselineView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .interactiveDismissDisabled()
        .onAppear {
            selectedTimerMinutes = settings.defaultSleepTimerMinutes
            if settings.skipBedIntentConfirmation {
                beginBaseline()
            }
        }
        .sheet(isPresented: $showingDevLogs) { DevLogSheet() }
    }

    // MARK: - Step A — Intent

    private var intentView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .indigo], startPoint: .top, endPoint: .bottom)
                )

            VStack(spacing: 10) {
                Text("Ready for bed?")
                    .font(.largeTitle.bold())
                Text("Let me know when you're in bed and ready to sleep. I'll check the room for a moment, then start tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            journalCard
                .padding(.horizontal, 20)

            Spacer()

            Button {
                saveExtractedFactors()
                beginBaseline()
            } label: {
                Text("I'm Ready to Sleep")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)

            Button("Cancel") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 30)
        }
    }

    // MARK: - Journal card (day → factors via Apple Intelligence)

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("How was your day?")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                if intelligenceService.isAvailable {
                    Text("AI")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Button {
                    withAnimation { showJournalExpanded.toggle() }
                } label: {
                    Image(systemName: showJournalExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if showJournalExpanded {
                Text("A quick sentence helps me log what might affect tonight's sleep (coffee, workout, stress…). I'll tag it automatically.")
                    .font(.caption).foregroundStyle(.secondary)

                TextField("e.g. coffee at 4, gym, stressed about exam", text: $dayJournal, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack {
                    Button {
                        Task { await extractFactorsNow() }
                    } label: {
                        HStack(spacing: 6) {
                            if isExtractingFactors {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(isExtractingFactors ? "Tagging…" : "Tag factors")
                        }
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                    }
                    .disabled(dayJournal.trimmingCharacters(in: .whitespaces).isEmpty || isExtractingFactors)
                    Spacer()
                }

                if !extractedFactors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(extractedFactors.enumerated()), id: \.offset) { _, f in
                                factorChip(type: f.type, label: f.customLabel.isEmpty ? f.type.label : f.customLabel)
                            }
                        }
                    }
                }
            } else if !extractedFactors.isEmpty {
                Text("\(extractedFactors.count) factor\(extractedFactors.count == 1 ? "" : "s") tagged")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Tap to log what affected your day")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
        .onTapGesture {
            if !showJournalExpanded { withAnimation { showJournalExpanded = true } }
        }
    }

    private func factorChip(type: FactorType, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon).font(.caption2)
            Text(label).font(.caption2).fontWeight(.semibold)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(type.color.opacity(0.18))
        .foregroundStyle(type.color)
        .clipShape(Capsule())
    }

    @MainActor
    private func extractFactorsNow() async {
        let text = dayJournal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isExtractingFactors = true
        defer { isExtractingFactors = false }
        extractedFactors = await intelligenceService.extractFactors(from: text)
        AppLogger.intelligence.info("🤖 Journal → \(extractedFactors.count) factors tagged")
    }

    private func saveExtractedFactors() {
        guard !extractedFactors.isEmpty else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Deduplicate against anything already logged today with the same
        // factor type (standard types) or same custom label (custom type).
        // Prevents multiple passes of the journal from stacking duplicates.
        let todaysFactors = existingFactors.filter { calendar.isDate($0.date, inSameDayAs: today) }
        var saved = 0
        var skipped = 0
        for f in extractedFactors {
            let alreadyExists: Bool
            if f.type == .custom {
                alreadyExists = todaysFactors.contains { existing in
                    existing.type == .custom &&
                    existing.customLabel.caseInsensitiveCompare(f.customLabel) == .orderedSame
                }
            } else {
                alreadyExists = todaysFactors.contains { $0.type == f.type }
            }
            if alreadyExists {
                skipped += 1
                continue
            }
            let factor = SleepFactor(
                date: Date(),
                type: f.type,
                customLabel: f.customLabel,
                intensity: f.intensity
            )
            modelContext.insert(factor)
            saved += 1
        }
        try? modelContext.save()
        AppLogger.intelligence.info("💾 Journal factors — saved: \(saved), skipped dupes: \(skipped)")
    }

    // MARK: - AI Meditation row (inside meditations CategoryBox)

    private var aiMeditationRow: some View {
        HStack(spacing: 10) {
            ZStack {
                LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Image(systemName: "sparkles")
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Tonight's Meditation")
                    .font(.subheadline).fontWeight(.semibold)
                if let text = aiMeditationScript, !text.isEmpty {
                    Text(String(text.prefix(60)) + (text.count > 60 ? "…" : ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("AI-generated for you, on-device")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task { await generateMeditationNow() }
            } label: {
                HStack(spacing: 4) {
                    if isGeneratingMeditation {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: aiMeditationScript == nil ? "wand.and.stars" : "arrow.clockwise")
                    }
                    Text(aiMeditationScript == nil ? "Generate" : "Regen")
                        .font(.caption).fontWeight(.semibold)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.purple.opacity(0.15))
                .foregroundStyle(.purple)
                .clipShape(Capsule())
            }
            .disabled(isGeneratingMeditation)
        }
        .padding(10)
        .background(aiMeditationSelected ? Color.purple.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(aiMeditationSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if aiMeditationScript != nil {
                aiMeditationSelected.toggle()
                if aiMeditationSelected {
                    // Mark as selected; the actual TTS kickoff happens in startTracking()
                    audioChoice = .none
                }
            }
        }
    }

    @MainActor
    private func generateMeditationNow() async {
        isGeneratingMeditation = true
        defer { isGeneratingMeditation = false }
        let stressSnippet = dayJournal.isEmpty ? nil : String(dayJournal.prefix(200))
        aiMeditationScript = await intelligenceService.generatePersonalMeditation(
            name: nil,
            recentStress: stressSnippet,
            lengthMinutes: 3
        )
        if aiMeditationScript != nil {
            aiMeditationSelected = true
            AppLogger.intelligence.info("✨ AI meditation generated, \(aiMeditationScript?.count ?? 0) chars")
        }
    }

    // MARK: - Step B — Baseline + audio chooser

    private var baselineView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Animated breathing circle (5-tap easter egg → dev logs)
                ZStack {
                    Circle()
                        .stroke(.cyan.opacity(0.2), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                    Circle()
                        .fill(LinearGradient(colors: [.cyan.opacity(0.25), .indigo.opacity(0.25)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                    VStack(spacing: 4) {
                        Text("\(Int((1 - baselineProgress) * baselineDuration))s")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("Getting ready")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 180)
                .padding(.top, 20)
                .onTapGesture {
                    logoTapCount += 1
                    if logoTapCount >= 5 {
                        logoTapCount = 0
                        showingDevLogs = true
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        pulseScale = 1.15
                    }
                }

                Text("Checking the room — listening for background noise, sensing motion, initializing sensors.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Divider().padding(.vertical, 4)

                // Audio chooser
                chooserHeader
                timerChipRow

                // Vertical stack of boxed category sections in the order the
                // user wants: Apple Music → Podcasts → Sleep Sounds →
                // Meditations → Sleep Stories. Hidden sections (Apple Music /
                // Podcasts) are gated by settings.
                VStack(spacing: 14) {
                    if settings.appleMusicEnabled {
                        CategoryBox(
                            title: "Apple Music",
                            subtitle: "Songs and playlists",
                            systemImage: "music.note",
                            tint: .red
                        ) {
                            AppleMusicTabView(choice: $audioChoice, mediaService: mediaService)
                        }
                    }

                    if settings.podcastsEnabled {
                        CategoryBox(
                            title: "Podcasts",
                            subtitle: "Search and stream any podcast",
                            systemImage: "waveform.badge.mic",
                            tint: .purple
                        ) {
                            PodcastsTabView(choice: $audioChoice, podcastService: podcastService)
                        }
                    }

                    CategoryBox(
                        title: "Sleep Sounds",
                        subtitle: "Rain, ocean, white noise…",
                        systemImage: "speaker.wave.2.fill",
                        tint: .cyan
                    ) {
                        SoundListView(items: SoundLibrary.free(), choice: $audioChoice)
                    }

                    CategoryBox(
                        title: "Meditations",
                        subtitle: "Guided breathing and body scans",
                        systemImage: "brain.head.profile.fill",
                        tint: .green
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            aiMeditationRow
                            SoundListView(items: SoundLibrary.meditation(), choice: $audioChoice)
                        }
                    }

                    CategoryBox(
                        title: "Sleep Stories",
                        subtitle: "Narrated stories to drift off to",
                        systemImage: "book.fill",
                        tint: .indigo
                    ) {
                        SoundListView(items: SoundLibrary.stories(), choice: $audioChoice)
                    }
                }

                Spacer(minLength: 16)

                // Start button becomes enabled as soon as baseline completes.
                Button {
                    startTracking()
                } label: {
                    HStack {
                        if baselineProgress < 1 {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(baselineProgress < 1 ? "Preparing…" : "Start Tracking")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: baselineProgress < 1 ? [.gray, .gray.opacity(0.7)] : [.cyan, .indigo],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(baselineProgress < 1)
                .padding(.horizontal, 20)

                Button("Cancel") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
        }
    }

    private var chooserHeader: some View {
        HStack {
            Text("What do you want to fall asleep to?")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var timerChipRow: some View {
        let options: [(label: String, value: Int)] = [
            ("15m", 15), ("30m", 30), ("1h", 60), ("2h", 120), ("Until I wake", 0)
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
                ForEach(options, id: \.value) { opt in
                    Button {
                        selectedTimerMinutes = opt.value
                    } label: {
                        Text(opt.label)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTimerMinutes == opt.value
                                ? AnyShapeStyle(LinearGradient(colors: [.cyan, .indigo], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color.secondary.opacity(0.15)))
                            .foregroundStyle(selectedTimerMinutes == opt.value ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Actions

    private func beginBaseline() {
        step = .baseline
        baselineStartDate = Date()
        baselineProgress = 0
        AppLogger.tracking.info("🛌 GetReadyForBed: baseline started")

        // Warm up the sensors DURING the 15-second baseline rather than
        // after the user taps Start Tracking:
        //  • MotionService so calibration can read real accelerometer data
        //  • AudioService so we sample the ambient dB floor + snoring-band baseline
        //  • SoundAnalysis classifier gets a head start classifying the room
        if settings.trackMotion {
            trackingService.motionService.startTracking(sensitivity: settings.sensitivityLevel)
        }
        if settings.trackAudio {
            trackingService.audioService.configure(
                sensitivity: settings.snoringSensitivity,
                minDuration: settings.minimumSnoreDuration
            )
            trackingService.audioService.startTracking()
        }

        // Now the calibration service samples real data from both streams.
        trackingService.calibrationService.startCalibration(
            motionService: trackingService.motionService,
            audioService: trackingService.audioService
        )

        baselineTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard let start = baselineStartDate else { return }
                let elapsed = Date().timeIntervalSince(start)
                baselineProgress = min(1, elapsed / baselineDuration)
                if baselineProgress >= 1 {
                    baselineTimer?.invalidate()
                    baselineTimer = nil
                    AppLogger.tracking.info("🛌 GetReadyForBed: baseline complete")
                }
            }
        }
    }

    private func startTracking() {
        baselineTimer?.invalidate()
        baselineTimer = nil
        AppLogger.tracking.info("🛌 Start tracking — audio: \(audioChoice.summary), timer: \(selectedTimerMinutes)m")
        // Begin tracking (calibration is already underway / complete).
        trackingService.startTracking()

        // If the user picked the AI-generated meditation, play it via TTS and
        // skip the other audio branches.
        if aiMeditationSelected, let script = aiMeditationScript, !script.isEmpty {
            soundService.playCustomScript(
                title: "Tonight's Meditation",
                script: script,
                volume: 0.8,
                timerMinutes: selectedTimerMinutes
            )
            onTrackingStarted?()
            dismiss()
            return
        }

        // Kick off the chosen fall-asleep media, if any.
        switch audioChoice {
        case .none:
            break
        case .sound(let sound):
            mediaService.playSound(sound, timerMinutes: selectedTimerMinutes)
        case .podcast(let episode):
            mediaService.playPodcast(episode, timerMinutes: selectedTimerMinutes)
        case .appleMusic(let id, let title, let subtitle, let artwork):
            Task { @MainActor in
                // Try the Apple Music catalog first (songs + curated playlists
                // surfaced via search).
                let songRequest = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: id)
                if let song = try? await songRequest.response().items.first {
                    await mediaService.playAppleMusic(
                        song,
                        title: title, subtitle: subtitle, artworkURL: artwork,
                        timerMinutes: selectedTimerMinutes
                    )
                    return
                }
                let catalogPlaylistRequest = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id)
                if let playlist = try? await catalogPlaylistRequest.response().items.first {
                    await mediaService.playAppleMusic(
                        playlist,
                        title: title, subtitle: subtitle, artworkURL: artwork,
                        timerMinutes: selectedTimerMinutes
                    )
                    return
                }

                // Fall back to the user's own library — catalog requests
                // can't resolve a library-only playlist ID, which is why
                // picking a personal playlist (e.g. "Jazz") never started.
                var libraryRequest = MusicLibraryRequest<Playlist>()
                libraryRequest.filter(matching: \.id, equalTo: id)
                if let libraryPlaylist = try? await libraryRequest.response().items.first {
                    await mediaService.playAppleMusic(
                        libraryPlaylist,
                        title: title, subtitle: subtitle, artworkURL: artwork,
                        timerMinutes: selectedTimerMinutes
                    )
                    return
                }

                AppLogger.sound.error("🎵 Could not resolve Apple Music ID \(id.rawValue) in catalog or library")
            }
        }
        onTrackingStarted?()
        dismiss()
    }
}

// MARK: - CategoryBox (boxed section wrapper)

private struct CategoryBox<Content: View>: View {

    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            content
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Sound list

private struct SoundListView: View {
    let items: [SoundItem]
    @Binding var choice: AudioChoice

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        choice = .sound(item)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 22))
                                .frame(width: 52, height: 52)
                                .background(isSelected(item) ? Color.cyan.opacity(0.2) : Color.secondary.opacity(0.1))
                                .foregroundStyle(isSelected(item) ? .cyan : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Text(item.name)
                                .font(.caption2)
                                .foregroundStyle(isSelected(item) ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 100)
    }

    private func isSelected(_ item: SoundItem) -> Bool {
        if case .sound(let chosen) = choice { return chosen.id == item.id }
        return false
    }
}

// MARK: - Apple Music tab

private struct AppleMusicTabView: View {
    @Binding var choice: AudioChoice
    let mediaService: MediaPlaybackService

    @State private var isAuthorized: Bool = false
    @State private var isChecking = false
    @State private var searchText = ""
    @State private var results: [Song] = []
    @State private var isSearching = false
    @State private var libraryPlaylists: [Playlist] = []
    @State private var isLoadingLibrary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isAuthorized {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .foregroundStyle(.red)
                        Text("Connect Apple Music to pick a song or playlist")
                            .font(.caption)
                    }
                    Button {
                        Task {
                            isChecking = true
                            let status = await mediaService.requestAppleMusicAuthorization()
                            let hasAccess = status == .authorized ? await mediaService.hasAppleMusicAccess() : false
                            isAuthorized = hasAccess
                            isChecking = false
                            if isAuthorized { await loadLibraryPlaylists() }
                        }
                    } label: {
                        Text(isChecking ? "Requesting…" : "Connect Apple Music")
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    .disabled(isChecking)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search Apple Music", text: $searchText)
                        .onSubmit { Task { await runSearch() } }
                    if isSearching { ProgressView() }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Decide what to show:
                //   • No search yet → the user's own library playlists
                //   • Active search with results → song results
                if results.isEmpty {
                    // Library playlists default view
                    HStack {
                        Text("Your Playlists")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isLoadingLibrary { ProgressView() }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    if libraryPlaylists.isEmpty && !isLoadingLibrary {
                        Text("No playlists found in your library. Search to pick a song.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(libraryPlaylists, id: \.id) { playlist in
                                    Button {
                                        choice = .appleMusic(
                                            id: playlist.id,
                                            title: playlist.name,
                                            subtitle: playlist.curatorName ?? "Playlist",
                                            artworkURL: playlist.artwork?.url(width: 200, height: 200)
                                        )
                                    } label: {
                                        MusicCardView(
                                            title: playlist.name,
                                            subtitle: playlist.curatorName ?? "Playlist",
                                            artwork: playlist.artwork,
                                            fallbackSymbol: "music.note.list",
                                            fallbackGradient: [.red.opacity(0.75), .purple.opacity(0.6)],
                                            isSelected: isSelected(id: playlist.id)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .frame(height: 170)
                    }
                } else {
                    // Search results
                    HStack {
                        Text("Search Results")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") {
                            searchText = ""
                            results = []
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(results, id: \.id) { song in
                                Button {
                                    choice = .appleMusic(
                                        id: song.id,
                                        title: song.title,
                                        subtitle: song.artistName,
                                        artworkURL: song.artwork?.url(width: 200, height: 200)
                                    )
                                } label: {
                                    MusicCardView(
                                        title: song.title,
                                        subtitle: song.artistName,
                                        artwork: song.artwork,
                                        fallbackSymbol: "music.note",
                                        fallbackGradient: [.pink.opacity(0.75), .red.opacity(0.6)],
                                        isSelected: isSelected(id: song.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 170)
                }
            }
        }
        .task {
            isChecking = true
            let status = MusicAuthorization.currentStatus
            let hasAccess = status == .authorized ? await mediaService.hasAppleMusicAccess() : false
            isAuthorized = hasAccess
            isChecking = false
            if isAuthorized { await loadLibraryPlaylists() }
        }
    }

    @MainActor
    private func loadLibraryPlaylists() async {
        isLoadingLibrary = true
        defer { isLoadingLibrary = false }
        var request = MusicLibraryRequest<Playlist>()
        request.limit = 25
        if let response = try? await request.response() {
            libraryPlaylists = Array(response.items)
            AppLogger.sound.info("🎵 Loaded \(libraryPlaylists.count) library playlists")
        } else {
            AppLogger.sound.info("🎵 Could not load library playlists")
        }
    }

    private func runSearch() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        var request = MusicCatalogSearchRequest(term: trimmed, types: [Song.self])
        request.limit = 15
        if let response = try? await request.response() {
            results = Array(response.songs)
        }
    }

    /// Is this MusicKit item the current selected choice?
    private func isSelected(id: MusicItemID) -> Bool {
        if case .appleMusic(let chosenID, _, _, _) = choice {
            return chosenID == id
        }
        return false
    }
}

// MARK: - MusicCardView

/// A visual tile for an Apple Music item (song or playlist) that:
///   • Renders artwork via MusicKit's ArtworkImage (handles auth correctly)
///   • Falls back to a gradient-backed SF Symbol when no artwork exists
///   • Shows a cyan ring + checkmark badge when selected
private struct MusicCardView: View {

    let title: String
    let subtitle: String
    let artwork: Artwork?
    let fallbackSymbol: String
    let fallbackGradient: [Color]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let artwork {
                        ArtworkImage(artwork, width: 100, height: 100)
                    } else {
                        fallbackTile
                            .frame(width: 100, height: 100)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 3)
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .cyan)
                        .background(Circle().fill(.white).padding(2))
                        .padding(4)
                }
            }
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .cyan : .primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 110)
    }

    private var fallbackTile: some View {
        LinearGradient(colors: fallbackGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                Image(systemName: fallbackSymbol)
                    .foregroundStyle(.white)
                    .font(.title2)
            )
    }
}

// MARK: - Podcasts tab

private struct PodcastsTabView: View {
    @Binding var choice: AudioChoice
    let podcastService: PodcastService

    @State private var query = ""
    @State private var shows: [PodcastShow] = []
    @State private var selectedShow: PodcastShow?
    @State private var episodes: [PodcastEpisode] = []
    @State private var isSearching = false
    @State private var isLoadingFeed = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search podcasts", text: $query)
                    .onSubmit { Task { await runSearch() } }
                if isSearching { ProgressView() }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            if let show = selectedShow {
                HStack {
                    Button {
                        selectedShow = nil
                        episodes = []
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    Text(show.name).font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    if isLoadingFeed { ProgressView() }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(episodes) { ep in
                            Button {
                                choice = .podcast(ep)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    if let art = ep.artworkURL {
                                        AsyncImage(url: art) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: { Color.secondary.opacity(0.1) }
                                            .frame(width: 36, height: 36)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ep.title).font(.caption).fontWeight(.semibold).lineLimit(2)
                                        HStack(spacing: 6) {
                                            if let dur = ep.duration {
                                                Text(formatDuration(dur)).font(.caption2).foregroundStyle(.secondary)
                                            }
                                            if isSelected(ep) {
                                                Text("• Selected").font(.caption2).foregroundStyle(.cyan)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(isSelected(ep) ? Color.cyan.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            } else if !shows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shows) { show in
                            Button {
                                selectedShow = show
                                Task { await loadEpisodes(show) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let art = show.artworkURL {
                                        AsyncImage(url: art) { img in
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: { Color.secondary.opacity(0.1) }
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    Text(show.name).font(.caption).lineLimit(2)
                                    Text(show.artist).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .frame(width: 110)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 170)
            } else {
                Text("Search to discover podcasts (e.g. \"sleep\", \"meditation\", \"bedtime story\").")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func isSelected(_ ep: PodcastEpisode) -> Bool {
        if case .podcast(let chosen) = choice { return chosen.id == ep.id }
        return false
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            shows = try await podcastService.search(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadEpisodes(_ show: PodcastShow) async {
        isLoadingFeed = true
        errorMessage = nil
        defer { isLoadingFeed = false }
        do {
            episodes = try await podcastService.episodes(for: show)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
