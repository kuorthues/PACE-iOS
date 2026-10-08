//
//  ForgotPasswordView.swift
//  PACE
//
//  Password reset request screen matching Figma design language:
//  - P A C E neon tracked branding
//  - Condensed heavy display title
//  - Sharp bordered email input
//  - Primary CTA with arrow: SEND RESET LINK →
//  - Secondary action: ← BACK TO LOGIN
//

import SwiftUI

struct ForgotPasswordView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var email = ""
    @State private var localError: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header Block
                VStack(alignment: .leading, spacing: 10) {
                    Text("P A C E")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.accent)
                        .tracking(3.0)
                        .padding(.top, 8)
                    
                    Text("FORGOT\nPASSWORD")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .lineSpacing(-4)
                    
                    Text("Enter your email address to receive a secure password reset link.")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(PACETheme.secondaryText)
                        .padding(.top, 4)
                }
                
                // Status / Success Banner
                if let statusText = authService.statusMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(PACETheme.accent)
                            .frame(width: 3)
                        Text(statusText)
                            .font(PACETypography.body())
                            .foregroundColor(PACETheme.accent)
                    }
                    .padding(12)
                    .background(PACETheme.surface)
                    .overlay(
                        Rectangle().stroke(PACETheme.accent, lineWidth: 1)
                    )
                }
                
                // Error Banner
                if let errorText = localError ?? authService.errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(PACETheme.accent)
                            .frame(width: 3)
                        Text(errorText)
                            .font(PACETypography.body())
                            .foregroundColor(PACETheme.primaryText)
                    }
                    .padding(12)
                    .background(PACETheme.surface)
                    .overlay(
                        Rectangle().stroke(PACETheme.border, lineWidth: 1)
                    )
                }
                
                // Email Field
                VStack(spacing: 20) {
                    PACETextField(
                        placeholder: "STUDENT@PACE.EDU",
                        text: $email,
                        label: "ACCOUNT EMAIL"
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    PACEButton(
                        title: authService.isLoading ? "SENDING LINK..." : "SEND RESET LINK →",
                        variant: .primary,
                        isEnabled: !authService.isLoading
                    ) {
                        performPasswordReset()
                    }
                    
                    PACEButton(
                        title: "← BACK TO LOGIN",
                        variant: .secondary
                    ) {
                        dismiss()
                    }
                }
                .padding(.top, 12)
                
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 24)
        }
        .background(PACETheme.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Text("← BACK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(PACETheme.secondaryText)
                        .tracking(1.0)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func performPasswordReset() {
        localError = nil
        authService.errorMessage = nil
        authService.statusMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedEmail.isEmpty {
            localError = "Please enter your account email address."
            return
        }
        
        if !authService.validateEmail(trimmedEmail) {
            localError = "Please enter a valid email format."
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
