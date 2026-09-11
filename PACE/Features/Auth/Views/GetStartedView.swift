//
//  GetStartedView.swift
//  PACE
//
//  Initial landing screen for unauthenticated users.
//  Copy adheres to PACE requirements:
//  - PACE
//  - SHOW UP FOR WHAT MATTERS.
//  - Set the date. Show up consistently. Keep the proof.
//

import SwiftUI

struct GetStartedView: View {
    @ObservedObject var authService = AuthService.shared
    @State private var navigateToRegister = false
    @State private var navigateToLogin = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                // Brand Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(PACEColor.accent)
                            .frame(width: 8, height: 28)
                        
                        Text("PACE")
                            .font(.system(size: 36, weight: .black, design: .default))
                            .foregroundColor(PACEColor.textPrimary)
                            .tracking(2.0)
                    }
                    
                    Text("SHOW UP FOR WHAT MATTERS.")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(PACEColor.accent)
                        .tracking(0.5)
                    
                    Text("Set the date. Show up consistently. Keep the proof.")
                        .font(PACETypography.body())
                        .foregroundColor(PACEColor.textSecondary)
                        .lineSpacing(4)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Test mode notice if Firebase is pending
                if !authService.hasGoogleServicePlist || !authService.isFirebaseLinked {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(PACEColor.accent)
                            Text("LOCAL TEST MODE ACTIVE")
                                .font(PACETypography.caption())
                                .foregroundColor(PACEColor.accent)
                        }
                        Text("Tap 'LOGIN TO EXISTING ACCOUNT' to enter directly without credentials.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(PACEColor.textSecondary)
                    }
                    .padding(12)
                    .paceCard(borderColor: PACEColor.border)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    PACEButton(
                        title: "CREATE ACCOUNT",
                        icon: "arrow.right",
                        variant: .primary
                    ) {
                        navigateToRegister = true
                    }
                    
                    PACEButton(
                        title: "LOGIN TO EXISTING ACCOUNT",
                        variant: .secondary
                    ) {
                        if !authService.isFirebaseConfigured {
                            authService.signInQuick()
                        } else {
                            navigateToLogin = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PACEColor.background.ignoresSafeArea())
            .navigationDestination(isPresented: $navigateToRegister) {
                CreateAccountView()
            }
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
            }
        }
    }
}
