//
//  LoginView.swift
//  PACE
//
//  Login screen with email/password authentication and zero-radius controls:
//  - Email, Password inputs
//  - Validation and error presentation
//  - Navigation to Forgot Password
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var localError: String? = nil
    @State private var navigateToForgotPassword = false
    @State private var navigateToRegister = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("LOGIN")
                        .font(PACETypography.titleLarge())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("Sign in to access your targets and daily logs.")
                        .font(PACETypography.body())
                        .foregroundColor(PACEColor.textSecondary)
                }
                .padding(.top, 10)
                
                PACEDivider()
                
                // Error Banner
                if let errorText = localError ?? authService.errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.square.fill")
                            .foregroundColor(PACEColor.accent)
                        Text(errorText)
                            .font(PACETypography.body())
                            .foregroundColor(PACEColor.textPrimary)
                    }
                    .padding(12)
                    .paceCard(borderColor: PACEColor.accent)
                }
                
                // Form Fields
                VStack(spacing: 16) {
                    PACETextField(
                        placeholder: "name@example.com (optional)",
                        text: $email,
                        label: "Email Address"
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    
                    PACETextField(
                        placeholder: "Enter password (optional)",
                        text: $password,
                        label: "Password",
                        isSecure: true
                    )
                    
                    // Direct access hint when in local mode
                    if !authService.isFirebaseConfigured {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(PACEColor.accent)
                            Text("FAST ACCESS: Tap LOGIN to enter without credentials.")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.accent)
                        }
                    }
                    
                    // Forgot Password link
                    HStack {
                        Spacer()
                        Button(action: {
                            navigateToForgotPassword = true
                        }) {
                            Text("FORGOT PASSWORD?")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                PACEDivider()
                
                // Submit Button
                PACEButton(
                    title: authService.isLoading ? "LOGGING IN..." : "LOGIN",
                    icon: authService.isLoading ? nil : "arrow.right.square",
                    variant: .primary,
                    isEnabled: !authService.isLoading
                ) {
                    performLogin()
                }
                
                // Switch to Register
                Button(action: {
                    navigateToRegister = true
                }) {
                    HStack {
                        Text("NEED AN ACCOUNT?")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        Text("CREATE ONE")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 24)
        }
        .background(PACEColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(PACEColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToForgotPassword) {
            ForgotPasswordView()
        }
        .navigationDestination(isPresented: $navigateToRegister) {
            CreateAccountView()
        }
    }
    
    private func performLogin() {
        localError = nil
        authService.errorMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If email or password is empty, or if Firebase is not configured,
        // sign in directly without requiring credentials!
        if trimmedEmail.isEmpty || password.isEmpty || !authService.isFirebaseConfigured {
            authService.signInQuick(
                email: trimmedEmail.isEmpty ? "student@pace.edu" : trimmedEmail,
                displayName: "PACE Student"
            )
            return
        }
        
        if !authService.validateEmail(trimmedEmail) {
            localError = "Please enter a valid email address."
            return
        }
        
        Task {
            do {
                try await authService.signIn(email: trimmedEmail, password: password)
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}
