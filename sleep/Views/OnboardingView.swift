//
//  OnboardingView.swift
//  sleep
//

import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import os
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {

    let onComplete: () -> Void

    @State private var currentPage = 0
    private let totalPages = 5

    private let permissionService = PermissionService.shared

    var body: some View {
        ZStack(alignment: .top) {
            if currentPage > 0 {
                ProgressBar(current: currentPage, total: totalPages)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .zIndex(1)
            }

            Group {
                switch currentPage {
                case 0:
                    SplashPage { advance() }
                case 1:
                    AccountSetupPage { advance() }
                case 2:
                    SignInPage { advance() }
                case 3:
                    PermissionsPage(permissionService: permissionService) { advance() }
                case 4:
                    InteractiveTutorialPage { onComplete() }
                default:
                    EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
        }
        .interactiveDismissDisabled()
    }

    private func advance() {
        withAnimation { currentPage += 1 }
    }
}

// MARK: - ProgressBar

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.cyan : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

// MARK: - SplashPage

private struct SplashPage: View {

    let onContinue: () -> Void

    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var teamHeaderOpacity: Double = 0
    @State private var visibleMembers: Int = 0
    @State private var universityOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private let team = [
        (name: "Simon Alberico", role: "Cyber Security", initials: "SA", colors: [Color.cyan, Color.blue]),
        (name: "Aia Ahmed", role: "Software Engineering", initials: "AA", colors: [Color.purple, Color.pink]),
        (name: "Ananjin Batdelger", role: "Computer Science", initials: "AB", colors: [Color.green, Color.teal])
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .stroke(.cyan.opacity(0.2), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)

                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .cyan.opacity(0.6), radius: glowRadius)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }

                Text("Welcome to Slumberscope")
                    .font(.largeTitle).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .offset(y: titleOffset).opacity(titleOpacity)

                Text("Track your sleep patterns, detect snoring, and wake up refreshed with intelligent insights.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .offset(y: subtitleOffset).opacity(subtitleOpacity)

                VStack(spacing: 12) {
                    Text("Meet the Team")
                        .font(.title3).fontWeight(.semibold)
                        .opacity(teamHeaderOpacity)

                    ForEach(Array(team.enumerated()), id: \.offset) { index, member in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: member.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                Text(member.initials)
                                    .font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name).font(.subheadline).fontWeight(.semibold)
                                Text(member.role).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(visibleMembers > index ? 1 : 0)
                        .offset(y: visibleMembers > index ? 0 : 16)
                        .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(index) * 0.15), value: visibleMembers)
                    }
                }
                .padding(.horizontal, 32)

                VStack(spacing: 4) {
                    Text("Gannon University").font(.headline).fontWeight(.semibold)
                    Text("Senior Design \u{2022} Spring 2026").font(.subheadline).foregroundStyle(.secondary)
                }
                .opacity(universityOpacity).padding(.top, 8)

                PrimaryButton(title: "Get Started") { onContinue() }
                    .padding(.horizontal, 32)
                    .opacity(buttonOpacity)
                    .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.1)) {
                iconScale = 1.0; iconOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.4)) { glowRadius = 20 }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) { titleOffset = 0; titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { subtitleOffset = 0; subtitleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(1.2)) { teamHeaderOpacity = 1 }
            withAnimation(.easeOut(duration: 0.1).delay(1.4)) { visibleMembers = team.count }
            withAnimation(.easeOut(duration: 0.5).delay(2.2)) { universityOpacity = 1 }
            withAnimation(.easeIn(duration: 0.4).delay(2.6)) { buttonOpacity = 1 }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false).delay(0.8)) {
                pulseScale = 1.8
            }
        }
    }
}

// MARK: - AccountSetupPage

private struct AccountSetupPage: View {

    let onContinue: () -> Void

