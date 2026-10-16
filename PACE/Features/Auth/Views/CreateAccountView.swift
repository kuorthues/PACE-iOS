//
//  CreateAccountView.swift
//  PACE
//
//  Screen 2: Registration screen matching Figma prototype:
//  - P A C E tracked header
//  - Massive CREATE / ACCOUNT display typography
//  - Sharp bordered fields: NAME, EMAIL, PASSWORD, CONFIRM PASSWORD
//  - Primary CTA: CREATE ACCOUNT →
//  - Secondary: ALREADY HAVE AN ACCOUNT? LOG IN →
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
            VStack(alignment: .leading, spacing: 28) {
                // Header Block
                VStack(alignment: .leading, spacing: 10) {
                    Text("P A C E")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.accent)
                        .tracking(3.0)
                        .padding(.top, 8)
                    
                    Text("CREATE\nACCOUNT")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
                        .lineSpacing(-4)
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
                
                // Form Fields
                VStack(spacing: 20) {
                    PACETextField(
                        placeholder: "YOUR NAME",
                        text: $name,
                        label: "NAME"
                    )
                    
                    PACETextField(
                        placeholder: "NAME@EXAMPLE.COM",
                        text: $email,
                        label: "EMAIL"
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    
                    PACETextField(
                        placeholder: "AT LEAST 6 CHARACTERS",
                        text: $password,
                        label: "PASSWORD",
                        isSecure: true
                    )
                    
                    PACETextField(
                        placeholder: "CONFIRM PASSWORD",
                        text: $confirmPassword,
                        label: "CONFIRM PASSWORD",
                        isSecure: true
                    )
                }
                
                // Actions
                VStack(spacing: 12) {
                    PACEButton(
                        title: authService.isLoading ? "CREATING ACCOUNT..." : "CREATE ACCOUNT →",
                        variant: .primary,
                        isEnabled: !authService.isLoading
                    ) {
                        performRegistration()
                    }
                    
                    PACEButton(
                        title: "ALREADY HAVE AN ACCOUNT? LOG IN →",
                        variant: .secondary,
                        isEnabled: !authService.isLoading
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
                    HStack(spacing: 4) {
                        Text("← BACK")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(PACETheme.secondaryText)
                            .tracking(1.0)
                    }
                }
                .buttonStyle(.plain)
            }
        }
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
