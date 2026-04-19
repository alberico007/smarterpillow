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

    @Environment(AuthenticationService.self) private var authService
    @State private var showingPDFExport = false
    @State private var showingCSVExport = false
    @State private var showingTerms = false
    @State private var showingSignOutConfirmation = false
    @State private var showingResetOnboardingConfirmation = false
    @State private var showingAdvancedDetection = false
    @State private var healthKitError: String?

    private let permissionService = PermissionService.shared

    private var notificationService: NotificationService {
        trackingService.notificationService
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                // MARK: You
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

                // MARK: Sleep
                Section {
                    NavigationLink {
                        SleepScheduleView()
                    } label: {
                        SettingRow(icon: "clock.fill", color: .cyan, title: "Sleep Schedule", subtitle: "Bedtime, wake time, sleep goal")
                    }
                    NavigationLink {
                        AlarmSettingsView()
                    } label: {
                        SettingRow(icon: "alarm.waves.left.and.right.fill", color: .orange, title: "Smart Alarm", subtitle: "Wake during light sleep")
                    }
                } header: {
                    Text("Sleep")
                } footer: {
                    Text("Smart Alarm wakes you during a light sleep stage within a window before your alarm time. Keep a backup iPhone alarm for anything critical.")
                }

                // MARK: Sleep Audio
                Section {
                    Toggle("Apple Music", isOn: $settings.appleMusicEnabled)
                    Toggle("Podcasts", isOn: $settings.podcastsEnabled)
                    Picker("Default Timer", selection: $settings.defaultSleepTimerMinutes) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                        Text("Until I wake").tag(0)
                    }
                    Toggle("Filter fans & AC from snores", isOn: $settings.environmentalNoiseFilteringEnabled)
                } header: {
                    Text("Sleep Audio")
                } footer: {
                    Text("Apple Music and Podcasts add those categories to the Get Ready for Bed chooser. Environmental filtering uses on-device sound classification to drop non-snore noise.")
                }

                // MARK: Detection
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Snoring Sensitivity")
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

                    Button {
                        showingAdvancedDetection = true
                    } label: {
                        HStack {
                            Text("Advanced")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Detection")
                } footer: {
                    Text("Lower sensitivity catches lighter snoring. Move right if you're getting false positives.")
                }

                // MARK: Notifications
                Section("Notifications") {
                    Toggle("Bedtime Reminder", isOn: $settings.bedtimeReminderEnabled)
                    if settings.bedtimeReminderEnabled {
                        DatePicker(
                            "Time",
                            selection: $settings.bedtimeReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Toggle("Morning Summary", isOn: $settings.morningSummaryEnabled)
                    Toggle("Weekly Digest", isOn: $settings.weeklyDigestEnabled)
                }

                // MARK: Integrations
                Section("Integrations") {
                    NavigationLink {
                        IntegrationsView()
                    } label: {
                        SettingRow(icon: "link.circle.fill", color: .green, title: "Apple Health, Watch & Siri", subtitle: "Sync, pairing, voice shortcuts")
                    }
                }

                // MARK: Data
                Section {
                    NavigationLink {
                        PrivacyControlsView()
                    } label: {
                        SettingRow(icon: "lock.shield.fill", color: .blue, title: "Privacy & Data", subtitle: "Storage, data management")
                    }
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
                } header: {
                    Text("Data")
                } footer: {
                    Text("All tracking runs on-device. Your data never leaves your iPhone unless you choose to share or export.")
                }

                // MARK: Permissions (compact — read-only status)
                Section {
                    PermissionRow(title: "Microphone", icon: "mic.fill", granted: permissionService.microphoneGranted)
                    PermissionRow(title: "Motion", icon: "move.3d", granted: permissionService.motionAvailable)
                    PermissionRow(title: "HealthKit", icon: "heart.fill", granted: permissionService.healthKitAuthorized)
                    PermissionRow(title: "Notifications", icon: "bell.fill", granted: permissionService.notificationsAuthorized)
                    Button("Request Missing Permissions") {
                        Task { await permissionService.requestAllPermissions() }
                    }
                    .font(.subheadline)
                } header: {
                    Text("Permissions")
                }

                // MARK: About
                Section {
                    NavigationLink {
                        AboutTeamView()
                    } label: {
                        SettingRow(icon: "person.3.fill", color: .orange, title: "About the Team", subtitle: "The people behind Slumberscope")
                    }
                    Button { showingTerms = true } label: {
                        SettingRow(icon: "doc.text.fill", color: .indigo, title: "Terms of Service", subtitle: "Usage terms & disclaimers")
                    }
                    .tint(.primary)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Nights Tracked")
                        Spacer()
                        Text("\(sessions.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // MARK: Account actions (sign out / reset) — bottom of Settings
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button {
                        showingResetOnboardingConfirmation = true
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Signing out wipes sleep data from this device. Cloud backup is preserved.")
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    LocalDataCleanup.wipeUserData(modelContext: modelContext, settings: settings)
                    authService.signOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Signing out removes sleep data from this device. Your cloud backup is preserved and will return when you sign back in.")
            }
            .alert("Reset Onboarding?", isPresented: $showingResetOnboardingConfirmation) {
                Button("Reset", role: .destructive) {
                    settings.hasCompletedOnboarding = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You will see the welcome flow again. Your data and account are not affected.")
            }
            .sheet(isPresented: $showingPDFExport) {
                PDFExportView(sessions: sessions)
            }
            .sheet(isPresented: $showingCSVExport) {
                CSVExportView(sessions: sessions)
            }
            .sheet(isPresented: $showingTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showingAdvancedDetection) {
                AdvancedDetectionSheet(settings: settings)
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

// MARK: - Advanced Detection Sheet
//
// Kept out of the main Settings surface because these are rarely-touched
// power-user knobs. Accessed via the "Advanced" row in the Detection section.

private struct AdvancedDetectionSheet: View {
    @Bindable var settings: SleepSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Text("Minimum Snore Duration: \(String(format: "%.1f", settings.minimumSnoreDuration))s")
                            .font(.subheadline)
                        Slider(value: $settings.minimumSnoreDuration, in: 0.3...3.0, step: 0.1)
                    }
                } header: {
                    Text("Thresholds")
                } footer: {
                    Text("Shorter durations catch quick snorts and snores; longer durations drop brief throat clears.")
                }
            }
            .navigationTitle("Advanced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - SettingRow

private struct SettingRow: View {

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