    @Environment(SleepSettings.self) private var settings
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var age: Int = 22
    @State private var goalHours: Double = 8.0
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case first, last }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 50)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 64))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    .opacity(titleOpacity)

                Text("Create Your Profile")
                    .font(.title).fontWeight(.bold).opacity(titleOpacity)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("First Name").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                        TextField("First name", text: $firstName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .first)
                            .padding(12).background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .submitLabel(.next)
                            .onSubmit { focusedField = .last }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Name").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                        TextField("Last name", text: $lastName)
                            .textContentType(.familyName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .last)
                            .padding(12).background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)

                VStack(spacing: 8) {
                    Text("Age").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        Button { if age > 13 { age -= 1; updateGoalForAge() } } label: {
                            Image(systemName: "minus.circle.fill").font(.title).foregroundStyle(.secondary)
                        }
                        Text("\(age)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan).frame(minWidth: 80)
                        Button { if age < 100 { age += 1; updateGoalForAge() } } label: {
                            Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(.secondary)
                        }
                    }
                    Text("Recommended: \(recommendedSleepLabel(forAge: age))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .opacity(contentOpacity)

                VStack(spacing: 8) {
                    Text("Your Sleep Goal").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", goalHours)) hours")
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.green)
                    Slider(value: $goalHours, in: 5...12, step: 0.5).tint(.green).padding(.horizontal, 40)
                    Text("Adjust if you'd like a different target").font(.caption).foregroundStyle(.tertiary)
                }
                .opacity(contentOpacity)

                PrimaryButton(title: "Continue") {
                    saveProfile()
                    onContinue()
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)

                if firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("Please enter your first and last name to continue")
                        .font(.caption).foregroundStyle(.red.opacity(0.8)).padding(.horizontal, 32)
                }

                Spacer(minLength: 40)
            }
        }
        .scrollIndicators(.hidden)
        .onTapGesture { focusedField = nil }
        .onAppear {
            firstName = settings.userName
            lastName = settings.userLastName
            age = settings.userAge > 0 ? settings.userAge : 22
            goalHours = recommendedSleepHours(forAge: age)
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { contentOpacity = 1 }
        }
    }

    private func updateGoalForAge() { goalHours = recommendedSleepHours(forAge: age) }

    private func saveProfile() {
        settings.userName = firstName
        settings.userLastName = lastName
        settings.userAge = age
        settings.sleepGoalHours = goalHours
    }
}

// MARK: - SignInPage

private struct SignInPage: View {

    let onContinue: () -> Void

    @Environment(AuthenticationService.self) private var authService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var didSignIn = false
    @State private var showEmailForm = false
    @State private var titleOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 50)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.cyan)
                    .opacity(titleOpacity)

                Text("Your Account")
                    .font(.title).fontWeight(.bold)
                    .opacity(titleOpacity)

                Text("Sign in to securely save your sleep data.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(contentOpacity)

                if didSignIn {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(.green)
                        Text("Signed in successfully!")
                            .font(.headline)
                    }
                    .transition(.scale.combined(with: .opacity))

                } else {
                    VStack(spacing: 16) {

                        // MARK: Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            AppLogger.auth.info("🔐 Sign In with Apple request initiated")
                            request.requestedScopes = [.fullName, .email]
                            let hashedNonce = authService.prepareNonce()
                            request.nonce = hashedNonce
                        } onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                AppLogger.auth.info("🔐 Sign In with Apple succeeded")
                                authService.handleAuthorization(result: auth)
                                withAnimation { didSignIn = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onContinue() }
                            case .failure(let error):
                                AppLogger.auth.error("🔐 Apple sign-in failed: \(error.localizedDescription)")
                            }
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 50)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                            Text("or").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        }

                        // MARK: Email option
                        if showEmailForm {
                            VStack(spacing: 14) {

                                // Email field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Email").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                                    TextField("your@email.com", text: $email)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .padding(12).background(.regularMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .submitLabel(.next)
                                        .onSubmit { focusedField = .password }
                                }

                                // Password field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Password").font(.subheadline).fontWeight(.medium).foregroundStyle(.secondary)
                                    SecureField("Password", text: $password)
                                        .textContentType(isSignUp ? .newPassword : .password)
                                        .focused($focusedField, equals: .password)
                                        .padding(12).background(.regularMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .submitLabel(.done)
                                        .onSubmit { focusedField = nil; handleAuth() }
                                }

                                // Error message
                                if let error = errorMessage {
                                    Text(error).font(.caption).foregroundStyle(.red)
                                        .multilineTextAlignment(.center)
                                }

                                // Submit button
                                if isLoading {
                                    ProgressView().padding()
                                } else {
                                    PrimaryButton(title: isSignUp ? "Create Account" : "Sign In") {
                                        handleAuth()
                                    }
                                    .disabled(email.isEmpty || password.isEmpty)
                                    .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1.0)
                                }

                                // Toggle sign in / sign up
                                Button {
                                    withAnimation { isSignUp.toggle(); errorMessage = nil }
                                } label: {
                                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Create one")
                                        .font(.subheadline).foregroundStyle(.cyan)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))

                        } else {
                            // Show email button
                            Button {
                                withAnimation { showEmailForm = true }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text("Continue with Email").font(.headline)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 40)
                    .opacity(contentOpacity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    Text("Your data is encrypted and private.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .opacity(contentOpacity)

                Spacer()

                if !didSignIn {
                    Button("Skip for Now") { onContinue() }
                        .font(.headline).foregroundStyle(.secondary)
                        .padding(.bottom, 50)
                        .opacity(contentOpacity)
                }
            }
        }
        .scrollIndicators(.hidden)
        .onTapGesture { focusedField = nil }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { contentOpacity = 1 }
        }
    }

    private func handleAuth() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        focusedField = nil

        Task {
            do {
                if isSignUp {
                    let result = try await Auth.auth().createUser(withEmail: email, password: password)
                    let uid = result.user.uid
                    let db = Firestore.firestore()
                    try await db.collection("users").document(uid).setData([
                        "email": email,
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastSynced": FieldValue.serverTimestamp(),
                        "platform": "ios"
                    ], merge: true)
                    AppLogger.auth.info("🔐 New account created — uid: \(uid)")
                } else {
                    let result = try await Auth.auth().signIn(withEmail: email, password: password)
                    AppLogger.auth.info("🔐 Signed in — uid: \(result.user.uid)")
                }

                await MainActor.run {
                    isLoading = false
                    withAnimation { didSignIn = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { onContinue() }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = friendlyError(error)
                }
            }
        }
    }

    private func friendlyError(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17007: return "An account with this email already exists."
        case 17009: return "Incorrect password. Please try again."
        case 17011: return "No account found with this email."
        case 17026: return "Password must be at least 6 characters."
        case 17008: return "Please enter a valid email address."
        default: return error.localizedDescription
        }
    }
}

