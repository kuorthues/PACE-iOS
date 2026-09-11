//
//  CreateAccountView.swift
//  PACE
//
//  Account registration screen with strict input validation:
//  - Name, Email, Password, Confirm Password
//  - Zero corner radius, sharp rectangular design
//

import SwiftUI

struct CreateAccountView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var localError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("CREATE ACCOUNT")
                        .font(PACETypography.titleLarge())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("Register with your email to start tracking your pace.")
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
                        placeholder: "Enter your full name",
                        text: $name,
                        label: "Full Name"
                    )
                    
                    PACETextField(
                        placeholder: "name@example.com",
                        text: $email,
                        label: "Email Address"
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    
                    PACETextField(
                        placeholder: "At least 6 characters",
                        text: $password,
                        label: "Password",
                        isSecure: true
                    )
                    
                    PACETextField(
                        placeholder: "Re-enter password",
                        text: $confirmPassword,
                        label: "Confirm Password",
                        isSecure: true
                    )
                }
                
                PACEDivider()
                
                // Submit Button
                PACEButton(
                    title: authService.isLoading ? "CREATING ACCOUNT..." : "REGISTER",
                    icon: authService.isLoading ? nil : "checkmark.square",
                    variant: .primary,
                    isEnabled: !authService.isLoading
                ) {
                    performRegistration()
                }
                
                // Switch to Login
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Text("ALREADY HAVE AN ACCOUNT?")
                            .font(PACETypography.caption())
                            .foregroundColor(PACEColor.textSecondary)
                        Text("LOGIN")
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
    }
    
    private func performRegistration() {
        localError = nil
        authService.errorMessage = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            localError = "Full Name is required."
            return
        }
        
        if trimmedEmail.isEmpty {
            localError = "Email address is required."
            return
        }
        
        if !authService.validateEmail(trimmedEmail) {
            localError = "Please enter a valid email address format."
            return
        }
        
        if password.count < 6 {
            localError = "Password must be at least 6 characters long."
            return
        }
        
        if password != confirmPassword {
            localError = "Passwords do not match."
            return
        }
        
        Task {
            do {
                try await authService.createAccount(
                    name: trimmedName,
                    email: trimmedEmail,
                    password: password,
                    confirmPassword: confirmPassword
                )
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}
