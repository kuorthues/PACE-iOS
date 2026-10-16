//
//  LoginView.swift
//  PACE
//
//  Login screen matching Figma prototype styling:
//  - P A C E tracked header
//  - Condensed bold display typography: LOG IN
//  - Sharp bordered fields: EMAIL, PASSWORD
//  - Primary CTA: LOG IN →
//  - Secondary: DON'T HAVE AN ACCOUNT? REGISTER →
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
            VStack(alignment: .leading, spacing: 28) {
                // Header Block
                VStack(alignment: .leading, spacing: 10) {
                    Text("P A C E")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(PACETheme.accent)
                        .tracking(3.0)
                        .padding(.top, 8)
                    
                    Text("LOG IN")
                        .font(PACETextStyle.displayLarge)
                        .foregroundColor(PACETheme.primaryText)
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
                        placeholder: "NAME@EXAMPLE.COM",
                        text: $email,
                        label: "EMAIL"
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    
                    PACETextField(
                        placeholder: "YOUR PASSWORD",
                        text: $password,
                        label: "PASSWORD",
                        isSecure: true
                    )
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            navigateToForgotPassword = true
                        }) {
                            Text("FORGOT PASSWORD?")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(PACETheme.secondaryText)
                                .tracking(1.0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Actions
                VStack(spacing: 12) {
                    PACEButton(
                        title: authService.isLoading ? "LOGGING IN..." : "LOG IN →",
                        variant: .primary,
                        isEnabled: !authService.isLoading
                    ) {
                        performLogin()
                    }
                    
                    PACEButton(
                        title: "CREATE NEW ACCOUNT →",
                        variant: .secondary,
                        isEnabled: !authService.isLoading
                    ) {
                        navigateToRegister = true
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
        
        if trimmedEmail.isEmpty {
            localError = "Please enter your email."
            return
        }
        
        if !authService.validateEmail(trimmedEmail) {
            localError = "Please enter a valid email format."
            return
        }
        
        if password.isEmpty {
            localError = "Please enter your password."
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