// MARK: - PermissionsPage

private struct PermissionsPage: View {

    let permissionService: PermissionService
    let onContinue: () -> Void

    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var visibleRows: Int = 0
    @State private var buttonOpacity: Double = 0
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .opacity(titleOpacity)

            Text("Permissions")
                .font(.title).fontWeight(.bold).opacity(titleOpacity)

            Text("Slumberscope needs a few permissions to track your sleep effectively.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
                .opacity(subtitleOpacity)

            VStack(spacing: 16) {
                let rows: [(icon: String, color: Color, title: String, desc: String, granted: Bool)] = [
                    ("mic.fill", .yellow, "Microphone", "Detects snoring patterns", permissionService.microphoneGranted),
                    ("move.3d", .green, "Motion", "Accelerometer (no permission needed)", permissionService.motionAvailable),
                    ("heart.fill", .red, "HealthKit", "Syncs with Apple Health", permissionService.healthKitAuthorized),
                    ("bell.fill", .blue, "Notifications", "Bedtime reminders & summaries", permissionService.notificationsAuthorized),
                    ("location.fill", .cyan, "Location", "Weather when you wake up", permissionService.locationAuthorized)
                ]
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    PermissionRow(icon: row.icon, color: row.color, title: row.title, description: row.desc, granted: row.granted)
                        .opacity(visibleRows > index ? 1 : 0)
                        .offset(x: visibleRows > index ? 0 : 20)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.1), value: visibleRows)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRequesting = true
                    Task {
                        await permissionService.requestAllPermissions()
                        isRequesting = false
                        onContinue()
                    }
                } label: {
                    HStack {
                        if isRequesting { ProgressView().tint(.white).padding(.trailing, 4) }
                        Text(isRequesting ? "Requesting\u{2026}" : "Grant Permissions & Continue").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32).opacity(buttonOpacity).disabled(isRequesting)

                Button("Skip for Now") { onContinue() }
                    .font(.subheadline).foregroundStyle(.secondary).opacity(buttonOpacity)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { titleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) { subtitleOpacity = 1 }
            withAnimation(.easeOut(duration: 0.1).delay(0.35)) { visibleRows = 4 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7)) { buttonOpacity = 1 }
        }
    }
}

// MARK: - InteractiveTutorialPage

private struct InteractiveTutorialPage: View {

    let onComplete: () -> Void

