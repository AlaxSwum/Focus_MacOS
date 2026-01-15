//
//  FocusApp.swift
//  Focus - Native macOS Menu Bar App
//
//  Menu bar dropdown with full app window support
//

import SwiftUI
import UserNotifications
#if os(macOS)
import AppKit
#endif

@main
struct FocusApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var inAppNotificationManager = InAppNotificationManager.shared
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        #if os(macOS)
        // Menu Bar Only - No floating window
        MenuBarExtra {
            MenuBarDropdownView()
                .environmentObject(authManager)
                .environmentObject(taskManager)
        } label: {
            // Load icon - try multiple paths
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)
        
        // Full App Window (opened separately)
        Window("Project Next", id: "full-app") {
            ZStack {
                FullAppWindowView()
                    .environmentObject(authManager)
                    .environmentObject(taskManager)
                
                // Rize-style in-app notification overlay
                NotificationToastStack(manager: inAppNotificationManager)
                    .allowsHitTesting(true)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        
        // Add Todo Window (separate from menu bar to prevent focus issues)
        Window("Add Todo", id: "add-todo") {
            MenuBarAddTodoSheet()
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Settings {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .environmentObject(taskManager)
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(taskManager)
                .environmentObject(notificationManager)
                .environmentObject(themeManager)
        }
        #endif
    }
}

// MARK: - Menu Bar Icon View
#if os(macOS)
struct MenuBarIconView: View {
    private static let logoPath = "/Users/swumpyaesone/Documents/project_management/frontend/assets/logo/projectnextlogo.png"
    
    private static func createIcon() -> NSImage? {
        guard let original = NSImage(contentsOfFile: logoPath) else { return nil }
        let newSize = NSSize(width: 18, height: 18)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        original.draw(in: NSRect(origin: .zero, size: newSize),
                     from: NSRect(origin: .zero, size: original.size),
                     operation: .copy,
                     fraction: 1.0)
        newImage.unlockFocus()
        newImage.isTemplate = false
        return newImage
    }
    
    private static let cachedIcon = createIcon()
    
    var body: some View {
        if let icon = Self.cachedIcon {
            Image(nsImage: icon)
        } else {
            Image(systemName: "checkmark.circle.fill")
        }
    }
}

// Project Next Logo - loads from your actual PNG file
struct ProjectNextLogo: View {
    var size: CGFloat = 24
    
    // Path to your actual logo file
    private static let logoPath = "/Users/swumpyaesone/Documents/project_management/frontend/assets/logo/projectnextlogo.png"
    
    var body: some View {
        Group {
            if let nsImage = NSImage(contentsOfFile: Self.logoPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                // Fallback if file not found
                fallbackLogo
            }
        }
    }
    
    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.231, green: 0.255, blue: 0.275))
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(x: size * 0.15, y: size * 0.15)
            
            Circle()
                .fill(Color(red: 0.231, green: 0.255, blue: 0.275))
                .frame(width: size * 0.55, height: size * 0.55)
                .offset(x: -size * 0.05, y: -size * 0.05)
            
            Circle()
                .fill(Color(red: 0.976, green: 0.698, blue: 0.2))
                .frame(width: size * 0.45, height: size * 0.45)
                .offset(x: -size * 0.15, y: -size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Menu Bar Dropdown View
struct MenuBarDropdownView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab = 0
    @State private var todaySubTab = 0  // 0 = Upcoming, 1 = Completed
    @State private var selectedMeeting: TaskItem?
    @State private var tabDirection: Int = 0
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                headerView
                tabBar
                contentView
                footerView
            }
            .opacity(selectedMeeting == nil ? 1 : 0)
            
            // Meeting Details overlay
            if let meeting = selectedMeeting {
                MeetingDetailsInline(meeting: meeting, onClose: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedMeeting = nil
                    }
                })
                    .environmentObject(taskManager)
                    .transition(.opacity)
            }
        }
        .frame(width: 380, height: 500)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await taskManager.fetchTasks(for: userId)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // Project Next Logo with pulse animation
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                ProjectNextLogo(size: 22)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Project Next")
                    .font(.system(size: 14, weight: .bold))
                Text(Date(), style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Progress indicator with animation
            let progress = getProgress()
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                        .frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress.completed) / CGFloat(max(progress.total, 1)))
                        .stroke(
                            progress.completed == progress.total ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: progress.completed)
                    
                    Text("\(progress.completed)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(progress.completed == progress.total ? .green : .accentColor)
                }
                
                Text("/\(progress.total)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("Today", icon: "sun.max.fill", index: 0)
            tabButton("Todo", icon: "checklist", index: 1)
            tabButton("Meetings", icon: "video.fill", index: 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            let oldTab = selectedTab
            withAnimation(.easeInOut(duration: 0.2)) {
                tabDirection = index > oldTab ? 1 : -1
                selectedTab = index
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: selectedTab == index ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 12, weight: selectedTab == index ? .semibold : .medium))
            }
            .foregroundColor(selectedTab == index ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                switch selectedTab {
                case 0:
                    todayContent
                case 1:
                    todoContent
                case 2:
                    meetingsContent
                default:
                    todayContent
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
    
    // Filter to today only - sorted by time
    private var todayTasks: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return taskManager.todayTasks.filter { task in
            Calendar.current.isDate(task.date, inSameDayAs: today)
        }.sorted { task1, task2 in
            // Sort by start hour then minute
            let time1 = task1.startHour * 60 + task1.startMinute
            let time2 = task2.startHour * 60 + task2.startMinute
            return time1 < time2
        }
    }
    
    // Today's meetings only - sorted by time
    private var todayMeetings: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return taskManager.todayTasks.filter { task in
            task.type == .meeting && Calendar.current.isDate(task.date, inSameDayAs: today)
        }.sorted { task1, task2 in
            let time1 = task1.startHour * 60 + task1.startMinute
            let time2 = task2.startHour * 60 + task2.startMinute
            return time1 < time2
        }
    }
    
    private var upcomingTasks: [TaskItem] {
        todayTasks.filter { !$0.isCompleted }
    }
    
    private var completedTasks: [TaskItem] {
        todayTasks.filter { $0.isCompleted }
    }
    
    private var todayContent: some View {
        VStack(spacing: 0) {
            // Upcoming / Completed toggle
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { todaySubTab = 0 }
                } label: {
                    Text("Upcoming (\(upcomingTasks.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(todaySubTab == 0 ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(todaySubTab == 0 ? Color.accentColor : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { todaySubTab = 1 }
                } label: {
                    Text("Completed (\(completedTasks.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(todaySubTab == 1 ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(todaySubTab == 1 ? Color.green : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)
            
            // Task list based on sub-tab
            let tasks = todaySubTab == 0 ? upcomingTasks : completedTasks
            
            if tasks.isEmpty {
                emptyStateView(todaySubTab == 0 ? "All caught up!" : "No completed tasks")
            } else {
                ForEach(tasks) { task in
                    unifiedTaskRow(task)
                }
            }
        }
    }
    
    // Unified row style for both tasks and meetings
    private func unifiedTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                Task { await taskManager.toggleComplete(task: task) }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? Color.green : taskColor(task).opacity(0.5), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(taskColor(task).opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: taskIcon(task))
                    .font(.system(size: 12))
                    .foregroundColor(taskColor(task))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(task.timeText)
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Type badge + chevron for meetings
            HStack(spacing: 6) {
                Text(task.type == .meeting ? "Meeting" : task.type.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(taskColor(task))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(taskColor(task).opacity(0.1))
                    .clipShape(Capsule())
                
                if task.type == .meeting {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: NSColor.controlBackgroundColor))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-click opens meeting details
            if task.type == .meeting {
                selectedMeeting = task
            }
        }
    }
    
    private func taskColor(_ task: TaskItem) -> Color {
        switch task.type {
        case .meeting: return .purple
        case .todo: return .blue
        case .social: return .pink
        case .timeBlock: return .orange
        }
    }
    
    private func taskIcon(_ task: TaskItem) -> String {
        switch task.type {
        case .meeting: return "video.fill"
        case .todo: return "checklist"
        case .social: return "person.2.fill"
        case .timeBlock: return "clock.fill"
        }
    }
    
    private var todoContent: some View {
        VStack(spacing: 0) {
            // Todo list
            let todos = taskManager.todayTasks.filter { $0.type == .todo }.sorted { task1, task2 in
                let time1 = task1.endHour * 60 + task1.endMinute
                let time2 = task2.endHour * 60 + task2.endMinute
                return time1 < time2
            }

            if todos.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 60, height: 60)
                        Image(systemName: "checklist")
                            .font(.system(size: 28))
                            .foregroundColor(.purple.opacity(0.6))
                    }
                    VStack(spacing: 4) {
                        Text("All clear!")
                            .font(.system(size: 14, weight: .semibold))
                        Text("No todo items yet")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale.combined(with: .opacity))
            } else {
                ForEach(todos) { task in
                    taskRow(task)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }

            Spacer()

            // Add Todo Button at bottom with gradient
            Button {
                openAddTodoWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Todo")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.purple.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: taskManager.todayTasks.count)
    }
    
    private func openAddTodoWindow() {
        // Create a new window programmatically for Add Todo
        let contentView = MenuBarAddTodoSheet()
            .environmentObject(TaskManager.shared)
            .environmentObject(AuthManager.shared)

        let hostingController = NSHostingController(rootView: contentView)

        // Create a proper window
        let window = AddTodoWindow(contentViewController: hostingController)
        window.title = "Add Todo"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 520))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private var meetingsContent: some View {
        Group {
            if todayMeetings.isEmpty {
                emptyStateView("No meetings today")
            } else {
                ForEach(todayMeetings) { task in
                    meetingRow(task)
                }
            }
        }
    }
    
    private func emptyStateView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func taskRow(_ task: TaskItem) -> some View {
        TaskRowWithSwipe(taskItem: task, taskManager: taskManager)
    }
    
    // Improved meeting row design
    private func meetingRow(_ task: TaskItem) -> some View {
        Button {
            selectedMeeting = task
        } label: {
            HStack(spacing: 12) {
                // Meeting icon with gradient
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "video.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(task.timeText)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    
                    if let desc = task.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if task.meetingLink != nil {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var footerView: some View {
        Button {
            openFullAppWindow()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "macwindow")
                    .font(.system(size: 12))
                Text("Open Full App")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    private func openFullAppWindow() {
        // Create the full app window programmatically
        let contentView = FullAppWindowView()
            .environmentObject(TaskManager.shared)
            .environmentObject(AuthManager.shared)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Project Next"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 1400, height: 900))
        window.minSize = NSSize(width: 1200, height: 800)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func getProgress() -> (completed: Int, total: Int) {
        let tasks = todayTasks
        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count
        return (completed, total)
    }
}

// MARK: - Swipeable Task Row with Delete Animation
struct TaskRowWithSwipe: View {
    let taskItem: TaskItem
    @ObservedObject var taskManager: TaskManager
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var showDeleteButton = false
    
    private let deleteThreshold: CGFloat = -80
    private let deleteButtonWidth: CGFloat = 70
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            HStack {
                Spacer()
                Button {
                    performDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                        Text("Delete")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteButtonWidth, height: 50)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .opacity(showDeleteButton ? 1 : 0)
                .scaleEffect(showDeleteButton ? 1 : 0.8)
                .animation(.spring(response: 0.3), value: showDeleteButton)
            }
            
            // Main content
            HStack(spacing: 10) {
                Button {
                    Task {
                        await taskManager.toggleComplete(task: taskItem)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(taskItem.isCompleted ? Color.green : Color.gray.opacity(0.4), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        
                        if taskItem.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 22, height: 22)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: taskItem.isCompleted)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskItem.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(taskItem.isCompleted)
                        .foregroundColor(taskItem.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: taskItem.isCompleted)
                    
                    HStack(spacing: 4) {
                        Text(taskItem.type.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(taskItem.type.color.opacity(0.2))
                            .foregroundColor(taskItem.type.color)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        if !taskItem.timeText.isEmpty {
                            Text(taskItem.timeText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            withAnimation(.interactiveSpring()) {
                                offset = value.translation.width
                            }
                            showDeleteButton = offset < deleteThreshold
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if offset < deleteThreshold {
                                offset = -deleteButtonWidth - 10
                                showDeleteButton = true
                            } else {
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
        }
        .opacity(isDeleting ? 0 : 1)
        .scaleEffect(isDeleting ? 0.8 : 1)
        .offset(x: isDeleting ? -300 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDeleting)
    }
    
    private func performDelete() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isDeleting = true
        }
        
        // Delete from database after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task {
                await taskManager.deleteTask(taskItem)
            }
        }
    }
}

// MARK: - Menu Bar Add Todo Sheet
struct MenuBarAddTodoSheet: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority = "medium"
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let priorities = ["low", "medium", "high"]
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Todo")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    closeWindow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: NSColor.windowBackgroundColor))
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Name *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("What do you need to do?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .font(.system(size: 13))
                            .frame(height: 60)
                            .padding(8)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                    
                    // Due Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Due Date")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.purple)
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Priority
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Priority")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(priorities, id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(priorityColor(p))
                                            .frame(width: 8, height: 8)
                                        Text(p.capitalized)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(priority == p ? priorityColor(p).opacity(0.15) : Color(nsColor: NSColor.controlBackgroundColor))
                                    .foregroundColor(priority == p ? priorityColor(p) : .primary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(priority == p ? priorityColor(p) : Color.gray.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasReminder) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(hasReminder ? .orange : .secondary)
                                Text("Set Reminder")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if hasReminder {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                DatePicker("", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(12)
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    closeWindow()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button {
                    saveTodo()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "plus")
                        }
                        Text(isSaving ? "Adding..." : "Add Todo")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding(20)
        }
        .frame(width: 400, height: 520)
        .interactiveDismissDisabled(isSaving)
    }
    
    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
    
    private func saveTodo() {
        print("DEBUG: saveTodo called")
        
        guard let userId = authManager.currentUser?.id else {
            print("DEBUG: No user ID")
            errorMessage = "Please log in first"
            showError = true
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            print("DEBUG: Title is empty")
            errorMessage = "Please enter a task name"
            showError = true
            return
        }
        
        print("DEBUG: Saving todo with title: \(trimmedTitle), userId: \(userId)")
        
        isSaving = true
        showError = false
        
        Task {
            let success = await createTodo(userId: userId)
            print("DEBUG: createTodo returned: \(success)")
            
            await MainActor.run {
                if success {
                    print("DEBUG: Todo saved successfully, refreshing tasks")
                    Task {
                        await taskManager.fetchTasks(for: userId)
                    }
                    // Close the window
                    closeWindow()
                } else {
                    isSaving = false
                    errorMessage = "Failed to save todo. Check console for details."
                    showError = true
                }
            }
        }
    }
    
    private func createTodo(userId: Int) async -> Bool {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dueDateStr = dateFormatter.string(from: dueDate)
        
        // Map priority to database values
        let dbPriority: String
        switch priority {
        case "high": dbPriority = "high"
        case "low": dbPriority = "low"
        default: dbPriority = "normal"
        }
        
        // user_id as string for Supabase
        var todoData: [String: Any] = [
            "user_id": String(userId),
            "task_name": title.trimmingCharacters(in: .whitespaces),
            "start_date": dueDateStr,
            "deadline": dueDateStr,
            "priority": dbPriority,
            "completed": false
        ]
        
        if !description.trimmingCharacters(in: .whitespaces).isEmpty {
            todoData["description"] = description.trimmingCharacters(in: .whitespaces)
        }
        
        print("DEBUG: Creating todo with data: \(todoData)")
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos") else {
            print("DEBUG: Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: todoData)
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG: Request body: \(jsonString)")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: Todo save response status: \(httpResponse.statusCode)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("DEBUG: Response body: \(responseStr)")
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG: Todo created successfully!")
                    return true
                } else {
                    print("DEBUG: Failed with status \(httpResponse.statusCode)")
                    return false
                }
            }
            return false
        } catch {
            print("DEBUG: Failed to save todo: \(error.localizedDescription)")
            return false
        }
    }
}

struct NoteSection: Codable, Identifiable {
    var id: String
    var name: String
    var notes: [String]
    
    init(id: String = UUID().uuidString, name: String, notes: [String] = [""]) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

struct MeetingNoteData: Codable {
    var id: Int?
    var meeting_id: Int
    var title: String
    var date: String
    var time: String
    var attendees: [String]
    var discussion_points: [String]
    var decisions_made: [String]
    var action_items: [String]
    var next_steps: [String]
    var discussion_sections: [NoteSection]?
    var decision_sections: [NoteSection]?
    var action_sections: [NoteSection]?
    var next_step_sections: [NoteSection]?
    var follow_up_date: String?
    var created_at: String?
    var updated_at: String?
}

// MARK: - Meeting Details Inline (shows inside dropdown)
struct MeetingDetailsInline: View {
    let meeting: TaskItem
    let onClose: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            HStack {
                Button { onClose() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("Meeting Details")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Spacer()
                
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Meeting Title Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meeting.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Status badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Scheduled")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Time & Date Cards
                    HStack(spacing: 8) {
                        // Time Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text("TIME")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(meeting.timeText)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                        )
                        
                        // Date Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("DATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(meeting.date, style: .date)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Description
                    if let desc = meeting.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("DESCRIPTION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(desc)
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.9))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: NSColor.controlBackgroundColor))
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                    
                    // Join Meeting Button
                    if let link = meeting.meetingLink {
                        Button {
                            if let url = URL(string: link) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 14))
                                Text("Join Meeting")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    }
                    
                    Spacer(minLength: 16)
                }
            }
            
            // Bottom button - Open Meeting Notes
            Button {
                openMeetingNotesWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                    Text("Open Meeting Notes")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.purple.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
    
    private func openMeetingNotesWindow() {
        let contentView = MeetingNotesView(meeting: meeting, onBack: {})
            .environmentObject(TaskManager.shared)
        
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Meeting Notes"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Meeting Sheet (for full app usage)
struct MenuBarMeetingSheet: View {
    let meeting: TaskItem
    let onClose: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    @State private var showMeetingNotes = false

    var body: some View {
        if showMeetingNotes {
            MeetingNotesView(meeting: meeting, onBack: { showMeetingNotes = false })
                .environmentObject(taskManager)
        } else {
            meetingDetailsView
        }
    }
    
    private var meetingDetailsView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Meeting Details")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Color.clear.frame(width: 20, height: 20)
            }
            .padding(16)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meeting", systemImage: "video.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(meeting.title)
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Divider()
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Time", systemImage: "clock")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(meeting.timeText)
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Date", systemImage: "calendar")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(meeting.date, style: .date)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    
                    if let desc = meeting.description, !desc.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(desc)
                                .font(.system(size: 13))
                        }
                    }
                    
                    if let link = meeting.meetingLink {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Meeting Link", systemImage: "link")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Button {
                                if let url = URL(string: link) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "video.fill")
                                    Text("Join Meeting")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            
            Button {
                withAnimation { showMeetingNotes = true }
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Open Meeting Notes")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(width: 400, height: 450)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
}

// MARK: - Meeting Notes View (opened manually)
struct MeetingNotesView: View {
    let meeting: TaskItem
    let onBack: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskManager: TaskManager

    @State private var isEditing = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var existingNotes: MeetingNoteData?

    // Meeting Notes Data
    @State private var noteTitle = ""
    @State private var noteDate = ""
    @State private var noteTime = ""
    @State private var attendees: [String] = []
    @State private var newAttendee = ""
    @State private var discussionPoints: [String] = [""]
    @State private var decisionsMade: [String] = [""]
    @State private var actionItems: [String] = [""]
    @State private var nextSteps: [String] = [""]
    @State private var followUpDate = ""

    // Sections
    @State private var discussionSections: [NoteSection] = []
    @State private var decisionSections: [NoteSection] = []
    @State private var actionSections: [NoteSection] = []
    @State private var nextStepSections: [NoteSection] = []

    // Section management
    @State private var showAddSection: [String: Bool] = [:]
    @State private var newSectionName: [String: String] = [:]
    @State private var expandedSections: Set<String> = []

    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            if isLoading {
                loadingView
            } else if isEditing {
                editView
            } else {
                documentView
            }
        }
        .frame(width: 900, height: 700)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            initializeData()
            loadMeetingNotes()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button { onBack() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18))
                Text("Meeting Notes")
                    .font(.system(size: 18, weight: .bold))
            }

            Spacer()

            if meeting.meetingLink != nil {
                Button {
                    if let link = meeting.meetingLink, let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                        Text("Join")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)], startPoint: .top, endPoint: .bottom))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading meeting notes...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document View (Read-only)
    private var documentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Document Header
                VStack(alignment: .center, spacing: 12) {
                    Text("Meeting Notes")
                        .font(.system(size: 28, weight: .bold))
                    
                    HStack(spacing: 16) {
                        metaItem("Meeting", noteTitle)
                        metaItem("Date", formatDisplayDate(noteDate))
                        metaItem("Time", noteTime)
                        if !followUpDate.isEmpty {
                            metaItem("Follow-up", formatDisplayDate(followUpDate))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                
                Divider()
                
                // Attendees
                if !attendees.isEmpty {
                    documentSection("Attendees") {
                        FlowLayout(spacing: 8) {
                            ForEach(attendees, id: \.self) { attendee in
                                Text(attendee)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // Discussion Points
                let filteredDiscussion = discussionPoints.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredDiscussion.isEmpty || !discussionSections.isEmpty {
                    documentSection("Key Discussion Points") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredDiscussion.enumerated()), id: \.offset) { idx, point in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(idx + 1).")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 24)
                                    Text(point)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(discussionSections) { section in
                                sectionDocView(section, prefix: "")
                            }
                        }
                    }
                }
                
                // Decisions Made
                let filteredDecisions = decisionsMade.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredDecisions.isEmpty || !decisionSections.isEmpty {
                    documentSection("Decisions Made") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredDecisions.enumerated()), id: \.offset) { idx, decision in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(decision)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(decisionSections) { section in
                                sectionDocView(section, prefix: "D")
                            }
                        }
                    }
                }
                
                // Action Items
                let filteredActions = actionItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredActions.isEmpty || !actionSections.isEmpty {
                    documentSection("Action Items") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredActions.enumerated()), id: \.offset) { idx, item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("A\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Text(item)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(actionSections) { section in
                                sectionDocView(section, prefix: "A")
                            }
                        }
                    }
                }
                
                // Next Steps
                let filteredSteps = nextSteps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredSteps.isEmpty || !nextStepSections.isEmpty {
                    documentSection("Next Steps") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredSteps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("→")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(step)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(nextStepSections) { section in
                                sectionDocView(section, prefix: "→")
                            }
                        }
                    }
                }
                
                Divider()
                
                // Edit Button
                HStack {
                    Spacer()
                    Button {
                        isEditing = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit Notes")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(32)
        }
    }
    
    private func sectionDocView(_ section: NoteSection, prefix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .foregroundColor(.secondary)
                Text(section.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.top, 8)
            
            ForEach(Array(section.notes.filter { !$0.isEmpty }.enumerated()), id: \.offset) { idx, note in
                HStack(alignment: .top, spacing: 12) {
                    if prefix.isEmpty {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text(prefix)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }
        }
        .padding(12)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func documentSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .padding(.bottom, 4)
            
            content()
        }
    }
    
    private func metaItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Edit View
    private var editView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Meeting Information Section
                    formSection("Meeting Information", icon: "info.circle.fill") {
                        VStack(spacing: 12) {
                            formField("Meeting Title") {
                                TextField("Enter meeting title", text: $noteTitle)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            HStack(spacing: 12) {
                                formField("Date") {
                                    TextField("YYYY-MM-DD", text: $noteDate)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                formField("Time") {
                                    TextField("HH:MM", text: $noteTime)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                formField("Follow-up Date") {
                                    TextField("YYYY-MM-DD", text: $followUpDate)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    // Attendees Section
                    formSection("Attendees", icon: "person.2.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Current attendees
                            FlowLayout(spacing: 8) {
                                ForEach(Array(attendees.enumerated()), id: \.offset) { idx, attendee in
                                    HStack(spacing: 4) {
                                        Text(attendee)
                                            .font(.system(size: 12, weight: .medium))
                                        Button {
                                            attendees.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                                    .clipShape(Capsule())
                                }
                            }
                            
                            // Add attendee
                            HStack(spacing: 8) {
                                TextField("Add attendee...", text: $newAttendee)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onSubmit { addAttendee() }
                                
                                Button { addAttendee() } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Add")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Discussion Points Section
                    notesSection(
                        title: "Key Discussion Points",
                        icon: "list.bullet",
                        items: $discussionPoints,
                        sections: $discussionSections,
                        sectionKey: "discussion"
                    )
                    
                    // Decisions Made Section
                    notesSection(
                        title: "Decisions Made",
                        icon: "checkmark.circle.fill",
                        items: $decisionsMade,
                        sections: $decisionSections,
                        sectionKey: "decisions",
                        itemPrefix: "D"
                    )
                    
                    // Action Items Section
                    notesSection(
                        title: "Action Items",
                        icon: "doc.text.fill",
                        items: $actionItems,
                        sections: $actionSections,
                        sectionKey: "actions",
                        itemPrefix: "A"
                    )
                    
                    // Next Steps Section
                    notesSection(
                        title: "Next Steps",
                        icon: "arrow.right.circle.fill",
                        items: $nextSteps,
                        sections: $nextStepSections,
                        sectionKey: "nextsteps",
                        itemPrefix: "N"
                    )
                }
                .padding(24)
            }
            
            // Save/Cancel buttons
            HStack(spacing: 16) {
                Button {
                    if existingNotes != nil {
                        isEditing = false
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
                .buttonStyle(.plain)
                
                Button {
                    saveMeetingNotes()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Saving..." : "Save Meeting Notes")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(20)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
        }
    }
    
    // MARK: - Form Components
    private func formSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            
            content()
        }
        .padding(16)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
    }
    
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }
    
    private func notesSection(
        title: String,
        icon: String,
        items: Binding<[String]>,
        sections: Binding<[NoteSection]>,
        sectionKey: String,
        itemPrefix: String = ""
    ) -> some View {
        formSection(title, icon: icon) {
            VStack(alignment: .leading, spacing: 12) {
                // Add Section button
                HStack {
                    Spacer()
                    Button {
                        showAddSection[sectionKey] = !(showAddSection[sectionKey] ?? false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text("Add Section")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                // Add section input
                if showAddSection[sectionKey] == true {
                    HStack(spacing: 8) {
                        TextField("Section name (e.g., Person name)", text: Binding(
                            get: { newSectionName[sectionKey] ?? "" },
                            set: { newSectionName[sectionKey] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            if let name = newSectionName[sectionKey], !name.isEmpty {
                                let newSection = NoteSection(name: name)
                                sections.wrappedValue.append(newSection)
                                expandedSections.insert(newSection.id)
                                newSectionName[sectionKey] = ""
                                showAddSection[sectionKey] = false
                            }
                        } label: {
                            Text("Create")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showAddSection[sectionKey] = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // General notes label
                Text("General Notes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                // General items
                ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, item in
                    noteItemRow(
                        index: idx,
                        item: item,
                        prefix: itemPrefix.isEmpty ? "\(idx + 1)" : "\(itemPrefix)\(idx + 1)",
                        onUpdate: { items.wrappedValue[idx] = $0 },
                        onAdd: {
                            items.wrappedValue.insert("", at: idx + 1)
                        },
                        onRemove: {
                            if items.wrappedValue.count > 1 {
                                items.wrappedValue.remove(at: idx)
                            }
                        },
                        canRemove: items.wrappedValue.count > 1
                    )
                }
                
                // Sections
                ForEach(Array(sections.wrappedValue.enumerated()), id: \.element.id) { sectionIdx, section in
                    sectionEditView(
                        section: section,
                        sectionIdx: sectionIdx,
                        sections: sections,
                        prefix: itemPrefix
                    )
                }
            }
        }
    }
    
    private func noteItemRow(
        index: Int,
        item: String,
        prefix: String,
        onUpdate: @escaping (String) -> Void,
        onAdd: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        canRemove: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Number badge
            Text(prefix)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.black)
                .clipShape(Circle())
            
            // Text input
            TextEditor(text: Binding(get: { item }, set: onUpdate))
                .font(.system(size: 13))
                .frame(minHeight: 60)
                .padding(8)
                .background(Color(nsColor: NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Controls
            VStack(spacing: 6) {
                Button { onAdd() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                if canRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func sectionEditView(
        section: NoteSection,
        sectionIdx: Int,
        sections: Binding<[NoteSection]>,
        prefix: String
    ) -> some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                if expandedSections.contains(section.id) {
                    expandedSections.remove(section.id)
                } else {
                    expandedSections.insert(section.id)
                }
            } label: {
                HStack {
                    Image(systemName: expandedSections.contains(section.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                    
                    Image(systemName: "person.circle")
                        .font(.system(size: 16))
                    
                    Text(section.name)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("(\(section.notes.filter { !$0.isEmpty }.count) notes)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        sections.wrappedValue.remove(at: sectionIdx)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(LinearGradient(colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            }
            .buttonStyle(.plain)
            
            // Section notes
            if expandedSections.contains(section.id) {
                VStack(spacing: 8) {
                    ForEach(Array(section.notes.enumerated()), id: \.offset) { noteIdx, note in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(prefix.isEmpty ? "" : prefix)\(noteIdx + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.gray)
                                .clipShape(Circle())
                            
                            TextEditor(text: Binding(
                                get: { section.notes[noteIdx] },
                                set: { sections.wrappedValue[sectionIdx].notes[noteIdx] = $0 }
                            ))
                            .font(.system(size: 13))
                            .frame(minHeight: 50)
                            .padding(8)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(spacing: 4) {
                                Button {
                                    sections.wrappedValue[sectionIdx].notes.insert("", at: noteIdx + 1)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                
                                if section.notes.count > 1 {
                                    Button {
                                        sections.wrappedValue[sectionIdx].notes.remove(at: noteIdx)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .frame(width: 22, height: 22)
                                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
    }
    
    // MARK: - Helper Functions
    private func initializeData() {
        noteTitle = meeting.title
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        noteDate = dateFormatter.string(from: meeting.date)
        noteTime = meeting.timeText
    }
    
    private func formatDisplayDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return dateStr }
        
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return date.map { formatter.string(from: $0) } ?? dateStr
    }
    
    private func addAttendee() {
        let trimmed = newAttendee.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !attendees.contains(trimmed) {
            attendees.append(trimmed)
            newAttendee = ""
        }
    }
    
    // MARK: - API Functions
    private func loadMeetingNotes() {
        guard let meetingId = Int(meeting.originalId) else {
            isLoading = false
            isEditing = true
            return
        }
        
        Task {
            guard let url = URL(string: "\(supabaseURL)/rest/v1/meeting_notes?meeting_id=eq.\(meetingId)&limit=1") else {
                await MainActor.run {
                    isLoading = false
                    isEditing = true
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let notes = try JSONDecoder().decode([MeetingNoteData].self, from: data)
                
                await MainActor.run {
                    if let note = notes.first {
                        existingNotes = note
                        noteTitle = note.title
                        noteDate = note.date
                        noteTime = note.time
                        attendees = note.attendees
                        discussionPoints = note.discussion_points.isEmpty ? [""] : note.discussion_points
                        decisionsMade = note.decisions_made.isEmpty ? [""] : note.decisions_made
                        actionItems = note.action_items.isEmpty ? [""] : note.action_items
                        nextSteps = note.next_steps.isEmpty ? [""] : note.next_steps
                        discussionSections = note.discussion_sections ?? []
                        decisionSections = note.decision_sections ?? []
                        actionSections = note.action_sections ?? []
                        nextStepSections = note.next_step_sections ?? []
                        followUpDate = note.follow_up_date ?? ""
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                    isLoading = false
                }
            } catch {
                print("Failed to load notes: \(error)")
                await MainActor.run {
                    isLoading = false
                    isEditing = true
                }
            }
        }
    }
    
    private func saveMeetingNotes() {
        guard let meetingId = Int(meeting.originalId) else { return }
        isSaving = true
        
        Task {
            // Clean up data
            let cleanedDiscussion = discussionPoints.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let cleanedDecisions = decisionsMade.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let cleanedActions = actionItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let cleanedSteps = nextSteps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            func cleanSections(_ sections: [NoteSection]) -> [NoteSection] {
                sections.compactMap { section in
                    let cleaned = section.notes.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    return cleaned.isEmpty ? nil : NoteSection(id: section.id, name: section.name, notes: cleaned)
                }
            }
            
            let noteData = MeetingNoteData(
                id: existingNotes?.id,
                meeting_id: meetingId,
                title: noteTitle,
                date: noteDate,
                time: noteTime,
                attendees: attendees,
                discussion_points: cleanedDiscussion,
                decisions_made: cleanedDecisions,
                action_items: cleanedActions,
                next_steps: cleanedSteps,
                discussion_sections: cleanSections(discussionSections),
                decision_sections: cleanSections(decisionSections),
                action_sections: cleanSections(actionSections),
                next_step_sections: cleanSections(nextStepSections),
                follow_up_date: followUpDate.isEmpty ? nil : followUpDate
            )
            
            let isUpdate = existingNotes?.id != nil
            let urlString: String
            let httpMethod: String
            
            if isUpdate, let id = existingNotes?.id {
                urlString = "\(supabaseURL)/rest/v1/meeting_notes?id=eq.\(id)"
                httpMethod = "PATCH"
            } else {
                urlString = "\(supabaseURL)/rest/v1/meeting_notes"
                httpMethod = "POST"
            }
            
            guard let url = URL(string: urlString) else {
                await MainActor.run { isSaving = false }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = httpMethod
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            do {
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(noteData)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    if let savedNotes = try? JSONDecoder().decode([MeetingNoteData].self, from: data).first {
                        await MainActor.run {
                            existingNotes = savedNotes
                            isEditing = false
                            isSaving = false
                        }
                    } else {
                        await MainActor.run {
                            isEditing = false
                            isSaving = false
                        }
                    }
                } else {
                    print("Save failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    await MainActor.run { isSaving = false }
                }
            } catch {
                print("Failed to save notes: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func calculateLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        let containerWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Full App Window View
struct FullAppWindowView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedTab = 0
    @State private var tabDirection: Int = 0

    private static let logoPath = "/Users/swumpyaesone/Documents/project_management/frontend/assets/logo/projectnextlogo.png"

    var body: some View {
        ZStack {
            Color(nsColor: NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            if authManager.isAuthenticated {
                mainContent
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerBar

            // Main content area
            ZStack {
                Color(nsColor: NSColor.windowBackgroundColor)

                switch selectedTab {
                case 0:
                    FullCalendarView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                case 1:
                    FullMeetingsView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                default:
                    FullCalendarView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await taskManager.fetchTasks(for: userId)
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            // Left section - Logo and progress
            HStack(spacing: 16) {
                // Logo
                HStack(spacing: 8) {
                    if let nsImage = NSImage(contentsOfFile: Self.logoPath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }
                    
                    Text("Project Next")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                // Progress pill
                let progress = getProgress()
                HStack(spacing: 8) {
                    ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                        .tint(progress.completed == progress.total ? .green : .accentColor)
                    
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Center section - Tab Selector
            HStack(spacing: 2) {
                tabButton("Personal", icon: "calendar", index: 0)
                tabButton("Meeting Schedule", icon: "video", index: 1)
            }
            .padding(3)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            // Right section - Actions
            HStack(spacing: 12) {
                Button {
                    // Add Todo
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                            .font(.system(size: 11))
                        Text("Add Todo")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button {
                    // Add Task
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add Task")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color(nsColor: NSColor.separatorColor))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            let oldTab = selectedTab
            withAnimation(.easeInOut(duration: 0.2)) {
                tabDirection = index > oldTab ? 1 : -1
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: selectedTab == index ? .semibold : .regular))
                Text(title)
                    .font(.system(size: 13, weight: selectedTab == index ? .semibold : .medium))
            }
            .foregroundColor(selectedTab == index ? .white : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func getProgress() -> (completed: Int, total: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayTasks = taskManager.todayTasks.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let total = todayTasks.count
        let completed = todayTasks.filter { $0.isCompleted }.count
        return (completed, total)
    }
}

// MARK: - Custom Window for Add Todo
class AddTodoWindow: NSWindow {
    private var clickMonitor: Any?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        
        // Monitor for clicks outside this window
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            // Close when clicking outside
            self.close()
        }
    }
    
    override func close() {
        // Remove the click monitor when closing
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        super.close()
    }
}
#endif

// MARK: - macOS App Delegate
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var notifiedTaskIds: Set<String> = []
    private var monitorTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app icon from file
        let iconPath = "/Users/swumpyaesone/Documents/project_management/frontend/assets/logo/projectnextlogo.png"
        if let iconImage = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImage
        }
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission with completion handler
        requestNotificationPermission()

        // Set up notification categories for action buttons
        setupNotificationCategories()

        // Start task monitoring (local)
        startTaskMonitoring()

        // Schedule notifications after a delay to let tasks load
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.scheduleAllTaskNotifications()
        }

        // Run as regular app (show in dock with icon)
        NSApp.setActivationPolicy(.regular)
        
        // Start floating notification task monitoring after tasks load
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            FloatingNotificationManager.shared.startTaskMonitoring()
        }
        
        print("Focus app launched")
    }
    
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        
        // Set delegate to receive notifications while app is in foreground
        center.delegate = self
        
        // Always request permission (will prompt user if not determined)
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission GRANTED")
                    // Send immediate test notification
                    self.sendImmediateNotification()
                } else {
                    print("Notification permission DENIED: \(error?.localizedDescription ?? "unknown")")
                    // Open System Settings for notifications
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    func sendImmediateNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Focus App"
        content.subtitle = "Notifications Enabled!"
        content.body = "You will receive reminders 5 minutes before your tasks."
        content.sound = .default
        content.categoryIdentifier = "FOCUS_TASK"
        
        // Trigger immediately (1 second)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-welcome-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            } else {
                print("Welcome notification scheduled!")
            }
        }
    }
    
    func setupNotificationCategories() {
        // Rize-style minimal actions
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
        
        // Meeting category
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
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let taskId = response.notification.request.content.userInfo["taskId"] as? String ?? ""
        
        switch response.actionIdentifier {
        case "COMPLETE":
            print("User marked task complete: \(taskId)")
            Task { @MainActor in
                // Find and complete the task
                if let task = TaskManager.shared.todayTasks.first(where: { $0.id == taskId }) {
                    await TaskManager.shared.toggleComplete(task: task)
                }
            }
            
        case "SNOOZE_5":
            print("User snoozed task 5 min: \(taskId)")
            rescheduleNotification(taskId: taskId, minutes: 5)
            
        case "SNOOZE_15":
            print("User snoozed task 15 min: \(taskId)")
            rescheduleNotification(taskId: taskId, minutes: 15)
            
        case "SKIP":
            print("User skipped task: \(taskId)")
            Task { @MainActor in
                if let task = TaskManager.shared.todayTasks.first(where: { $0.id == taskId }) {
                    TaskManager.shared.skipTask(task, reason: "Skipped from notification")
                }
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // Show notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner, play sound even when app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    private func rescheduleNotification(taskId: String, minutes: Int) {
        Task { @MainActor in
            guard let task = TaskManager.shared.todayTasks.first(where: { $0.id == taskId }) else { return }
            
            let newTime = Date().addingTimeInterval(Double(minutes * 60))
            
            let content = UNMutableNotificationContent()
            content.title = "Reminder: \(task.title)"
            content.subtitle = "Snoozed task"
            content.body = "Your task is waiting"
            content.sound = .default
            content.categoryIdentifier = "TASK_REMINDER"
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["taskId": taskId]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
            let request = UNNotificationRequest(identifier: "snooze-\(taskId)-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
            print("Rescheduled notification for \(minutes) minutes")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running when windows are closed
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Hide instead of quit when Command+Q is pressed
        // Return .terminateCancel to prevent quitting, but this can be frustrating
        // Instead, let's just keep running - the menu bar extra keeps the app alive
        print("App termination requested - app will continue running in menu bar")
        return .terminateNow  // Allow termination but app stays in menu bar due to MenuBarExtra
    }
    
    func startTaskMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingTasks()
            }
        }
        Task { @MainActor in
            checkUpcomingTasks()
        }
    }
    
    @MainActor
    func checkUpcomingTasks() {
        let tasks = TaskManager.shared.todayTasks
        let now = Date()
        let calendar = Calendar.current
        
        for task in tasks {
            guard let startTime = task.startTime,
                  !task.isCompleted,
                  !task.isSkipped,
                  !notifiedTaskIds.contains(task.id) else { continue }
            
            let diff = calendar.dateComponents([.minute], from: now, to: startTime).minute ?? 0
            
            if diff >= 4 && diff <= 6 {
                sendNotification(for: task, minutesUntil: diff)
                notifiedTaskIds.insert(task.id)
            }
        }
    }
    
    @MainActor
    func scheduleAllTaskNotifications() {
        let tasks = TaskManager.shared.todayTasks
        let now = Date()
        
        print("Scheduling notifications for \(tasks.count) tasks")
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        var scheduledCount = 0
        for task in tasks {
            guard let startTime = task.startTime,
                  !task.isCompleted,
                  !task.isSkipped else { continue }
            
            let notifyTime = startTime.addingTimeInterval(-5 * 60)
            
            if notifyTime > now {
                scheduleNotification(for: task, at: notifyTime)
                scheduledCount += 1
                print("Scheduled notification for '\(task.title)' at \(notifyTime)")
            }
        }
        
        print("Total notifications scheduled: \(scheduledCount)")
        
        // Send a test notification after 5 seconds to verify notifications work
        sendTestNotification()
    }
    
    func sendTestNotification() {
        print("Attempting to send test notification...")
        
        let content = UNMutableNotificationContent()
        content.title = "Focus App"
        content.subtitle = "Test Notification"
        content.body = "If you see this, notifications are working!"
        content.sound = .default
        content.categoryIdentifier = "FOCUS_TASK"

        // Send after 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-test-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Test notification FAILED: \(error.localizedDescription)")
            } else {
                print("Test notification SCHEDULED - should appear in 2 seconds")
            }
        }
    }
    
    func scheduleNotification(for task: TaskItem, at date: Date) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = task.startTime != nil ? timeFormatter.string(from: task.startTime!) : ""
        
        // Rize-style notification
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.subtitle = task.title
        content.body = "Starting in 5 min \u{2022} \(timeString)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        content.categoryIdentifier = "FOCUS_TASK"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "focus-reminders"
        content.userInfo = ["taskId": task.id, "taskType": task.type.displayName]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "focus-scheduled-\(task.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendNotification(for task: TaskItem, minutesUntil: Int) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = task.startTime != nil ? timeFormatter.string(from: task.startTime!) : ""
        
        // Rize-style notification
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.subtitle = task.title
        content.body = "\(minutesUntil) min remaining \u{2022} \(timeString)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        content.categoryIdentifier = "FOCUS_TASK"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "focus-reminders"
        content.userInfo = ["taskId": task.id]

        let request = UNNotificationRequest(
            identifier: "focus-immediate-\(task.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
}

// MARK: - Floating Notification Manager
class FloatingNotificationManager {
    static let shared = FloatingNotificationManager()
    
    private var notificationPanel: NSPanel?
    private var keepOnTopTimer: Timer?
    private var taskMonitorTimer: Timer?
    private var notifiedTaskIds: Set<String> = []
    
    func startTaskMonitoring() {
        // Check every 30 seconds for upcoming tasks
        taskMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkUpcomingTasks()
        }
        // Also check immediately
        checkUpcomingTasks()
    }
    
    func stopTaskMonitoring() {
        taskMonitorTimer?.invalidate()
        taskMonitorTimer = nil
    }
    
    private func checkUpcomingTasks() {
        Task { @MainActor in
            let tasks = TaskManager.shared.todayTasks
            let calendar = Calendar.current
            let now = Date()
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            let currentTotalMinutes = currentHour * 60 + currentMinute
            
            for task in tasks {
                // Skip completed tasks
                if task.isCompleted { continue }
                
                // Skip already notified tasks
                let notificationId = "\(task.id)-\(task.startHour)-\(task.startMinute)"
                if self.notifiedTaskIds.contains(notificationId) { continue }
                
                let taskTotalMinutes = task.startHour * 60 + task.startMinute
                let minutesUntilTask = taskTotalMinutes - currentTotalMinutes
                
                // Notify if task is 5 minutes away or less (but not past)
                if minutesUntilTask >= 0 && minutesUntilTask <= 5 {
                    self.notifiedTaskIds.insert(notificationId)
                    self.showTaskReminder(task: task, minutesBefore: minutesUntilTask)
                }
            }
            
            // Clean up old notification IDs at midnight
            if currentHour == 0 && currentMinute == 0 {
                self.notifiedTaskIds.removeAll()
            }
        }
    }
    
    func show(title: String, subtitle: String = "", body: String, duration: TimeInterval = 8.0, showCloseButton: Bool = false) {
        DispatchQueue.main.async {
            self.dismiss()
            NSSound(named: "Glass")?.play()

            let notificationView = FloatingNotificationView(
                title: title,
                subtitle: subtitle,
                message: body,
                task: nil,
                onDone: nil,
                onSnooze: nil,
                onSkip: nil,
                onDismiss: { self.dismiss() },
                showCloseButton: showCloseButton
            )

            self.showWindow(with: notificationView, height: 90, duration: duration)
        }
    }
    
    func showTaskReminder(task: TaskItem, minutesBefore: Int = 5) {
        DispatchQueue.main.async {
            self.dismiss()
            NSSound(named: "Glass")?.play()

            let timeStr = self.formatTime12Hour(hour: task.startHour, minute: task.startMinute)
            let isNow = minutesBefore == 0
            let message = isNow ? "Starting now!" : "Starting in \(minutesBefore) min • \(timeStr)"

            let notificationView = FloatingNotificationView(
                title: "Task Reminder",
                subtitle: task.title,
                message: message,
                task: task,
                onDone: {
                    self.markTaskDone(task)
                    self.dismiss()
                },
                onSnooze: {
                    self.snoozeTask(task)
                    self.dismiss()
                },
                onSkip: {
                    self.skipTask(task)
                    self.dismiss()
                },
                onDismiss: { self.dismiss() },
                showCloseButton: true
            )

            self.showWindow(with: notificationView, height: 140, duration: 30.0)
        }
    }
    
    private func showWindow(with view: FloatingNotificationView, height: CGFloat, duration: TimeInterval) {
        let windowWidth: CGFloat = 360
        let windowHeight: CGFloat = height

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Start position: off-screen to the right
        let startX = screenFrame.maxX + 20
        // End position: top-right corner
        let endX = screenFrame.maxX - windowWidth - 16
        let windowY = screenFrame.maxY - windowHeight - 8

        // Create a floating panel (like system notifications)
        let panel = NSPanel(
            contentRect: NSRect(x: startX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu // High level that appears above most windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0
        panel.isFloatingPanel = true
        
        // Store reference
        self.notificationPanel = panel
        
        // Show panel (starts off-screen)
        panel.orderFrontRegardless()
        
        // Smooth slide-in animation from right
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(NSPoint(x: endX, y: windowY))
            panel.animator().alphaValue = 1
        }
        
        // Keep panel on top for a limited time
        self.keepOnTopTimer?.invalidate()
        self.keepOnTopTimer = nil
        
        // Auto-dismiss using DispatchQueue (more reliable than Timer)
        let dismissDuration = duration
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDuration) { [weak self] in
            self?.dismiss()
        }
    }
    
    func dismiss() {
        keepOnTopTimer?.invalidate()
        keepOnTopTimer = nil
        
        guard let panel = notificationPanel else { return }
        
        guard let screen = NSScreen.main else {
            panel.orderOut(nil)
            self.notificationPanel = nil
            return
        }
        
        // Slide out animation to right
        let endX = screen.visibleFrame.maxX + 20
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: endX, y: panel.frame.origin.y))
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            self.notificationPanel = nil
        })
    }
    
    private func markTaskDone(_ task: TaskItem) {
        Task { @MainActor in
            await TaskManager.shared.toggleComplete(task: task)
            self.show(title: "Done!", subtitle: task.title, body: "Task marked as completed", duration: 3.0)
        }
    }
    
    private func snoozeTask(_ task: TaskItem) {
        // Remove from notified so it can notify again
        let notificationId = "\(task.id)-\(task.startHour)-\(task.startMinute)"
        notifiedTaskIds.remove(notificationId)
        
        // Show snooze confirmation
        show(title: "Snoozed", subtitle: task.title, body: "Will remind you again in 5 minutes", duration: 3.0)
        
        // Re-notify in 5 minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            self?.showTaskReminder(task: task, minutesBefore: 0)
        }
    }
    
    private func skipTask(_ task: TaskItem) {
        show(title: "Skipped", subtitle: task.title, body: "Task skipped for today", duration: 3.0)
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Floating Notification View with Actions
// Close button that works in non-activating panels
struct CloseButton: NSViewRepresentable {
    let onDismiss: () -> Void
    
    func makeNSView(context: Context) -> ClickableCloseButton {
        let button = ClickableCloseButton(onDismiss: onDismiss)
        return button
    }
    
    func updateNSView(_ nsView: ClickableCloseButton, context: Context) {}
}

class ClickableCloseButton: NSView {
    private let onDismiss: () -> Void
    private var isHovering = false
    private var imageView: NSImageView!
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        imageView = NSImageView(frame: bounds)
        imageView.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        imageView.contentTintColor = NSColor.secondaryLabelColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        
        // Add tracking area
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseDown(with event: NSEvent) {
        onDismiss()
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        imageView.contentTintColor = NSColor.labelColor
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        imageView.contentTintColor = NSColor.secondaryLabelColor
    }
}

struct FloatingNotificationView: View {
    let title: String
    let subtitle: String
    let message: String
    let task: TaskItem?
    let onDone: (() -> Void)?
    let onSnooze: (() -> Void)?
    let onSkip: (() -> Void)?
    let onDismiss: () -> Void
    var iconName: String = "bell.fill"
    var showCloseButton: Bool = true
    
    @State private var isAppearing = false
    
    var hasActions: Bool {
        onDone != nil || onSnooze != nil || onSkip != nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // App logo with animation
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color.purple, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .scaleEffect(isAppearing ? 1 : 0.5)
            .opacity(isAppearing ? 1 : 0)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Header row with title
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project Next")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(subtitle.isEmpty ? title : subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary.opacity(0.9))
                            .lineLimit(2)
                    }
                    .offset(x: isAppearing ? 0 : -20)
                    .opacity(isAppearing ? 1 : 0)
                    
                    Spacer(minLength: 8)
                    
                    // Time label
                    Text("now")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .opacity(isAppearing ? 1 : 0)
                }
                
                // Message
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Action buttons
                if hasActions {
                    HStack(spacing: 10) {
                        if let onDone = onDone {
                            Button {
                                onDone()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Done")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let onSnooze = onSnooze {
                            Button {
                                onSnooze()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("+5 min")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.purple.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let onSkip = onSkip {
                            Button {
                                onSkip()
                            } label: {
                                Text("Skip")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .padding(.trailing, showCloseButton ? 24 : 0) // Extra space for close button
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            // X close button in top-right corner
            if showCloseButton {
                CloseButton(onDismiss: onDismiss)
                    .frame(width: 20, height: 20)
                    .padding(10)
            }
        }
        .scaleEffect(isAppearing ? 1 : 0.9)
        .offset(x: isAppearing ? 0 : 50)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                isAppearing = true
            }
        }
    }
}


#endif
