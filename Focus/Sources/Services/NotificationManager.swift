//
//  NotificationManager.swift
//  Focus
//
//  Rize-style notification system for Focus app
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var reminderMinutes = 5
    @Published var soundEnabled = true
    
    private var scheduledNotifications: Set<String> = []
    
    init() {
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            self.isAuthorized = granted
        } catch {
            print("Notification authorization error: \(error)")
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - Schedule Notifications (Rize Style)
    
    func scheduleNotifications(for tasks: [TaskItem]) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let taskIds = requests.filter { $0.identifier.hasPrefix("focus-") }.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: taskIds)
        }
        scheduledNotifications.removeAll()
        
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        
        for task in tasks {
            guard !task.isCompleted,
                  !task.isSkipped,
                  let startTime = task.startTime,
                  startTime > now else { continue }
            
            let reminderTime = startTime.addingTimeInterval(-Double(reminderMinutes * 60))
            
            if reminderTime > now {
                scheduleRizeStyleNotification(
                    task: task,
                    date: reminderTime,
                    timeString: timeFormatter.string(from: startTime)
                )
            }
        }
    }
    
    // MARK: - Rize-Style System Notification
    
    func scheduleRizeStyleNotification(task: TaskItem, date: Date, timeString: String) {
        guard isAuthorized, !scheduledNotifications.contains(task.id) else { return }
        
        let content = UNMutableNotificationContent()
        
        // Rize-style clean messaging
        content.title = "Focus"
        content.subtitle = task.title
        content.body = "Starting in \(reminderMinutes) min \u{2022} \(timeString)"
        
        // Sound
        if soundEnabled {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        }
        
        content.categoryIdentifier = task.type.displayName.lowercased().contains("meeting") ? "FOCUS_MEETING" : "FOCUS_TASK"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "focus-reminders"
        content.userInfo = [
            "taskId": task.id,
            "taskType": task.type.displayName,
            "startTime": timeString
        ]
        content.badge = NSNumber(value: TaskManager.shared.upcomingCount)
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: "focus-\(task.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            } else {
                self.scheduledNotifications.insert(task.id)
            }
        }
    }
    
    // Legacy compatibility
    func scheduleNotification(id: String, title: String, body: String, date: Date, type: TaskType) {
        guard isAuthorized, !scheduledNotifications.contains(id) else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.subtitle = title
        content.body = body
        
        if soundEnabled {
            content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        }
        
        content.categoryIdentifier = "FOCUS_TASK"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "focus-reminders"
        content.userInfo = ["taskId": id, "taskType": type.displayName]
        content.badge = NSNumber(value: TaskManager.shared.upcomingCount)
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                self.scheduledNotifications.insert(id)
            }
        }
    }
    
    func scheduleTaskNotification(task: TaskItem, date: Date, timeString: String) {
        scheduleRizeStyleNotification(task: task, date: date, timeString: timeString)
    }
    
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id, "focus-\(id)"])
        scheduledNotifications.remove(id)
    }
    
    // MARK: - Rize-Style Notification Categories
    
    func setupNotificationCategories() {
        // Task Actions - Clean minimal style
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Done",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "checkmark")
        )
        
        let snooze5Action = UNNotificationAction(
            identifier: "SNOOZE_5",
            title: "+5 min",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock")
        )
        
        let snooze15Action = UNNotificationAction(
            identifier: "SNOOZE_15",
            title: "+15 min",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath")
        )
        
        let skipAction = UNNotificationAction(
            identifier: "SKIP",
            title: "Skip",
            options: [.destructive],
            icon: UNNotificationActionIcon(systemImageName: "xmark")
        )
        
        // Task category
        let taskCategory = UNNotificationCategory(
            identifier: "FOCUS_TASK",
            actions: [completeAction, snooze5Action, snooze15Action, skipAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        // Meeting Actions
        let joinAction = UNNotificationAction(
            identifier: "JOIN",
            title: "Join",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "video")
        )
        
        let meetingCategory = UNNotificationCategory(
            identifier: "FOCUS_MEETING",
            actions: [joinAction, snooze5Action, snooze15Action],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([taskCategory, meetingCategory])
    }
    
    // MARK: - Show In-App Notification
    
    func showInAppNotification(for task: TaskItem, minutesUntil: Int) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = task.startTime != nil ? timeFormatter.string(from: task.startTime!) : ""
        
        let notification = NotificationData(
            taskId: task.id,
            title: task.title,
            subtitle: "\(minutesUntil) min until \(timeString)",
            time: "in \(minutesUntil)m",
            type: .taskReminder,
            accentColor: task.type.color
        )
        
        InAppNotificationManager.shared.show(notification)
    }
}

