//
//  PrivacyPolicyView.swift
//  sleep
//

import SwiftUI

struct PrivacyPolicyView: View {

    @Environment(\.dismiss) private var dismiss

    private static let supportEmail = "alberico007@gannon.edu"
    private static let lastUpdated = "April 2026"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 48))
                                .foregroundStyle(.cyan)
                            Text("Privacy Policy")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Last updated: \(Self.lastUpdated)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    PolicySection(title: "1. Introduction") {
                        Text("Slumberscope (\"the App\") is a sleep tracking application. This Privacy Policy explains what information we collect, how it is used, where it lives, and the choices you have. Please read it together with our Terms of Service.")
                    }

                    PolicySection(title: "2. Data We Collect") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The App collects the following information to provide its features:")
                            BulletPoint("Motion data from your device's accelerometer, used to detect restlessness and estimate sleep stages.")
                            BulletPoint("Audio amplitude and frequency measurements from your microphone, used to detect snoring and classify background noise on device.")
                            BulletPoint("Sleep session timestamps, including start time, end time, quality rating, and optional notes.")
                            BulletPoint("Profile information you provide during onboarding such as first name, last name, age, gender, and sleep goal.")
                            BulletPoint("Account information tied to your sign-in method. For email sign-in this is your email and a Firebase-hashed password. For Sign in with Apple this is an Apple user identifier and, if you share it, your real or relay email.")
                            BulletPoint("App settings and preferences such as reminder times, sensitivity, and which media sources are enabled.")
                        }
                    }

                    PolicySection(title: "3. How We Use Your Data") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your data is used to:")
                            BulletPoint("Track sleep sessions and compute your sleep score, restfulness, and snoring metrics.")
                            BulletPoint("Generate insights, trends, and coaching tips.")
                            BulletPoint("Trigger smart-alarm wake-ups timed to a light sleep phase.")
                            BulletPoint("Let you export your history as a PDF report or CSV file.")
                            BulletPoint("Sign you back in securely and restore your data to a new device when you reinstall or switch phones.")
                        }
                    }

                    PolicySection(title: "4. Where Your Data Lives") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The App stores data in two places:")
                            BulletPoint("On your device, using SwiftData for sleep sessions, sleep factors, and sound presets. Settings are stored in the standard iOS UserDefaults. Your sign-in credential is stored in the iOS Keychain.")
                            BulletPoint("In Google Firebase, specifically Firebase Authentication for sign-in and Firebase Firestore for cloud backup of your sleep sessions and profile. Data is transmitted over HTTPS and stored in Google Cloud datacenters managed by Firebase. This allows you to recover your history on a new device.")
                        }
                    }

                    PolicySection(title: "5. What We Do Not Do") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To be clear about the limits:")
                            BulletPoint("We do not record, store, or upload audio recordings. Only numerical amplitude, frequency energy, and short-lived on-device classification labels are produced. Any snoring audio clip you record locally stays on your device and is never uploaded.")
                            BulletPoint("We do not use third-party analytics or advertising SDKs.")
                            BulletPoint("We do not sell, rent, or share your personal information with data brokers, insurers, or employers.")
                            BulletPoint("We do not use your data to train machine learning models outside the App.")
                        }
                    }

                    PolicySection(title: "6. Third-Party Services") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The App uses the following third-party services. Each is governed by its own privacy policy.")
                            BulletPoint("Google Firebase (Authentication, Firestore): stores your account credentials and synced sleep data. See policies.google.com.")
                            BulletPoint("Apple Sign in with Apple, HealthKit, WeatherKit, MusicKit, and SoundAnalysis: covered by Apple's privacy policy at apple.com/legal/privacy.")
                            BulletPoint("Apple iTunes Podcast Search API: used to find podcasts by keyword. We send only your search term. No account data is attached.")
                            BulletPoint("Podcast audio feeds: when you pick an episode, your device streams the MP3 or M4A file directly from the podcast publisher. Slumberscope does not proxy the stream.")
                        }
                    }

                    PolicySection(title: "7. Apple HealthKit") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you opt in to HealthKit:")
                            BulletPoint("Sleep sessions may be written to Apple Health as sleep analysis samples.")
                            BulletPoint("This data is governed by Apple's HealthKit privacy terms.")
                            BulletPoint("We do not read HealthKit data back into Firebase.")
                            BulletPoint("You may revoke HealthKit access at any time in the iOS Settings app.")
                        }
                    }

                    PolicySection(title: "8. Microphone") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The microphone is used only for sleep tracking and only during an active tracking session.")
                            BulletPoint("Audio buffers are processed in real time using on-device signal processing (FFT and Apple's SoundAnalysis framework).")
                            BulletPoint("Only numerical results (amplitude, frequency band energy, classification labels) are stored.")
                            BulletPoint("No audio recording is ever sent off the device.")
                            BulletPoint("Audio tracking can be turned off in Settings.")
                        }
                    }

                    PolicySection(title: "9. Apple Music") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you connect Apple Music in Settings or during the Get Ready for Bed flow:")
                            BulletPoint("Slumberscope uses Apple's MusicKit framework to search the Apple Music catalog and play songs or playlists you choose.")
                            BulletPoint("Apple manages your Apple Music subscription and privacy.")
                            BulletPoint("We do not read your listening history or upload what you played to Firebase.")
                            BulletPoint("You may disable Apple Music integration in Settings at any time.")
                        }
                    }

                    PolicySection(title: "10. Podcasts") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you enable Podcasts:")
                            BulletPoint("We query the public iTunes Podcast Search API with the search term you type. No account is required.")
                            BulletPoint("We fetch the podcast's public RSS feed and play the episode you select directly on your device.")
                            BulletPoint("We do not report episode plays to any third party.")
                            BulletPoint("You may disable Podcasts in Settings at any time.")
                        }
                    }

                    PolicySection(title: "11. Your Rights") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You have full control over your data:")
                            BulletPoint("View and edit every sleep session in the History tab.")
                            BulletPoint("Delete individual sessions with a swipe, or delete your entire account from Settings > Profile > Delete Account & All Data.")
                            BulletPoint("Export your history as a PDF report or CSV file.")
                            BulletPoint("Revoke microphone, motion, location, HealthKit, or notification permissions from the iOS Settings app.")
                            BulletPoint("Sign out at any time. Signing out wipes all local data from the device while preserving your cloud backup.")
                        }
                    }

                    PolicySection(title: "12. GDPR (European Economic Area)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you live in the EEA:")
                            BulletPoint("Processing is based on your consent, given when you create an account and enable each feature.")
                            BulletPoint("You have the right to access, correct, export, restrict, and erase your data.")
                            BulletPoint("You have the right to withdraw consent at any time.")
                            BulletPoint("Data syncs to Google Firebase infrastructure, which may include servers outside the EEA. Google uses Standard Contractual Clauses for international transfers. See Google's Privacy Policy for details.")
                        }
                    }

                    PolicySection(title: "13. CCPA (California)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you live in California:")
                            BulletPoint("We do not sell your personal information.")
                            BulletPoint("We do not share your personal information for cross-context behavioral advertising.")
                            BulletPoint("You have the right to know, access, delete, and correct personal information we hold about you.")
                            BulletPoint("You will not be discriminated against for exercising your rights.")
                        }
                    }

                    PolicySection(title: "14. Consumer Health Data") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sleep, motion, and audio information collected by Slumberscope may be considered consumer health data under certain state laws.")
                            BulletPoint("Slumberscope is not a medical device and does not diagnose any condition.")
                            BulletPoint("We do not share consumer health data with insurers, employers, advertisers, or data brokers.")
                            BulletPoint("You can delete your health-related data at any time.")
                        }
                    }

                    PolicySection(title: "15. Children's Privacy") {
                        Text("Slumberscope is not directed to children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with data, contact us and we will delete it.")
                    }

                    PolicySection(title: "16. Changes to This Policy") {
                        Text("We may update this Privacy Policy from time to time. Material changes will be surfaced in the App, and the \"Last updated\" date above will be revised. Continued use of Slumberscope after a change means you accept the updated policy.")
                    }

                    PolicySection(title: "17. Contact") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Questions about this Privacy Policy, your data, or a privacy request:")
                            BulletPoint("Email: \(Self.supportEmail)")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - PolicySection

private struct PolicySection<Content: View>: View {

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - BulletPoint

private struct BulletPoint: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .fontWeight(.bold)
            Text(text)
        }
    }
}