    @Environment(SleepSettings.self) private var settings
    @State private var tutorialStep = 0
    @State private var stepOpacity: Double = 0
    @State private var phoneOffset: CGFloat = 50
    @State private var mockTracking = false
    @State private var mockScore: Double = 0

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip Tutorial") { onComplete() }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.trailing, 24).padding(.top, 16)
            }

            Spacer()

            Group {
                switch tutorialStep {
                case 0: placementStep
                case 1: trackingStep
                case 2: resultsStep
                case 3: aiStep
                default: EmptyView()
                }
            }
            .opacity(stepOpacity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: tutorialStep)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == tutorialStep ? Color.cyan : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 16)

            PrimaryButton(title: tutorialStep < totalSteps - 1 ? "Next" : "Start Sleeping Better") {
                if tutorialStep < totalSteps - 1 {
                    withAnimation { stepOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        tutorialStep += 1
                        withAnimation(.easeOut(duration: 0.3)) { stepOpacity = 1 }
                    }
                } else {
                    onComplete()
                }
            }
            .padding(.horizontal, 32).padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { stepOpacity = 1 }
        }
    }

    private var placementStep: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [.indigo.opacity(0.3), .purple.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 260, height: 140)
                Capsule().fill(.white.opacity(0.15)).frame(width: 100, height: 50).offset(x: -60, y: -10)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.cyan.opacity(0.8), .blue.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 35, height: 65)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.3), lineWidth: 1))
                    .offset(x: 20, y: phoneOffset > 0 ? phoneOffset : 0)
                    .shadow(color: .cyan.opacity(0.4), radius: 8)
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) { phoneOffset = 0 }
            }

            Text("Place Your Phone").font(.title2).fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                TutorialBullet(icon: "bed.double.fill", color: .indigo, text: "Place on mattress near your pillow")
                TutorialBullet(icon: "iphone.gen3", color: .cyan, text: "Keep face down to reduce light")
                TutorialBullet(icon: "battery.100.bolt", color: .green, text: "Plug in or ensure good charge")
                TutorialBullet(icon: "mic.fill", color: .yellow, text: "Keep microphone unobstructed")
            }
            .padding(.horizontal, 40)
        }
    }

    private var trackingStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(.cyan.opacity(0.2), lineWidth: 3).frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: mockTracking ? 0.7 : 0)
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 160, height: 160).rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill").font(.system(size: 32)).foregroundStyle(.cyan)
                    Text(mockTracking ? "Tracking..." : "Ready").font(.caption).foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).delay(0.5)) { mockTracking = true }
            }

            Text("Sleep Tracking").font(.title2).fontWeight(.bold)
            Text("Tap \"Track\" to start recording. Slumberscope monitors your movement, audio, and sleep stages throughout the night.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    private var resultsStep: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(.secondary.opacity(0.2), lineWidth: 8).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: mockScore)
                    .stroke(
                        LinearGradient(colors: [.green, .cyan], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140).rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int(mockScore * 100))").font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("Sleep Score").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).delay(0.3)) { mockScore = 0.85 }
            }

            Text("Morning Review").font(.title2).fontWeight(.bold)
            Text("Each morning you'll get a sleep score, detailed breakdown of your sleep stages, snoring events, and personalized tips.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)

            HStack(spacing: 24) {
                MockStat(label: "Deep", value: "1h 42m", color: .indigo)
                MockStat(label: "REM", value: "2h 05m", color: .cyan)
                MockStat(label: "Snoring", value: "12 min", color: .orange)
            }
        }
    }

    private var aiStep: some View {
        VStack(spacing: 20) {
            @Bindable var settings = settings

            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))

            Text("AI Sleep Coach").font(.title2).fontWeight(.bold)

            if #available(iOS 26, *) {
                Text("Your device supports Apple Intelligence! Get personalized insights powered by on-device AI.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                Toggle("Enable AI Coaching", isOn: $settings.aiCoachingEnabled).padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    Text("All AI runs on-device. No data leaves your phone.").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
            } else {
                Text("AI coaching requires iPhone 15 Pro or newer. You'll still get rule-based sleep tips and insights.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Rule-based coaching is enabled by default.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Reusable Components

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.headline)
                .frame(maxWidth: .infinity).padding()
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct TutorialBullet: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).foregroundStyle(color).frame(width: 32)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct MockStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    let granted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .secondary)
        }
    }
}
