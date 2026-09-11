//
//  RootView.swift
//  PACE
//
//  Root container view that dynamically switches between the unauthenticated flow
//  (GetStartedView) and the authenticated application shell (MainTabView)
//  based on AuthService state.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                GetStartedView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.isAuthenticated)
    }
}
