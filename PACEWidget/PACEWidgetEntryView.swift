//
//  PACEWidgetEntryView.swift
//  PACEWidget
//
//  Widget view rendering systemSmall and systemMedium goal widgets.
//  Strictly adheres to PACE visual identity:
//  - #A7FF19 accent
//  - Black/dark surfaces with sharp 1px borders
//  - System monospaced metrics
//  - Deep-linking to Goal Detail and Log Progress
//

import WidgetKit
import SwiftUI

struct PACEWidgetEntryView: View {
    let entry: PACEWidgetEntry
    @Environment(\.widgetFamily) var family
    
    // PACE Design Tokens (WidgetKit-isolated)
    private let accentColor = Color(red: 167 / 255.0, green: 255 / 255.0, blue: 25 / 255.0)
    private let surfaceColor = Color(red: 18 / 255.0, green: 18 / 255.0, blue: 18 / 255.0)
    private let surfaceElevated = Color(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0)
    private let borderColor = Color(red: 44 / 255.0, green: 44 / 255.0, blue: 46 / 255.0)
    private let textSecondary = Color(red: 142 / 255.0, green: 142 / 255.0, blue: 147 / 255.0)
    
    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemSmall:
                    smallView(snapshot: snapshot)
                        .widgetURL(URL(string: "pace://goal?id=\(snapshot.goalId)"))
                case .systemMedium:
                    mediumView(snapshot: snapshot)
                        .widgetURL(URL(string: "pace://goal?id=\(snapshot.goalId)"))
                default:
                    smallView(snapshot: snapshot)
                        .widgetURL(URL(string: "pace://goal?id=\(snapshot.goalId)"))
                }
            } else {
                noGoalView
                    .widgetURL(URL(string: "pace://goals"))
            }
        }
    }
    
    // MARK: - System Small View
    
    private func smallView(snapshot: PACEWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: PACE branding + Today Indicator
            HStack {
                Text("PACE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(accentColor)
                    .tracking(1.0)
                
                Spacer()
                
                // Status dot
                Rectangle()
                    .fill(snapshot.hasLoggedToday ? accentColor : (snapshot.isScheduledToday ? Color.yellow : borderColor))
                    .frame(width: 8, height: 8)
            }
            
            // Goal Title
            Text(snapshot.goalTitle.uppercased())
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 2)
            
            // Metrics Row: Days Remaining + Streak
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(format: "%02d", snapshot.daysRemaining))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("DAYS")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%02d", snapshot.currentStreak))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(snapshot.currentStreak > 0 ? accentColor : .white)
                    Text("STREAK")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
            }
            
            // Bottom Today Status Badge
            HStack(spacing: 4) {
                if snapshot.hasLoggedToday {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("LOGGED TODAY")
                } else if snapshot.isScheduledToday {
                    Image(systemName: "clock")
                        .font(.system(size: 8, weight: .bold))
                    Text("PROOF PENDING")
                } else {
                    Text("REST DAY")
                }
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(snapshot.hasLoggedToday ? .black : (snapshot.isScheduledToday ? accentColor : textSecondary))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .background(snapshot.hasLoggedToday ? accentColor : surfaceElevated)
            .overlay(
                Rectangle().stroke(snapshot.hasLoggedToday ? accentColor : borderColor, lineWidth: 1)
            )
        }
        .padding(12)
    }
    
    // MARK: - System Medium View
    
    private func mediumView(snapshot: PACEWidgetSnapshot) -> some View {
        HStack(spacing: 12) {
            // Left Column: Goal info & Today Status
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("PACE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(accentColor)
                        .tracking(1.0)
                    
                    Spacer()
                    
                    Text("TARGET: \(snapshot.targetDateString.uppercased())")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
                
                Text(snapshot.goalTitle.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Spacer()
                
                // Status Box with Deep Link to Log
                Link(destination: URL(string: "pace://log?goalId=\(snapshot.goalId)")!) {
                    HStack(spacing: 6) {
                        Image(systemName: snapshot.hasLoggedToday ? "checkmark.circle.fill" : "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                        
                        Text(snapshot.hasLoggedToday ? "PROOF VERIFIED TODAY" : (snapshot.isScheduledToday ? "LOCK IN TODAY'S PROOF" : "REST DAY"))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(snapshot.hasLoggedToday ? .black : (snapshot.isScheduledToday ? .black : textSecondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(snapshot.hasLoggedToday ? accentColor : (snapshot.isScheduledToday ? accentColor : surfaceElevated))
                    .overlay(
                        Rectangle().stroke(snapshot.isScheduledToday || snapshot.hasLoggedToday ? accentColor : borderColor, lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Vertical Divider
            Rectangle()
                .fill(borderColor)
                .frame(width: 1)
            
            // Right Column: Key Metrics (Days Remaining, Streak, Time)
            VStack(alignment: .leading, spacing: 10) {
                // Days Remaining
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%02d", snapshot.daysRemaining))
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("DAYS REMAINING")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
                
                // Streak
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%02d", snapshot.currentStreak))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(snapshot.currentStreak > 0 ? accentColor : .white)
                    Text("DAY STREAK")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
            }
            .frame(width: 100, alignment: .leading)
        }
        .padding(14)
    }
    
    // MARK: - No Goal View
    
    private var noGoalView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PACE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(accentColor)
                    .tracking(1.0)
                Spacer()
            }
            
            Spacer()
            
            Image(systemName: "target")
                .font(.system(size: family == .systemSmall ? 22 : 28))
                .foregroundColor(accentColor)
            
            Text("NO ACTIVE GOAL")
                .font(.system(size: family == .systemSmall ? 11 : 13, weight: .bold, design: .default))
                .foregroundColor(.white)
            
            Text("Tap to launch PACE and set your target objective.")
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(12)
    }
}
