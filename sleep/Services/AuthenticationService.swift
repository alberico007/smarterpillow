//
//  AuthenticationService.swift
//  sleep
//
//  Created by Michael Berinshteyn on 3/17/26.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import os

@Observable
final class AuthenticationService {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let isSignedIn = "auth_isSignedIn"
        static let userID = "auth_userID"
        static let userName = "auth_userName"
        static let userEmail = "auth_userEmail"
    }

    /// The raw nonce for the current sign-in attempt (needed by Firebase)
    private(set) var currentNonce: String?

    // MARK: - Observable State

    var isSignedIn: Bool {
        didSet { UserDefaults.standard.set(isSignedIn, forKey: Keys.isSignedIn) }
    }

    var userID: String? {
        didSet { UserDefaults.standard.set(userID, forKey: Keys.userID) }
    }

    var userName: String? {
        didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
    }

    var userEmail: String? {
        didSet { UserDefaults.standard.set(userEmail, forKey: Keys.userEmail) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        self.isSignedIn = defaults.bool(forKey: Keys.isSignedIn)
        self.userID = defaults.string(forKey: Keys.userID)
        self.userName = defaults.string(forKey: Keys.userName)
        self.userEmail = defaults.string(forKey: Keys.userEmail)

        if isSignedIn {
            Task { await checkCredentialState() }
        }
    }

    // MARK: - Nonce

    /// Generate a random nonce and store it. Returns the SHA256 hash for the Apple request.
    func prepareNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Sign In With Apple Request

    func signInWithApple() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        return request
    }

    // MARK: - Handle Authorization

    func handleAuthorization(result: ASAuthorization) {
        guard let credential = result.credential as? ASAuthorizationAppleIDCredential else {
            AppLogger.auth.error("Unexpected credential type")
            return
        }

        let userIdentifier = credential.user

        // Name and email are only provided on first authorization
        if let fullName = credential.fullName {
            let givenName = fullName.givenName ?? ""
            let familyName = fullName.familyName ?? ""
            let name = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
            if !name.isEmpty {
                userName = name
            }
        }

        if let email = credential.email {
            userEmail = email
        }

        userID = userIdentifier
        isSignedIn = true
        AppLogger.auth.info("🔐 User signed in: \(userIdentifier)")

        // Store user identifier in Keychain for more secure persistence
        saveToKeychain(userIdentifier: userIdentifier)

        // Sign in to Firebase with the Apple credential
        signInToFirebase(with: credential)
    }

    // MARK: - Sign Out

    func signOut() {
        AppLogger.auth.info("🔐 User signed out")
        isSignedIn = false
        userID = nil
        userName = nil
        userEmail = nil
        removeFromKeychain()
        firebaseSignOut()
    }

    // MARK: - Check Credential State

    func checkCredentialState() async {
        guard let userID = userID else {
            await MainActor.run { isSignedIn = false }
            return
        }

        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await provider.credentialState(forUserID: userID)
            await MainActor.run {
                switch state {
                case .authorized:
                    self.isSignedIn = true
                case .revoked, .notFound:
                    self.signOut()
                case .transferred:
                    // Handle account transfer if needed
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            AppLogger.auth.error("Failed to check credential state: \(error.localizedDescription)")
        }
    }

    // MARK: - Keychain Helpers

    private static let keychainService = "smarter-pillow.sleep.auth"
    private static let keychainAccount = "appleIDUserIdentifier"

    private func saveToKeychain(userIdentifier: String) {
        guard let data = userIdentifier.data(using: .utf8) else { return }

        // Delete any existing entry first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new entry
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            AppLogger.auth.error("Failed to save user identifier to Keychain: \(status)")
        }
    }

    private func removeFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    func loadUserIdentifierFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Firebase Integration

    private func signInToFirebase(with credential: ASAuthorizationAppleIDCredential) {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            AppLogger.auth.error("🔐 Missing identity token for Firebase sign-in")
            return
        }

        guard let nonce = currentNonce else {
            AppLogger.auth.error("🔐 Missing nonce for Firebase sign-in — was prepareNonce() called?")
            return
        }

        let firebaseCredential = OAuthProvider.credential(
            providerID: .apple,
            idToken: tokenString,
            rawNonce: nonce
        )

        Task {
            do {
                let result = try await Auth.auth().signIn(with: firebaseCredential)
                let uid = result.user.uid
                AppLogger.auth.info("🔐 Firebase signed in — uid: \(uid)")
                await saveUserProfile(uid: uid)
            } catch {
                AppLogger.auth.error("🔐 Firebase sign-in failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveUserProfile(uid: String) async {
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "name": userName ?? "",
            "email": userEmail ?? "",
            "appleUserID": userID ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        do {
            try await db.collection("users").document(uid).setData(data, merge: true)
            AppLogger.auth.info("🔐 User profile saved to Firestore")
        } catch {
            AppLogger.auth.error("🔐 Firestore save failed: \(error.localizedDescription)")
        }
    }

    /// Save sleep settings to Firestore for the current user
    func syncSettings(_ settings: SleepSettings) {
        guard let firebaseUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "firstName": settings.userName,
            "lastName": settings.userLastName,
            "age": settings.userAge,
            "sleepGoalHours": settings.sleepGoalHours,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        db.collection("users").document(firebaseUser.uid).setData(data, merge: true) { error in
            if let error {
                AppLogger.auth.error("🔐 Settings sync failed: \(error.localizedDescription)")
            } else {
                AppLogger.auth.info("🔐 Settings synced to Firestore")
            }
        }
    }

    /// Delete Firebase user account and their Firestore data
    func deleteFirebaseAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let db = Firestore.firestore()

        // Delete Firestore user document
        db.collection("users").document(uid).delete { error in
            if let error {
                AppLogger.auth.error("🔐 Firestore user delete failed: \(error.localizedDescription)")
            } else {
                AppLogger.auth.info("🔐 Firestore user document deleted")
            }
        }

        // Delete Firebase Auth account
        user.delete { error in
            if let error {
                AppLogger.auth.error("🔐 Firebase account delete failed: \(error.localizedDescription)")
            } else {
                AppLogger.auth.info("🔐 Firebase account deleted")
            }
        }
    }

    func firebaseSignOut() {
        do {
            try Auth.auth().signOut()
            AppLogger.auth.info("🔐 Firebase signed out")
        } catch {
            AppLogger.auth.error("🔐 Firebase sign-out failed: \(error.localizedDescription)")
        }
    }
}
