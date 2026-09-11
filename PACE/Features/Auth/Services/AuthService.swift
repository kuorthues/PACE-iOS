//
//  AuthService.swift
//  PACE
//
//  Authentication service managing email/password authentication via Firebase Authentication.
//  Preserves strict error reporting when Firebase packages or GoogleService-Info.plist are missing
//  without faking success.
//

import SwiftUI
import Combine

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum AuthError: LocalizedError, Equatable {
    case validation(String)
    case firebaseNotConfigured(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        case .firebaseNotConfigured(let message):
            return message
        case .serverError(let message):
            return message
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: PACEUser? = nil
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var statusMessage: String? = nil
    
    // Configuration diagnostics
    @Published var isFirebaseLinked: Bool = false
    @Published var hasGoogleServicePlist: Bool = false
    @Published var isFirebaseConfigured: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkConfiguration()
        setupAuthStateListener()
    }
    
    func checkConfiguration() {
        // 1. Check if GoogleService-Info.plist exists in main bundle
        let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        hasGoogleServicePlist = (plistPath != nil)
        
        // 2. Check if Firebase SDK is compiled in
        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        isFirebaseLinked = true
        if hasGoogleServicePlist {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
            isFirebaseConfigured = true
        } else {
            isFirebaseConfigured = false
        }
        #else
        isFirebaseLinked = false
        isFirebaseConfigured = false
        #endif
    }
    
    private func setupAuthStateListener() {
        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if let user = user {
                        self.currentUser = PACEUser(
                            id: user.uid,
                            email: user.email ?? "",
                            displayName: user.displayName
                        )
                        self.isAuthenticated = true
                    } else {
                        self.currentUser = nil
                        self.isAuthenticated = false
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Validation
    
    func validateEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
    
    // MARK: - Registration
    
    func createAccount(name: String, email: String, password: String, confirmPassword: String) async throws {
        errorMessage = nil
        statusMessage = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validation checks
        guard !trimmedName.isEmpty else {
            let error = AuthError.validation("Name is required.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard !trimmedEmail.isEmpty else {
            let error = AuthError.validation("Email address is required.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard validateEmail(trimmedEmail) else {
            let error = AuthError.validation("Please enter a valid email address.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard password.count >= 6 else {
            let error = AuthError.validation("Password must be at least 6 characters.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard password == confirmPassword else {
            let error = AuthError.validation("Passwords do not match.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        // Verify Firebase environment - do NOT fake success if missing
        guard isFirebaseLinked else {
            let error = AuthError.firebaseNotConfigured("Firebase Authentication SDK is not linked. Add firebase-ios-sdk and GoogleService-Info.plist for mseud.edu.ph.PACE.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard hasGoogleServicePlist else {
            let error = AuthError.firebaseNotConfigured("GoogleService-Info.plist is missing in the app bundle. Add the configuration file to register users.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        #if canImport(FirebaseAuth)
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = trimmedName
            try await changeRequest.commitChanges()
            
            self.currentUser = PACEUser(
                id: result.user.uid,
                email: trimmedEmail,
                displayName: trimmedName
            )
            self.isAuthenticated = true
        } catch {
            let mapped = mapFirebaseError(error)
            self.errorMessage = mapped
            throw AuthError.serverError(mapped)
        }
        #endif
    }
    
    // MARK: - Login
    
    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        statusMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            let error = AuthError.validation("Email address is required.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard validateEmail(trimmedEmail) else {
            let error = AuthError.validation("Please enter a valid email address.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard !password.isEmpty else {
            let error = AuthError.validation("Password is required.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        // Verify Firebase environment - do NOT fake success if missing
        guard isFirebaseLinked else {
            let error = AuthError.firebaseNotConfigured("Firebase Authentication SDK is not linked. Add firebase-ios-sdk and GoogleService-Info.plist for mseud.edu.ph.PACE.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard hasGoogleServicePlist else {
            let error = AuthError.firebaseNotConfigured("GoogleService-Info.plist is missing in the app bundle. Add the configuration file to sign in.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        #if canImport(FirebaseAuth)
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
            self.currentUser = PACEUser(
                id: result.user.uid,
                email: result.user.email ?? trimmedEmail,
                displayName: result.user.displayName
            )
            self.isAuthenticated = true
        } catch {
            let mapped = mapFirebaseError(error)
            self.errorMessage = mapped
            throw AuthError.serverError(mapped)
        }
        #endif
    }
    
    // MARK: - Forgot Password
    
    func sendPasswordReset(email: String) async throws {
        errorMessage = nil
        statusMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            let error = AuthError.validation("Email address is required.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard validateEmail(trimmedEmail) else {
            let error = AuthError.validation("Please enter a valid email address.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard isFirebaseLinked else {
            let error = AuthError.firebaseNotConfigured("Firebase Authentication SDK is not linked. Add firebase-ios-sdk and GoogleService-Info.plist for mseud.edu.ph.PACE.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        guard hasGoogleServicePlist else {
            let error = AuthError.firebaseNotConfigured("GoogleService-Info.plist is missing. Add the configuration file to send password reset emails.")
            self.errorMessage = error.localizedDescription
            throw error
        }
        
        #if canImport(FirebaseAuth)
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
            self.statusMessage = "Password reset instructions sent to \(trimmedEmail)."
        } catch {
            let mapped = mapFirebaseError(error)
            self.errorMessage = mapped
            throw AuthError.serverError(mapped)
        }
        #endif
    }
    
    // MARK: - Logout
    
    func signOut() {
        errorMessage = nil
        statusMessage = nil
        
        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            try? Auth.auth().signOut()
        }
        #endif
        
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Helper Error Mapping
    
    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        // Handle common AuthErrorCode descriptions
        let description = error.localizedDescription
        if description.contains("email address is badly formatted") || nsError.code == 17008 {
            return "The email address is badly formatted."
        } else if description.contains("no user record") || nsError.code == 17011 {
            return "No account found with this email address."
        } else if description.contains("password is invalid") || description.contains("wrong password") || nsError.code == 17009 {
            return "Incorrect password. Please try again."
        } else if description.contains("already in use") || nsError.code == 17007 {
            return "An account with this email already exists."
        } else if description.contains("network error") || description.contains("network-request-failed") || nsError.code == 17020 {
            return "Network request failed. Check your internet connection."
        }
        return description
    }
}
