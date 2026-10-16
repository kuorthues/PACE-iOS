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
    
    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    #endif
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkConfiguration()
        UserDefaults.standard.removeObject(forKey: "pace_active_user")
        setupAuthStateListener()
    }
    
    func checkConfiguration() {
        // 1. Check if GoogleService-Info.plist exists in main bundle
        let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        hasGoogleServicePlist = (plistPath != nil)
        
        // 2. Check if Firebase SDK is compiled in
        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        isFirebaseLinked = true
        if hasGoogleServicePlist && FirebaseApp.app() != nil {
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
        checkConfiguration()
        if isFirebaseConfigured {
            if let user = Auth.auth().currentUser {
                self.currentUser = PACEUser(
                    id: user.uid,
                    email: user.email ?? "",
                    displayName: user.displayName
                )
                self.isAuthenticated = true
            }
            
            authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
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
        
        guard isFirebaseConfigured else {
            let error = AuthError.firebaseNotConfigured("Firebase Authentication is not configured.")
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
        
        guard isFirebaseConfigured else {
            let error = AuthError.firebaseNotConfigured("Firebase Authentication is not configured.")
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
        
        guard isFirebaseConfigured else {
            let error = AuthError.firebaseNotConfigured("Firebase Authentication is not configured.")
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
        
        UserDefaults.standard.removeObject(forKey: "pace_active_user")
        self.currentUser = nil
        self.isAuthenticated = false
    }
    
    // MARK: - Helper Error Mapping
    
    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        
        #if canImport(FirebaseAuth)
        if let authErrorCode = AuthErrorCode(rawValue: nsError.code) {
            switch authErrorCode {
            case .invalidEmail:
                return "Please enter a valid email address."
            case .wrongPassword, .invalidCredential:
                return "Incorrect email or password. Please try again."
            case .userNotFound:
                return "No account found with this email address."
            case .userDisabled:
                return "This account has been disabled."
            case .emailAlreadyInUse:
                return "An account with this email already exists."
            case .weakPassword:
                return "Password is too weak. Please use at least 6 characters."
            case .networkError:
                return "Network request failed. Check your internet connection."
            case .tooManyRequests:
                return "Too many attempts. Please try again later."
            case .operationNotAllowed:
                return "Email/Password sign-in is not enabled in Firebase Console."
            default:
                break
            }
        }
        #endif
        
        let description = error.localizedDescription
        let lower = description.lowercased()
        if lower.contains("email address is badly formatted") || nsError.code == 17008 {
            return "Please enter a valid email address."
        } else if lower.contains("no user record") || nsError.code == 17011 {
            return "No account found with this email address."
        } else if lower.contains("password is invalid") || lower.contains("wrong password") || lower.contains("invalid-credential") || nsError.code == 17009 || nsError.code == 17999 {
            return "Incorrect email or password. Please try again."
        } else if lower.contains("already in use") || nsError.code == 17007 {
            return "An account with this email already exists."
        } else if lower.contains("weak password") || nsError.code == 17026 {
            return "Password is too weak. Please use at least 6 characters."
        } else if lower.contains("network") || nsError.code == 17020 {
            return "Network request failed. Check your internet connection."
        }
        return description
    }
}
