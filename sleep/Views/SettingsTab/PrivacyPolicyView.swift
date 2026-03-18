//
//  PrivacyPolicyView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import SwiftUI

struct PrivacyPolicyView: View {

    @Environment(\.dismiss) private var dismiss

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
                            Text("Last updated: March 2026")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    // Section 1: Introduction
                    PolicySection(title: "1. Introduction") {
                        Text("Slumberscope (\"the App\") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your personal information when you use our sleep tracking application.")
                    }

                    // Section 2: Data We Collect
                    PolicySection(title: "2. Data We Collect") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("We collect the following data to provide sleep tracking functionality:")
                            BulletPoint("Motion data from your device's accelerometer to detect sleep movements and restlessness")
                            BulletPoint("Audio amplitude data from your device's microphone to detect snoring patterns")
                            BulletPoint("FFT (Fast Fourier Transform) frequency analysis of audio to identify snoring frequency bands")
                            BulletPoint("Sleep session timestamps (start and end times)")
                            BulletPoint("User-provided sleep quality ratings and notes")
                            BulletPoint("App settings and preferences")
                        }
                    }

                    // Section 3: How We Use Your Data
                    PolicySection(title: "3. How We Use Your Data") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your data is used exclusively to:")
                            BulletPoint("Track and analyze your sleep patterns")
                            BulletPoint("Generate sleep scores and quality metrics")
                            BulletPoint("Provide sleep insights and trends")
                            BulletPoint("Trigger smart alarm functionality based on sleep phases")
                            BulletPoint("Generate exportable reports (PDF and CSV)")
                        }
                    }

                    // Section 4: Data We Do NOT Collect
                    PolicySection(title: "4. Data We Do NOT Collect") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("We want to be completely transparent:")
                            BulletPoint("We do NOT record or store audio recordings. Only amplitude and frequency data is processed in real-time.")
                            BulletPoint("We do NOT transmit any data to external servers")
                            BulletPoint("We do NOT use analytics or tracking SDKs")
                            BulletPoint("We do NOT collect location data")
                            BulletPoint("We do NOT collect personally identifiable information beyond what you voluntarily enter")
                            BulletPoint("We do NOT sell, share, or rent your data to third parties")
                        }
                    }

                    // Section 5: HealthKit Integration
                    PolicySection(title: "5. Apple HealthKit") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you choose to enable HealthKit integration:")
                            BulletPoint("Sleep data may be written to Apple Health as sleep analysis samples")
                            BulletPoint("This data is governed by Apple's HealthKit privacy policies")
                            BulletPoint("We only write data to HealthKit when you explicitly enable this feature")
                            BulletPoint("HealthKit data is never used for advertising or shared with third parties")
                            BulletPoint("You can revoke HealthKit access at any time through iOS Settings")
                        }
                    }

                    // Section 6: Microphone Usage
                    PolicySection(title: "6. Microphone Usage") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The microphone is used exclusively for sleep tracking:")
                            BulletPoint("Audio is processed in real-time using on-device signal processing")
                            BulletPoint("Only numerical amplitude values and frequency band energy ratios are stored")
                            BulletPoint("No audio recordings are created, stored, or transmitted")
                            BulletPoint("The microphone is only active during an active sleep tracking session")
                            BulletPoint("You can disable audio tracking at any time in Settings")
                        }
                    }

                    // Section 7: Data Storage
                    PolicySection(title: "7. Data Storage") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("All data is stored locally on your device:")
                            BulletPoint("Sleep sessions are stored using SwiftData in a local database")
                            BulletPoint("Settings are stored in UserDefaults")
                            BulletPoint("Crash recovery data is stored temporarily in the app's Documents directory")
                            BulletPoint("No data is stored on external servers or cloud services")
                            BulletPoint("Data may be included in your iCloud device backups if enabled")
                        }
                    }

                    // Section 8: Your Rights
                    PolicySection(title: "8. Your Rights") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You have complete control over your data:")
                            BulletPoint("Delete individual sleep sessions by swiping in the History tab")
                            BulletPoint("Export your data in PDF or CSV format at any time")
                            BulletPoint("Revoke microphone, motion, HealthKit, or notification permissions through iOS Settings")
                            BulletPoint("Delete all app data by uninstalling the application")
                        }
                    }

                    // Section 9: GDPR Compliance
                    PolicySection(title: "9. GDPR Compliance") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("For users in the European Economic Area (EEA):")
                            BulletPoint("Data processing is based on your explicit consent")
                            BulletPoint("You have the right to access, rectify, and erase your data")
                            BulletPoint("You have the right to data portability (export features)")
                            BulletPoint("No data is transferred outside your device")
                            BulletPoint("You may withdraw consent at any time by disabling features or uninstalling")
                        }
                    }

                    // Section 10: CCPA Compliance
                    PolicySection(title: "10. CCPA Compliance") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("For California residents:")
                            BulletPoint("We do not sell personal information")
                            BulletPoint("We do not share personal information for cross-context behavioral advertising")
                            BulletPoint("You have the right to know what data is collected")
                            BulletPoint("You have the right to delete your data")
                            BulletPoint("You will not be discriminated against for exercising your privacy rights")
                        }
                    }

                    // Section 11: MHMDA Compliance
                    PolicySection(title: "11. Mental Health & Medical Data") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Regarding health data protections:")
                            BulletPoint("Sleep data collected by this app is not used for medical diagnosis")
                            BulletPoint("We comply with applicable consumer health data privacy laws")
                            BulletPoint("No health data is shared with insurers, employers, or data brokers")
                            BulletPoint("All health-related data processing occurs entirely on-device")
                        }
                    }

                    // Section 12: Children's Privacy
                    PolicySection(title: "12. Children's Privacy") {
                        Text("Slumberscope is not directed at children under 13. We do not knowingly collect personal information from children. If you believe a child has provided us with data, please contact us to have it removed.")
                    }

                    // Section 13: Changes to This Policy
                    PolicySection(title: "13. Changes to This Policy") {
                        Text("We may update this Privacy Policy from time to time. We will notify you of material changes through an in-app notification. Your continued use of the app after changes constitutes acceptance of the updated policy.")
                    }

                    // Section 14: Contact
                    PolicySection(title: "14. Contact Us") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If you have questions about this Privacy Policy or your data, please contact us:")
                            BulletPoint("Email: privacy@slumberscope.app")
                            BulletPoint("Website: https://slumberscope.app/privacy")
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
