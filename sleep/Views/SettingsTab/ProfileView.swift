//
//  ProfileView.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import AuthenticationServices
import os
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(SleepSettings.self) private var settings
    @Environment(AuthenticationService.self) private var authService
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SleepSession]
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var isDeleting = false

    private let genderOptions = ["Not specified", "Male", "Female", "Non-binary", "Prefer not to say"]

    var body: some View {
        @Bindable var settings = settings

        Form {
            // MARK: Profile Info
            Section {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 4) {
                        if !settings.userName.isEmpty {
                            Text(settings.userName)
                                .font(.title3)
                                .fontWeight(.semibold)
                        } else {
                            Text("Set up your profile")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        if authService.isSignedIn {
                            Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("Name", text: $settings.userName)

                Stepper("Age: \(settings.userAge)", value: $settings.userAge, in: 13...120)

                Picker("Gender", selection: $settings.userGender) {
                    ForEach(genderOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            } footer: {
                Text("Used for age-based sleep recommendations and benchmark comparisons.")
            }

            Section("Sleep Goal") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target: \(String(format: "%.1f", settings.sleepGoalHours)) hours")
                        .font(.subheadline)
                    Slider(value: $settings.sleepGoalHours, in: 5...12, step: 0.5)
                        .tint(.green)

                    // Age-based recommendation
                    let recommended = recommendedSleep(age: settings.userAge)
                    Text("Recommended for your age: \(recommended)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: Account
            Section("Account") {
                if authService.isSignedIn {
                    HStack {
                        Text("Apple ID")
                        Spacer()
                        Text(authService.userEmail ?? "Connected")
                            .foregroundStyle(.secondary)
                    }

                    Button("Sign Out", role: .destructive) {
                        showingSignOutConfirmation = true
                    }
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            authService.handleAuthorization(result: authorization)
                            if let name = authService.userName {
                                settings.userName = name
                            }
                        case .failure(let error):
                            print("Sign in failed: \(error)")
                        }
                    }
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // MARK: Danger Zone
            Section {
                Button("Delete Account & All Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } footer: {
                Text("This will permanently delete your account and all sleep data. This action cannot be undone.")
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                authService.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can sign back in anytime.")
        }
        .alert("Delete Everything?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteEverything()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account, \(sessions.count) sleep sessions, and all settings. This cannot be undone.")
        }
    }

    private func deleteEverything() {
        AppLogger.auth.info("🔐 User requested account & data deletion")

        // 1. Delete all SwiftData sessions
        for session in sessions {
            modelContext.delete(session)
        }
        try? modelContext.save()
        AppLogger.auth.info("🔐 Deleted \(sessions.count) sleep sessions")

        // 2. Delete Firebase user data & sign out
        authService.deleteFirebaseAccount()

        // 3. Sign out of Apple ID
        authService.signOut()

        // 4. Reset all settings to defaults
        settings.userName = ""
        settings.userLastName = ""
        settings.userAge = 30
        settings.userGender = "Not specified"
        settings.sleepGoalHours = 8.0
        settings.hasCompletedOnboarding = false
        AppLogger.auth.info("🔐 All data deleted and settings reset")
    }

    private func recommendedSleep(age: Int) -> String {
        recommendedSleepLabel(forAge: age)
    }
}
