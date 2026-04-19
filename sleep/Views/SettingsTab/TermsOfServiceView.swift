//
//  TermsOfServiceView.swift
//  sleep
//

import SwiftUI

struct TermsOfServiceView: View {

    @Environment(\.dismiss) private var dismiss

    private static let supportEmail = "alberico007@gannon.edu"
    private static let lastUpdated = "April 2026"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundStyle(.cyan)
                            Text("Terms of Service")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("Last updated: \(Self.lastUpdated)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    TermsSection(title: "1. Acceptance of Terms") {
                        Text("By downloading, installing, or using Slumberscope (\"the App\"), you agree to be bound by these Terms of Service. If you do not agree, do not use the App.")
                    }

                    TermsSection(title: "2. Description of Service") {
                        Text("Slumberscope is a sleep tracking application. It uses your device sensors to monitor sleep, detect snoring, and produce sleep quality insights. Optional features include Apple Music playback, in-app podcast playback, Apple HealthKit integration, and local weather display. Account data and sleep history are synced to Google Firebase so you can restore your history on a new device.")
                    }

                    TermsSection(title: "3. Medical Disclaimer") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IMPORTANT. PLEASE READ CAREFULLY.")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)

                            Text("Slumberscope is NOT a medical device and is NOT intended to diagnose, treat, cure, or prevent any disease or medical condition.")

                            Text("The sleep data, scores, and insights are for informational purposes only. They are not a substitute for professional medical advice, diagnosis, or treatment.")

                            Text("If you suspect a sleep disorder such as sleep apnea, insomnia, narcolepsy, or restless legs syndrome, consult a qualified healthcare professional. Snoring detection is not a substitute for a clinical sleep study.")

