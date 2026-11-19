import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var service: NotificationCenterService
    @State private var selectedDestination: PACENotificationDestination?
    @State private var visibleCount = 40

    private var visibleNotifications: [PACENotification] {
        Array(service.notifications.prefix(visibleCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("NOTIFICATIONS")
                    .font(PACETextStyle.displayLarge)
                    .foregroundColor(PACETheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                if service.unreadCount > 0 {
                    Button("MARK ALL READ") {
                        service.markAllRead()
                    }
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.accent)
                    .buttonStyle(.plain)
                    .accessibilityHint("Marks all currently loaded notifications as read")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            if let errorMessage = service.errorMessage {
                Text(errorMessage.uppercased())
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            if service.isLoading && service.notifications.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(PACETheme.accent)
                    Text("SYNCING NOTIFICATIONS")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if service.notifications.isEmpty {
                            Text("NO NOTIFICATIONS YET")
                                .font(PACETextStyle.pixelMetadata)
                                .foregroundColor(PACETheme.mutedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(visibleNotifications) { notification in
                                notificationRow(notification)
                            }

                            if visibleCount < service.notifications.count {
                                Button("LOAD OLDER") {
                                    visibleCount = min(visibleCount + 40, service.notifications.count)
                                }
                                .font(PACETextStyle.pixelMetadata)
                                .foregroundColor(PACETheme.accent)
                                .padding(.vertical, 16)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PACETheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(PACETheme.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(PACETheme.primaryText)
                }
                .accessibilityLabel("Back to goals")
            }
        }
        .navigationDestination(item: $selectedDestination) { destination in
            destinationView(destination)
        }
    }

    private func notificationRow(_ notification: PACENotification) -> some View {
        Button {
            service.markAsRead(notification)
            selectedDestination = notification.destination
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.kind.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(notification.isRead ? PACETheme.secondaryText : PACETheme.accent)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(notification.title)
                            .font(PACETextStyle.pixelLabel)
                            .foregroundColor(PACETheme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(notification.createdAt, style: .relative)
                            .font(PACETextStyle.pixelMetadata)
                            .foregroundColor(PACETheme.mutedText)
                            .lineLimit(1)
                    }

                    Text(notification.message)
                        .font(PACETextStyle.body)
                        .foregroundColor(PACETheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !notification.isRead {
                    Circle()
                        .fill(PACETheme.accent)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notification.isRead ? Color.clear : PACETheme.surface.opacity(0.72))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PACETheme.border)
                    .frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Marks as read and opens the related PACE screen")
    }

    @ViewBuilder
    private func destinationView(_ destination: PACENotificationDestination) -> some View {
        switch destination {
        case .invitations:
            InvitationManagementView()
        case .sharedGoal(let goalId):
            SharedGoalNotificationDestinationView(goalId: goalId, mode: .detail)
        case .sharedJourney(let goalId, let logId):
            SharedGoalNotificationDestinationView(goalId: goalId, mode: .journey(logId: logId))
        case .sharedGoalLog(let goalId):
            SharedGoalNotificationDestinationView(goalId: goalId, mode: .log)
        }
    }
}

private struct SharedGoalNotificationDestinationView: View {
    enum Mode {
        case detail
        case journey(logId: String)
        case log
    }

    let goalId: String
    let mode: Mode
    @State private var goal: SharedGoal?
    @State private var didLoad = false

    var body: some View {
        Group {
            if let goal {
                switch mode {
                case .detail:
                    SharedGoalDetailView(goal: goal)
                case .journey(let logId):
                    SharedJourneyView(goal: goal, focusLogId: logId)
                case .log:
                    SharedGoalDetailView(goal: goal, openLoggingOnAppear: true)
                }
            } else if !didLoad {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(PACETheme.accent)
                    Text("OPENING SHARED GOAL")
                        .font(PACETextStyle.pixelMetadata)
                        .foregroundColor(PACETheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PACETheme.background.ignoresSafeArea())
            } else {
                Text("THIS SHARED GOAL IS NO LONGER AVAILABLE.")
                    .font(PACETextStyle.pixelMetadata)
                    .foregroundColor(PACETheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
                    .background(PACETheme.background.ignoresSafeArea())
            }
        }
        .task(id: goalId) {
            goal = await SharedGoalService.shared.fetchGoal(id: goalId)
            didLoad = true
        }
    }
}