// MARK: - Notification Banner Data Model
struct NotificationData: Identifiable, Equatable {
    let id = UUID()
    let taskId: String
    let title: String
    let subtitle: String
    let time: String
    let type: NotificationType
    let accentColor: Color
    
    enum NotificationType {
        case taskReminder
        case meetingReminder
        case completed
        case system
    }
    
    static func == (lhs: NotificationData, rhs: NotificationData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Functional Notification Banner (Linear/Notion Style)
#if os(macOS)
struct NotificationBannerView: View {
    let notification: NotificationData
    let onComplete: () -> Void
    let onSnooze: (Int) -> Void
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top: Info Row
            HStack(spacing: 12) {
                // Color indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(notification.accentColor)
                    .frame(width: 4, height: 40)
                
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(notification.accentColor)
                    .frame(width: 24, height: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(notification.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Time badge
                Text(notification.time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Close
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // Divider
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1)
            
            // Bottom: Action Buttons (always visible)
            HStack(spacing: 0) {
                // Complete
                if notification.type == .taskReminder {
                    FunctionalButton(label: "Done", icon: "checkmark", color: .green) {
                        onComplete()
                    }
                    
                    Divider().frame(height: 28)
                }
                
                // Snooze options
                FunctionalButton(label: "+5m", icon: "clock", color: .blue) {
                    onSnooze(5)
                }
                
                Divider().frame(height: 28)
                
                FunctionalButton(label: "+15m", icon: "clock.arrow.circlepath", color: .orange) {
                    onSnooze(15)
                }
                
                Divider().frame(height: 28)
                
                // Skip
                FunctionalButton(label: "Skip", icon: "forward", color: .red) {
                    onDismiss()
                }
            }
            .frame(height: 36)
        }
        .frame(width: 340)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
        .onHover { isHovered = $0 }
    }
    
    private var iconName: String {
        switch notification.type {
        case .taskReminder: return "bell"
        case .meetingReminder: return "video"
        case .completed: return "checkmark.circle"
        case .system: return "info.circle"
        }
    }
}

// MARK: - Functional Button
struct FunctionalButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isHovered ? color : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isHovered ? color.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Notification Toast Stack
struct NotificationToastStack: View {
    @ObservedObject var manager: InAppNotificationManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.activeNotifications) { notification in
                NotificationBannerView(
                    notification: notification,
                    onComplete: { manager.handleComplete(notification) },
                    onSnooze: { minutes in manager.handleSnooze(notification, minutes: minutes) },
                    onDismiss: { manager.dismiss(notification) }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .animation(.easeInOut(duration: 0.2), value: manager.activeNotifications.count)
    }
}
#endif

// MARK: - In-App Notification Manager
@MainActor
class InAppNotificationManager: ObservableObject {
    static let shared = InAppNotificationManager()
    
    @Published var activeNotifications: [NotificationData] = []
    
    private var dismissTimers: [UUID: Timer] = [:]
    
    func show(_ notification: NotificationData, autoDismissAfter seconds: Double = 60) {
        // Limit to 3 notifications
        if activeNotifications.count >= 3 {
            activeNotifications.removeFirst()
        }
        activeNotifications.append(notification)
        
        // Auto dismiss timer - defaults to 60 seconds (1 minute)
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(notification)
            }
        }
        dismissTimers[notification.id] = timer
    }
    
    func dismiss(_ notification: NotificationData) {
        dismissTimers[notification.id]?.invalidate()
        dismissTimers.removeValue(forKey: notification.id)
        activeNotifications.removeAll { $0.id == notification.id }
    }
    
    func handleComplete(_ notification: NotificationData) {
        Task {
            if let task = TaskManager.shared.todayTasks.first(where: { $0.id == notification.taskId }) {
                await TaskManager.shared.toggleComplete(task: task)
            }
            dismiss(notification)
        }
    }
    
    func handleSnooze(_ notification: NotificationData, minutes: Int) {
        dismiss(notification)
        
        // Schedule system notification for snooze
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.subtitle = notification.title
        content.body = "Snoozed reminder"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        content.categoryIdentifier = "FOCUS_TASK"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "snooze-\(notification.taskId)-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func showTaskReminder(task: TaskItem, minutesUntil: Int) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = task.startTime != nil ? timeFormatter.string(from: task.startTime!) : ""
        
        let notification = NotificationData(
            taskId: task.id,
            title: task.title,
            subtitle: "Starts at \(timeString)",
            time: "\(minutesUntil)m",
            type: .taskReminder,
            accentColor: task.type.color
        )
        
        show(notification)
    }
}