                            Text("Never disregard professional medical advice or delay seeking treatment because of information from this App.")
                        }
                    }

                    TermsSection(title: "4. User Responsibilities") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("As a user, you agree to:")
                            TermsBullet("Use the App only for personal sleep tracking.")
                            TermsBullet("Place your device safely during tracking so it will not fall or overheat.")
                            TermsBullet("Keep the device charged during a tracking session.")
                            TermsBullet("Not rely on the Smart Alarm as your only alarm for critical wake-ups. Always set a backup.")
                            TermsBullet("Provide accurate information when creating an account and keep your password confidential.")
                        }
                    }

                    TermsSection(title: "5. Account and Authentication") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Account security details:")
                            TermsBullet("You may sign in with an email and password or with Sign in with Apple.")
                            TermsBullet("Password policy: minimum 8 characters with at least one uppercase letter, one lowercase letter, one number, and one special character. The server enforces this policy for new passwords and password resets.")
                            TermsBullet("After 10 failed sign-in attempts, sign-in is temporarily locked for two hours. This protects your account from brute-force attacks.")
                            TermsBullet("Some sensitive actions may require email verification.")
                            TermsBullet("You are responsible for activity on your account. If you suspect unauthorized use, contact us at \(Self.supportEmail).")
                        }
                    }

                    TermsSection(title: "6. Data and Privacy") {
                        Text("Your use of the App is also governed by our Privacy Policy, which is incorporated by reference. Sensor data (motion, audio, heart rate when shared) is processed on your device. Account information, sleep sessions, and settings sync to Google Firebase for backup and multi-device restore.")
                    }

                    TermsSection(title: "7. HealthKit") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you enable HealthKit:")
                            TermsBullet("Sleep data written to Apple Health is governed by Apple's HealthKit terms.")
                            TermsBullet("You are responsible for managing HealthKit permissions in iOS Settings.")
                            TermsBullet("We do not read HealthKit back into Firebase.")
                            TermsBullet("HealthKit integration is optional and can be disabled at any time.")
                        }
                    }

                    TermsSection(title: "8. Apple Music") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apple Music integration is optional.")
                            TermsBullet("An active Apple Music subscription is required to play catalog content.")
                            TermsBullet("Apple manages authorization, subscription status, and playback rights through MusicKit.")
                            TermsBullet("Slumberscope does not store or transmit your Apple Music listening history.")
                        }
                    }

                    TermsSection(title: "9. Podcasts") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Podcast search and playback is optional.")
                            TermsBullet("Podcast discovery uses the public Apple iTunes Podcast Search API.")
                            TermsBullet("Your device streams the episode directly from the podcast publisher's feed.")
                            TermsBullet("Podcast content is owned by the respective publishers and governed by their terms.")
                            TermsBullet("We do not guarantee availability of any podcast or episode.")
                        }
                    }

                    TermsSection(title: "10. Smart Alarm Disclaimer") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Smart Alarm attempts to wake you during a light sleep phase.")
                            TermsBullet("This feature is provided as a convenience and is not a guaranteed alarm.")
                            TermsBullet("Trigger timing depends on sensor accuracy and environmental conditions.")
                            TermsBullet("Always set a backup alarm for any critical wake-up.")
                            TermsBullet("Slumberscope is not responsible for consequences of a missed or delayed alarm.")
                        }
                    }

                    TermsSection(title: "11. Intellectual Property") {
                        Text("All content, features, and functionality of Slumberscope, including the design, source code, algorithms, graphics, audio, and user interface, are owned by the developer and protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, or reverse-engineer any part of the App without written permission.")
                    }

                    TermsSection(title: "12. Sensor Accuracy") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Regarding measurement accuracy:")
                            TermsBullet("Results depend on device placement, sensor quality, and the environment.")
                            TermsBullet("Snoring detection is probabilistic and may produce false positives or false negatives, particularly when mechanical fans, air conditioners, pets, or speech are present.")
                            TermsBullet("Sleep stage estimation is approximate. It is derived from motion and audio, not clinical EEG.")
                            TermsBullet("Sleep scores are relative indicators, not clinical measurements.")
                        }
                    }

                    TermsSection(title: "13. Limitation of Liability") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TO THE MAXIMUM EXTENT PERMITTED BY LAW:")
                                .fontWeight(.semibold)
                            TermsBullet("The App is provided \"AS IS\" and \"AS AVAILABLE\" without warranties of any kind.")
                            TermsBullet("We disclaim all warranties, express or implied, including merchantability, fitness for a particular purpose, and non-infringement.")
                            TermsBullet("We shall not be liable for any indirect, incidental, special, consequential, or punitive damages.")
                            TermsBullet("Our total aggregate liability will not exceed the amount you paid for the App, or fifty US dollars if the App was free.")
                        }
                    }

                    TermsSection(title: "14. Third-Party Services") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The App integrates with the following third-party services. Each has its own terms of service.")
                            TermsBullet("Google Firebase (Authentication, Firestore).")
                            TermsBullet("Apple services: Sign in with Apple, HealthKit, WeatherKit, MusicKit, and SoundAnalysis.")
                            TermsBullet("Apple iTunes Podcast Search API and public podcast RSS feeds.")
                            TermsBullet("We do not control third-party services and are not responsible for their availability or changes to their terms.")
                        }
                    }

                    TermsSection(title: "15. Modifications to Terms") {
                        Text("We may modify these Terms. Material changes will be surfaced in the App and the \"Last updated\" date will be revised. Continued use after modifications constitutes acceptance of the updated Terms. If you disagree, stop using the App.")
                    }

                    TermsSection(title: "16. Termination") {
                        Text("You may stop using the App at any time. You may also delete your account and associated cloud data from Settings > Profile > Delete Account & All Data. We may terminate or suspend access for violations of these Terms.")
                    }

                    TermsSection(title: "17. Governing Law") {
                        Text("These Terms are governed by the laws of the United States and the state in which the developer resides, without regard to conflict of law principles. Disputes arising from these Terms will be resolved through binding arbitration where permitted by law.")
                    }

                    TermsSection(title: "18. Apple's Role") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("As required by Apple's App Store guidelines:")
                            TermsBullet("Apple is not a party to these Terms.")
                            TermsBullet("Apple has no obligation to provide support for the App.")
                            TermsBullet("Apple is not responsible for any claims related to the App.")
                            TermsBullet("Apple is a third-party beneficiary of these Terms with the right to enforce them.")
                        }
                    }

                    TermsSection(title: "19. Contact") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Questions about these Terms:")
                            TermsBullet("Email: \(Self.supportEmail)")
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - TermsSection

private struct TermsSection<Content: View>: View {

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

// MARK: - TermsBullet

private struct TermsBullet: View {

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
