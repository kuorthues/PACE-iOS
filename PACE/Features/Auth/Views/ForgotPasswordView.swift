//
//  ForgotPasswordView.swift
//  PACE
//
//  Password reset request screen:
//  - Email validation
//  - Feedback/status state
//  - Zero corner radius design
//

import SwiftUI

struct ForgotPasswordView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var localError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("FORGOT PASSWORD")
                        .font(PACETypography.titleLarge())
                        .foregroundColor(PACEColor.textPrimary)
                    
                    Text("Enter your email address and we will send you a link to reset your password.")
                        .font(PACETypography.body())
                        .foregroundColor(PACEColor.textSecondary)
                }
                .padding(.top, 10)
                
                PACEDivider()
                
                // Status / Success Banner
                if let statusText = authService.statusMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundColor(PACEColor.accent)
                        Text(statusText)
                            .font(PACETypography.body())
                            .foregroundColor(PACEColor.accent)
                    }
                    .padding(12)
                    .paceCard(borderColor: PACEColor.accent)
                }
                
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
                
                // Email Field
                PACETextField(
                    placeholder: "name@example.com",
                    text: $email,
                    label: "Account Email"
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled(true)
                
                PACEDivider()
                
                // Send Reset Button
                PACEButton(
                    title: authService.isLoading ? "SENDING LINK..." : "SEND RESET LINK",
                    icon: authService.isLoading ? nil : "envelope.badge",
                    variant: .primary,
                    isEnabled: !authService.isLoading
                ) {
                    performPasswordReset()
                }
                
                // Return to Login
                Button(action: {
                    dismiss()
                }) {
                    Text("BACK TO LOGIN")
                        .font(PACETypography.caption())
                        .foregroundColor(PACEColor.textSecondary)
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
    
    private func performPasswordReset() {
        localError = nil
        authService.errorMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedEmail.isEmpty {
            localError = "Email address is required."
            return
        }
        
        if !authService.validateEmail(trimmedEmail) {
            localError = "Please enter a valid email address."
            return
        }
        
        Task {
            do {
                try await authService.sendPasswordReset(email: trimmedEmail)
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}
