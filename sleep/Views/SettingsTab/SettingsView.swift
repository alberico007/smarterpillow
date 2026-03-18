//
//  SettingsView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftData
import SwiftUI

struct SettingsView: View {

    @Environment(SleepSettings.self) private var settings
    @Environment(SleepTrackingService.self) private var trackingService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SleepSession.startTime, order: .reverse)
    private var sessions: [SleepSession]

    @State private var showingPDFExport = false
    @State private var showingCSVExport = false
    @State private var showingTerms = false
    @State private var healthKitError: String?

    private let permissionService = PermissionService.shared

    private var notificationService: NotificationService {
        trackingService.notificationService
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                // MARK: Profile
                Section {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(settings.userName.isEmpty ? "Set Up Profile" : settings.userName)
                                    .font(.subheadline)
                                Text("Name, age, sleep goal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // MARK: Sleep Schedule
                Section {
                    NavigationLink {
                        SleepScheduleView()
                    } label: {
                        LegalRow(icon: "clock.fill", color: .cyan, title: "Sleep Schedule", subtitle: "Bedtime, wake time, sleep goal")
                    }

                    NavigationLink {
                        AlarmSettingsView()
                    } label: {
                        LegalRow(icon: "alarm.fill", color: .orange, title: "Smart Alarm", subtitle: "Wake window, gradual alarm")
                    }
                } header: {
                    Text("Schedule & Alarm")
                }

                // MARK: Advanced Schedule
                Section {
                    NavigationLink {
                        ShiftWorkView()
                    } label: {
                        LegalRow(icon: "calendar.badge.clock", color: .purple, title: "Shift Work & Vacation", subtitle: "Custom schedules, vacation mode")
                    }
                } header: {
                    Text("Advanced Schedule")
                }

                // MARK: Tracking
                Section("Tracking") {
                    Toggle("Track Motion", isOn: $settings.trackMotion)
                    Toggle("Track Audio", isOn: $settings.trackAudio)
                    Toggle("Calibration Phase", isOn: $settings.calibrationEnabled)

                    VStack(alignment: .leading) {
                        Text("Motion Sensitivity: \(String(format: "%.1f", settings.sensitivityLevel))")
                            .font(.subheadline)
                        Slider(value: $settings.sensitivityLevel, in: 0.1...1.0, step: 0.1)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sensitivity")
                                .font(.subheadline)
                            Spacer()
                            Text(snoringSensitivityLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.snoringSensitivity, in: 0.0...1.0, step: 0.1)
                        HStack {
                            Text("Light Snorer")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Heavy Snorer")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Min Snore Duration: \(String(format: "%.1f", settings.minimumSnoreDuration))s")
                            .font(.subheadline)
                        Slider(value: $settings.minimumSnoreDuration, in: 0.5...3.0, step: 0.5)
                    }
                } header: {
                    Text("Snoring Detection")
                } footer: {
                    Text("Lower sensitivity detects lighter snoring. Increase duration if getting false positives.")
                }

                // MARK: Notifications
                Section("Notifications") {
                    Toggle("Bedtime Reminder", isOn: $settings.bedtimeReminderEnabled)
                    if settings.bedtimeReminderEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $settings.bedtimeReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Toggle("Morning Summary", isOn: $settings.morningSummaryEnabled)
                    Toggle("Weekly Digest", isOn: $settings.weeklyDigestEnabled)
                }

                // MARK: Integrations
                Section {
                    NavigationLink {
                        IntegrationsView()
                    } label: {
                        LegalRow(icon: "link.circle.fill", color: .green, title: "Integrations", subtitle: "Health, Watch, Siri")
                    }

                    NavigationLink {
                        ActionButtonSettingsView()
                    } label: {
                        LegalRow(icon: "button.programmable", color: .gray, title: "Action Button", subtitle: "Map to start/stop tracking")
                    }
                }

                // MARK: Display
                Section("Display") {
                    Toggle("Show Sleep Score", isOn: $settings.showSleepScore)
                }

                // MARK: Permissions
                Section("Permissions") {
                    PermissionRow(title: "Microphone", icon: "mic.fill", granted: permissionService.microphoneGranted)
                    PermissionRow(title: "Motion", icon: "move.3d", granted: permissionService.motionAvailable)
                    PermissionRow(title: "HealthKit", icon: "heart.fill", granted: permissionService.healthKitAuthorized)
                    PermissionRow(title: "Notifications", icon: "bell.fill", granted: permissionService.notificationsAuthorized)

                    Button("Request All Permissions") {
                        Task { await permissionService.requestAllPermissions() }
                    }
                }

                // MARK: Legal
                Section {
                    NavigationLink {
                        PrivacyControlsView()
                    } label: {
                        LegalRow(icon: "lock.shield.fill", color: .blue, title: "Privacy & Data", subtitle: "Storage, export, data management")
                    }

                    Button { showingTerms = true } label: {
                        LegalRow(icon: "doc.text.fill", color: .indigo, title: "Terms of Service", subtitle: "Usage terms & disclaimers")
                    }
                    .tint(.primary)
                } header: {
                    Text("Legal")
                } footer: {
                    Text("All sleep data is processed on-device and never shared with third parties.")
                }

                // MARK: Export
                Section("Export") {
                    Button {
                        showingPDFExport = true
                    } label: {
                        Label("Export PDF Report", systemImage: "doc.richtext")
                    }
                    Button {
                        showingCSVExport = true
                    } label: {
                        Label("Export CSV Data", systemImage: "tablecells")
                    }
                }

                // MARK: Subscription
                Section {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        LegalRow(icon: "crown.fill", color: .orange, title: "Premium", subtitle: "Unlock all features")
                    }
                }

                // MARK: About
                Section("About") {
                    NavigationLink {
                        AboutTeamView()
                    } label: {
                        LegalRow(icon: "person.3.fill", color: .orange, title: "About the Team", subtitle: "The people behind Slumberscope")
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Sessions Recorded")
                        Spacer()
                        Text("\(sessions.count)")
                            .foregroundStyle(.secondary)
                    }
                    Button("Reset Onboarding") {
                        settings.hasCompletedOnboarding = false
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPDFExport) {
                PDFExportView(sessions: sessions)
            }
            .sheet(isPresented: $showingCSVExport) {
                CSVExportView(sessions: sessions)
            }
            .sheet(isPresented: $showingTerms) {
                TermsOfServiceView()
            }
            .onChange(of: settings.bedtimeReminderEnabled) { _, newValue in
                notificationService.scheduleBedtimeReminder(at: settings.bedtimeReminderTime, enabled: newValue)
            }
            .onChange(of: settings.bedtimeReminderTime) { _, newValue in
                if settings.bedtimeReminderEnabled {
                    notificationService.scheduleBedtimeReminder(at: newValue, enabled: true)
                }
            }
            .onChange(of: settings.weeklyDigestEnabled) { _, newValue in
                notificationService.scheduleWeeklyDigest(enabled: newValue)
            }
            .onChange(of: settings.calibrationEnabled) { _, newValue in
                if !newValue { trackingService.calibrationService.clearBaseline() }
            }
            .onChange(of: settings.syncHealthKit) { _, newValue in
                if newValue {
                    Task {
                        await permissionService.requestHealthKit()
                        if !permissionService.healthKitAuthorized {
                            healthKitError = "HealthKit authorization was not granted."
                            settings.syncHealthKit = false
                        } else {
                            healthKitError = nil
                        }
                    }
                } else {
                    healthKitError = nil
                }
            }
        }
    }

    private var snoringSensitivityLabel: String {
        switch settings.snoringSensitivity {
        case 0.0...0.2: return "Very Sensitive"
        case 0.2...0.4: return "Sensitive"
        case 0.4...0.6: return "Normal"
        case 0.6...0.8: return "Low"
        default: return "Very Low"
        }
    }
}

// MARK: - LegalRow

private struct LegalRow: View {

    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PermissionRow

private struct ActionButtonSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Map your iPhone's Action Button to quickly start or stop sleep tracking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Action") {
                Label("Start/Stop Sleep Tracking", systemImage: "moon.zzz.fill")
                Text("Go to Settings \u{2192} Action Button \u{2192} Shortcut \u{2192} Select \"Start Sleep Tracking\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Action Button")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - PermissionRow

private struct PermissionRow: View {

    let title: String
    let icon: String
    let granted: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(granted ? .green : .secondary)
                .frame(width: 24)
            Text(title)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? .green : .red)
        }
    }
}
