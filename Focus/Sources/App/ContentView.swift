//
//  ContentView.swift
//  Focus
//
//  Main content with tabs: Today, Todo List, Meetings
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedTab = 0
    @State private var showFullApp = false
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainContent
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
    }
    
    private var mainContent: some View {
        #if os(iOS)
        iOSContent
        #else
        macOSContent
        #endif
    }
    
    #if os(iOS)
    private var iOSContent: some View {
        TabView(selection: $selectedTab) {
            TodayScheduleView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(0)
            
            TodoListView()
                .tabItem { Label("Todo", systemImage: "checklist") }
                .tag(1)
            
            MeetingsView()
                .tabItem { Label("Meetings", systemImage: "calendar") }
                .tag(2)
        }
        .onAppear { fetchData() }
    }
    #endif
    
    #if os(macOS)
    private var macOSContent: some View {
        VStack(spacing: 0) {
            // Rize-style header
            miniAppHeader
            
            // Tab bar
            miniTabBar
            
            // Content
            ZStack {
                Color(nsColor: NSColor.windowBackgroundColor)
                
                switch selectedTab {
                case 0:
                    TodayScheduleView()
                        .transition(.opacity)
                case 1:
                    TodoListView()
                        .transition(.opacity)
                case 2:
                    MeetingsView()
                        .transition(.opacity)
                default:
                    TodayScheduleView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(width: 400, height: 580)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear { fetchData() }
        .sheet(isPresented: $showFullApp) {
            FullAppView()
                .environmentObject(taskManager)
                .environmentObject(authManager)
                .frame(minWidth: 1200, minHeight: 800)
        }
    }
    
    // System theme header with Project Next logo
    private var miniAppHeader: some View {
        HStack(spacing: 12) {
            // Logo and name
            HStack(spacing: 10) {
                // Project Next Logo
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                
                Text("Project Next")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Daily Progress
            let progress = getDailyProgress()
            HStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progress.percentage >= 100 ? Color.green : Color.accentColor)
                            .frame(width: geometry.size.width * CGFloat(min(progress.percentage, 100)) / 100, height: 6)
                    }
                }
                .frame(width: 60, height: 6)
                
                Text("\(progress.completed)/\(progress.total)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(progress.percentage >= 100 ? .green : .accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(progress.percentage >= 100 ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
            )
            
            // Full app button
            Button {
                showFullApp = true
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Open Full App")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .overlay(
            Rectangle()
                .fill(Color(nsColor: NSColor.separatorColor))
                .frame(height: 1),
            alignment: .bottom
        )
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
    
    private var miniTabBar: some View {
        HStack(spacing: 2) {
            miniTabButton(index: 0, icon: "sun.max", title: "Today")
            miniTabButton(index: 1, icon: "checklist", title: "Todo")
            miniTabButton(index: 2, icon: "calendar", title: "Meetings")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func miniTabButton(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: selectedTab == index ? icon + ".fill" : icon)
                    .font(.system(size: 11))
                
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundColor(selectedTab == index ? .white : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func requestMiniNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("Notifications enabled from mini app")
            }
        }
    }
    #endif
    
    private func fetchData() {
        if let userId = authManager.currentUser?.id {
            Task {
                await taskManager.fetchTasks(for: userId)
            }
        }
    }
    
    private func getDailyProgress() -> (completed: Int, total: Int, percentage: Double) {
        let todayTasks = taskManager.todayTasks
        let total = todayTasks.count
        let completed = todayTasks.filter { $0.isCompleted }.count
        let percentage = total > 0 ? Double(completed) / Double(total) * 100 : 0
        return (completed, total, percentage)
    }
}

// MARK: - Full App View
#if os(macOS)
struct FullAppView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var showAddTodo = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ZStack {
                Color(nsColor: NSColor.windowBackgroundColor)

                switch selectedTab {
                case 0:
                    FullCalendarView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                case 1:
                    FullTodoView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                case 2:
                    FullMeetingsView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                default:
                    FullCalendarView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            // Set window to maximum size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for window in NSApp.windows {
                    if window.isVisible && window.title.contains("Focus") || window.isKeyWindow {
                        if let screen = NSScreen.main {
                            let frame = screen.visibleFrame
                            window.setFrame(frame, display: true, animate: true)
                            window.styleMask.insert(.resizable)
                            window.styleMask.insert(.fullSizeContentView)
                            window.collectionBehavior = [.fullScreenPrimary, .managed]
                            window.minSize = NSSize(width: 1200, height: 800)
                        }
                        break
                    }
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 20) {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            // Logo and title
            HStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                
                Text("Project Next")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // Daily Progress
            let progress = getDailyProgress()
            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.1))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progress.percentage >= 100 ? Color.green : Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(min(progress.percentage, 100)) / 100)
                    }
                }
                .frame(width: 100, height: 6)
                
                Text("\(progress.completed)/\(progress.total)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(progress.percentage >= 100 ? .green : .accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(progress.percentage >= 100 ? Color.green.opacity(0.1) : Color.accentColor.opacity(0.1))
            )

            Spacer()

            // View mode tabs (system styled)
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
                
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { index in
                        let titles = ["Personal", "Todo List", "Meetings"]
                        let icons = ["calendar", "checklist", "person.2"]
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = index
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: icons[index])
                                    .font(.system(size: 12))
                                Text(titles[index])
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(selectedTab == index ? .primary : .secondary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if selectedTab == index {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(nsColor: NSColor.selectedContentBackgroundColor).opacity(0.3))
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
            }
            .fixedSize()

            Spacer()

            // Notification button
            Button {
                requestNotificationPermission()
            } label: {
                Image(systemName: "bell.badge")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .help("Enable notifications for task reminders")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notifications enabled")
                // Schedule notifications for upcoming tasks
                scheduleTaskNotifications()
            } else if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
    
    private func scheduleTaskNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Get upcoming tasks
        let upcomingTasks = taskManager.todayTasks.filter { task in
            guard let startTime = task.startTime, !task.isCompleted else { return false }
            let reminderTime = startTime.addingTimeInterval(-300) // 5 minutes before
            return reminderTime > Date()
        }
        
        for task in upcomingTasks.prefix(10) {
            guard let startTime = task.startTime else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Upcoming: \(task.title)"
            content.body = "Starts in 5 minutes"
            content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
            content.interruptionLevel = .timeSensitive
            
            let reminderDate = startTime.addingTimeInterval(-300)
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(identifier: "task-\(task.id)", content: content, trigger: trigger)
            center.add(request)
        }
        
        print("Scheduled \(min(upcomingTasks.count, 10)) task notifications")
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedTab == index ? icon + ".fill" : icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(selectedTab == index ? Color.accentColor : Color.clear)
            .foregroundColor(selectedTab == index ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private func getDailyProgress() -> (completed: Int, total: Int, percentage: Double) {
        let todayTasks = taskManager.todayTasks
        let total = todayTasks.count
        let completed = todayTasks.filter { $0.isCompleted }.count
        let percentage = total > 0 ? Double(completed) / Double(total) * 100 : 0
        return (completed, total, percentage)
    }
}

// MARK: - Full Todo View
struct FullTodoView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var showAddTodo = false
    @State private var newTodoTitle = ""
    @State private var selectedFilter = 0 // 0 = Active, 1 = Completed
    
    private var todos: [TaskItem] {
        taskManager.todayTasks.filter { $0.type == .todo }
            .sorted { ($0.date, $0.title) < ($1.date, $1.title) }
    }
    
    private var activeTodos: [TaskItem] {
        todos.filter { !$0.isCompleted }
    }
    
    private var completedTodos: [TaskItem] {
        todos.filter { $0.isCompleted }
    }
    
    private var displayedTodos: [TaskItem] {
        selectedFilter == 0 ? activeTodos : completedTodos
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                header
                
                // Content - fills remaining space
                if todos.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    todoList
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(isPresented: $showAddTodo) {
            AddTodoSheet()
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
    }
    
    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Todo List")
                    .font(.title)
                    .fontWeight(.bold)
                Text("\(activeTodos.count) active, \(completedTodos.count) completed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Filter tabs
            HStack(spacing: 4) {
                filterButton(title: "Active", count: activeTodos.count, index: 0)
                filterButton(title: "Completed", count: completedTodos.count, index: 1)
            }
            .padding(4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
            
            Button {
                showAddTodo = true
            } label: {
                Label("Add Todo", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
    
    private func filterButton(title: String, count: Int, index: Int) -> some View {
        Button {
            withAnimation { selectedFilter = index }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(selectedFilter == index ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedFilter == index ? Color.accentColor : Color.clear)
            .foregroundColor(selectedFilter == index ? .white : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var todoList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(displayedTodos) { todo in
                    todoRow(todo)
                }
            }
            .padding(24)
        }
    }
    
    private func todoRow(_ todo: TaskItem) -> some View {
        HStack(spacing: 16) {
            Button {
                Task { await taskManager.toggleComplete(task: todo) }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(todo.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.system(size: 16, weight: .medium))
                    .strikethrough(todo.isCompleted)
                    .foregroundColor(todo.isCompleted ? .secondary : .primary)
                
                if let desc = todo.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(formatDate(todo.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Delete button
            Button {
                Task { await deleteTodo(todo) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No todos yet")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Add your first todo item to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button {
                showAddTodo = true
            } label: {
                Label("Add Todo", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func deleteTodo(_ todo: TaskItem) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        // Try to delete from personal_todos first
        if todo.originalType == "todo" {
            guard let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos?id=eq.\(todo.originalId)") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                _ = try await URLSession.shared.data(for: request)
                if let userId = authManager.currentUser?.id {
                    await taskManager.fetchTasks(for: userId)
                }
            } catch {
                print("Failed to delete todo: \(error)")
            }
        }
    }
}

// MARK: - Add Todo Sheet
struct AddTodoSheet: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var hasReminder = false
    @State private var reminderTime = Date()
    @State private var priority: String = "normal"
    @State private var isSaving = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Todo")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Add a task to your todo list")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: NSColor.windowBackgroundColor))
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("What do you need to do?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2)))
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .font(.system(size: 13))
                            .frame(height: 60)
                            .padding(8)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2)))
                    }
                    
                    // Due Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Due Date")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                        }
                        .padding(12)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2)))
                    }
                    
                    // Priority
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Priority")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            ForEach(["low", "normal", "high"], id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(priorityColor(p))
                                            .frame(width: 8, height: 8)
                                        Text(p.capitalized)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(priority == p ? priorityColor(p).opacity(0.15) : Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(priority == p ? priorityColor(p) : Color.gray.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $hasReminder) {
                            HStack {
                                Image(systemName: "bell")
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
                                DatePicker("", selection: $reminderTime, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.field)
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(12)
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    saveTodo()
                } label: {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Label("Add Todo", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || isSaving)
            }
            .padding(16)
            .background(Color(nsColor: NSColor.windowBackgroundColor))
        }
        .frame(width: 420, height: 520)
    }
    
    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "high": return .red
        case "low": return .green
        default: return .blue
        }
    }
    
    private func saveTodo() {
        guard let userId = authManager.currentUser?.id else { 
            print("DEBUG TODO: No user ID found")
            return 
        }
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("DEBUG TODO: Title is empty")
            return
        }
        
        isSaving = true
        
        Task {
            await createTodo(userId: userId)
            await MainActor.run {
                isSaving = false
            }
            await taskManager.fetchTasks(for: userId)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func createTodo(userId: Int) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Use correct column names for personal_todos table
        var todoData: [String: Any] = [
            "user_id": userId,
            "task_name": title,
            "deadline": dateFormatter.string(from: dueDate),
            "start_date": dateFormatter.string(from: dueDate),
            "priority": "normal",
            "completed": false
        ]
        
        // Only add description if not empty
        if !description.isEmpty {
            todoData["description"] = description
        }
        
        print("DEBUG TODO: Creating todo with data: \(todoData)")
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos") else { 
            print("DEBUG TODO: Invalid URL")
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: todoData)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG TODO: Response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG TODO: Successfully created todo")
                } else {
                    let responseStr = String(data: data, encoding: .utf8) ?? ""
                    print("DEBUG TODO: Error response: \(responseStr)")
                }
            }
        } catch {
            print("DEBUG TODO: Failed to save todo: \(error)")
        }
    }
}

// MARK: - Full Calendar View (Apple Calendar Style)
struct FullCalendarView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDate = Date()
    @State private var viewMode: CalendarViewMode = .day
    @State private var selectedTask: TaskItem?
    @State private var showTaskPopup = false
    @State private var showAddTask = false
    @State private var showAddTodo = false
    @State private var taskToEdit: TaskItem?

    // Drag to create (day view)
    @State private var isDragging = false
    @State private var dragStartY: CGFloat = 0
    @State private var dragCurrentY: CGFloat = 0
    @State private var dragStartTime: Date?
    @State private var dragEndTime: Date?

    // Drag to create (week view)
    @State private var weekDragDay: Date?
    @State private var weekDragStartY: CGFloat = 0
    @State private var weekDragCurrentY: CGFloat = 0
    @State private var isWeekDragging = false

    // Resize task
    @State private var resizingTaskId: String?
    @State private var resizeStartHeight: CGFloat = 0
    @State private var resizeDelta: CGFloat = 0

    enum CalendarViewMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
    }
    
    private let hourHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                dateNavigation

                if viewMode == .day {
                    dayView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    weekView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .animation(.easeInOut(duration: 0.2), value: viewMode)
        }
        .sheet(isPresented: $showTaskPopup) {
            if let task = selectedTask {
                TaskPopupView(task: task, onEdit: { taskToEdit = task }, onClose: { showTaskPopup = false }, onDuplicate: { duplicateTask(task) })
                    .environmentObject(taskManager)
                    .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddEditTaskView(date: selectedDate, task: nil, startTime: dragStartTime, endTime: dragEndTime)
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
        .sheet(item: $taskToEdit) { task in
            AddEditTaskView(date: selectedDate, task: task, startTime: nil, endTime: nil)
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showAddTodo) {
            AddTodoSheet()
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
    }
    
    private var dateNavigation: some View {
        HStack(spacing: 16) {
            // Navigation
            HStack(spacing: 12) {
                Button {
                    navigatePrevious()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                
                VStack(spacing: 2) {
                    Text(dateTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(dateSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 180)
                
                Button {
                    navigateNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // View mode toggle
            HStack(spacing: 4) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) { viewMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(viewMode == mode ? Color.accentColor : Color.clear)
                            .foregroundColor(viewMode == mode ? .white : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
            
            Spacer()
            
            Button("Today") {
                withAnimation { selectedDate = Date() }
            }
            .buttonStyle(.bordered)
            
            // Add Todo button
            Button {
                showAddTodo = true
            } label: {
                Label("Add Todo", systemImage: "checklist")
            }
            .buttonStyle(.bordered)
            
            Button {
                dragStartTime = nil
                dragEndTime = nil
                showAddTask = true
            } label: {
                Label("Add Task", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }
    
    // MARK: - Day View
    private var dayView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: true) {
                HStack(alignment: .top, spacing: 0) {
                    // Time column (inside ScrollView now)
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: hourHeight, alignment: .topTrailing)
                                .padding(.trailing, 8)
                        }
                    }
                    .frame(width: 70)
                    
                    // Main content area
                    ZStack(alignment: .topLeading) {
                        hourGrid
                        
                        if Calendar.current.isDateInToday(selectedDate) {
                            currentTimeLine
                        }
                        
                        // Tasks with overlap handling
                        GeometryReader { geo in
                            let layouts = calculateTaskLayouts(for: tasksForDay)
                            let availableWidth = geo.size.width - 20
                            
                            ForEach(layouts) { layout in
                                let task = layout.task
                                let columnWidth = availableWidth / CGFloat(layout.totalColumns)
                                let xOffset = CGFloat(layout.column) * columnWidth + 10
                                
                                ResizableTaskBlock(
                                    task: task,
                                    hourHeight: hourHeight,
                                    isResizing: resizingTaskId == task.id,
                                    resizeDelta: resizingTaskId == task.id ? resizeDelta : 0,
                                    onTap: {
                                        selectedTask = task
                                        showTaskPopup = true
                                    },
                                    onResizeStart: {
                                        resizingTaskId = task.id
                                        resizeDelta = 0
                                    },
                                    onResizeChange: { delta in
                                        resizeDelta = delta
                                    },
                                    onResizeEnd: { delta in
                                        let minutes = Int(delta / hourHeight * 60)
                                        updateTaskDuration(task, offsetMinutes: minutes)
                                        resizingTaskId = nil
                                        resizeDelta = 0
                                    },
                                    onEdit: { taskToEdit = task },
                                    onDuplicate: { duplicateTask(task) },
                                    onComplete: { Task { await taskManager.toggleComplete(task: task) } },
                                    onMoveEnd: { delta in
                                        let minutes = Int(delta / hourHeight * 60)
                                        moveTask(task, offsetMinutes: minutes)
                                    }
                                )
                                .frame(width: columnWidth - 4) // Small gap between columns
                                .offset(x: xOffset)
                            }
                        }
                        
                        // Drag to create preview
                        if isDragging {
                            dragPreview
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(createTaskGesture)
                }
            }
            .onAppear {
                let hour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(0, hour - 2), anchor: .top)
            }
        }
    }
    
    // MARK: - Week View
    private var weekView: some View {
        VStack(spacing: 0) {
            // Week day headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 70)
                
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(dayName(day))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("\(dayNumber(day))")
                            .font(.system(size: 16, weight: Calendar.current.isDateInToday(day) ? .bold : .medium))
                            .foregroundColor(Calendar.current.isDateInToday(day) ? .white : .primary)
                            .frame(width: 32, height: 32)
                            .background(Calendar.current.isDateInToday(day) ? Color.accentColor : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.1) : Color.clear)
                    .onTapGesture {
                        withAnimation { selectedDate = day }
                    }
                }
            }
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            // Week grid with synced scroll
            GeometryReader { geometry in
                let dayWidth = (geometry.size.width - 70) / 7
                
                ScrollView(showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Time column inside scroll
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(formatHour(hour))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, height: hourHeight, alignment: .topTrailing)
                                    .padding(.trailing, 8)
                            }
                        }
                        .frame(width: 70)
                        
                        // Days columns
                        ForEach(Array(weekDays.enumerated()), id: \.element) { index, day in
                            ZStack(alignment: .topLeading) {
                                    // Hour lines with 15/30 minute intervals
                                    VStack(spacing: 0) {
                                        ForEach(0..<24, id: \.self) { _ in
                                            ZStack(alignment: .top) {
                                                // Main hour line
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.25))
                                                    .frame(height: 1)
                                                
                                                // 15-minute line
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.08))
                                                    .frame(height: 1)
                                                    .offset(y: hourHeight * 0.25)
                                                
                                                // 30-minute line
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.15))
                                                    .frame(height: 1)
                                                    .offset(y: hourHeight * 0.5)
                                                
                                                // 45-minute line
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.08))
                                                    .frame(height: 1)
                                                    .offset(y: hourHeight * 0.75)
                                            }
                                            .frame(height: hourHeight, alignment: .top)
                                        }
                                    }
                                    
                                    // Tasks for this day with overlap handling
                                    let dayTasks = tasksForDate(day)
                                    let layouts = calculateTaskLayouts(for: dayTasks)
                                    
                                    GeometryReader { dayGeo in
                                        let availableWidth = dayGeo.size.width - 4
                                        
                                        ForEach(layouts) { layout in
                                            let task = layout.task
                                            let columnWidth = availableWidth / CGFloat(layout.totalColumns)
                                            let xOffset = CGFloat(layout.column) * columnWidth + 2
                                            
                                            WeekTaskBlock(
                                                task: task,
                                                hourHeight: hourHeight,
                                                onTap: {
                                                    selectedDate = day
                                                    selectedTask = task
                                                    showTaskPopup = true
                                                },
                                                onResizeEnd: { delta in
                                                    let minutes = Int(delta / hourHeight * 60)
                                                    updateTaskDuration(task, offsetMinutes: minutes)
                                                },
                                                onMoveEnd: { delta in
                                                    let minutes = Int(delta / hourHeight * 60)
                                                    moveTask(task, offsetMinutes: minutes)
                                                }
                                            )
                                            .frame(width: columnWidth - 2)
                                            .offset(x: xOffset)
                                        }
                                    }
                                    
                                    // Drag preview for this day
                                    if isWeekDragging, let dragDay = weekDragDay, Calendar.current.isDate(day, inSameDayAs: dragDay) {
                                        weekDragPreview
                                    }
                                    
                                    // Current time line
                                    if Calendar.current.isDateInToday(day) {
                                        currentTimeLine
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .background(
                                    Calendar.current.isDateInToday(day)
                                        ? Color.accentColor.opacity(0.03)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 10)
                                        .onChanged { value in
                                            isWeekDragging = true
                                            weekDragDay = day
                                            weekDragStartY = value.startLocation.y
                                            weekDragCurrentY = value.location.y
                                        }
                                        .onEnded { _ in
                                            createTaskFromWeekDrag(day: day)
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    selectedDate = day
                                    dragStartTime = nil
                                    dragEndTime = nil
                                    showAddTask = true
                                }
                                
                                if day != weekDays.last {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 1)
                                }
                            }
                        }
                    }
                }
            }
    }
    
    private var weekDragPreview: some View {
        let top = min(weekDragStartY, weekDragCurrentY)
        let height = abs(weekDragCurrentY - weekDragStartY)
        let startHour = Int(top / hourHeight)
        let endHour = Int((top + height) / hourHeight) + 1
        
        return VStack(spacing: 2) {
            Text("New Task")
                .font(.system(size: 10, weight: .medium))
            Text("\(formatHour(startHour))")
                .font(.system(size: 9))
        }
        .foregroundColor(.accentColor)
        .frame(maxWidth: .infinity)
        .frame(height: max(30, height))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
        )
        .padding(.horizontal, 2)
        .offset(y: top)
    }
    
    private func createTaskFromWeekDrag(day: Date) {
        let startHour = Int(min(weekDragStartY, weekDragCurrentY) / hourHeight)
        let endHour = Int(max(weekDragStartY, weekDragCurrentY) / hourHeight) + 1
        
        let calendar = Calendar.current
        var startComps = calendar.dateComponents([.year, .month, .day], from: day)
        startComps.hour = max(0, min(23, startHour))
        startComps.minute = 0
        
        var endComps = calendar.dateComponents([.year, .month, .day], from: day)
        endComps.hour = max(1, min(24, endHour))
        endComps.minute = 0
        
        selectedDate = day
        dragStartTime = calendar.date(from: startComps)
        dragEndTime = calendar.date(from: endComps)
        
        isWeekDragging = false
        weekDragDay = nil
        showAddTask = true
    }
    
    private var timeColumn: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(formatHour(hour))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 60, height: hourHeight, alignment: .topTrailing)
                        .padding(.trailing, 8)
                }
            }
        }
        .frame(width: 70)
    }
    
    private var hourGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                ZStack(alignment: .top) {
                    // Main hour line (solid)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                    
                    // 15-minute line (dotted/light)
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .offset(y: hourHeight * 0.25)
                    
                    // 30-minute line (medium)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .offset(y: hourHeight * 0.5)
                    
                    // 45-minute line (dotted/light)
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .offset(y: hourHeight * 0.75)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }
    
    private var currentTimeLine: some View {
        var ukCalendar = Calendar(identifier: .gregorian)
        ukCalendar.timeZone = TimeZone(identifier: "Europe/London")!
        let hour = ukCalendar.component(.hour, from: Date())
        let minute = ukCalendar.component(.minute, from: Date())
        let offset = CGFloat(hour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .offset(y: offset - 5)
    }
    
    private var createTaskGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                isDragging = true
                dragStartY = value.startLocation.y
                dragCurrentY = value.location.y
            }
            .onEnded { _ in
                // Snap to 15-minute intervals
                let quarterHeight = hourHeight / 4  // 15 minutes
                
                let startY = min(dragStartY, dragCurrentY)
                let endY = max(dragStartY, dragCurrentY)
                
                // Calculate start time (snap to nearest 15 min)
                let startQuarters = Int(startY / quarterHeight)
                let startHour = startQuarters / 4
                let startMinute = (startQuarters % 4) * 15
                
                // Calculate end time (snap to nearest 15 min, minimum 15 min duration)
                let endQuarters = max(startQuarters + 1, Int(endY / quarterHeight) + 1)
                let endHour = endQuarters / 4
                let endMinute = (endQuarters % 4) * 15
                
                let calendar = Calendar.current
                var startComps = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                startComps.hour = max(0, min(23, startHour))
                startComps.minute = startMinute
                
                var endComps = calendar.dateComponents([.year, .month, .day], from: selectedDate)
                endComps.hour = max(0, min(24, endHour))
                endComps.minute = endMinute
                
                // Handle end time going to next day
                if endHour >= 24 {
                    endComps.hour = 23
                    endComps.minute = 59
                }
                
                dragStartTime = calendar.date(from: startComps)
                dragEndTime = calendar.date(from: endComps)
                
                isDragging = false
                showAddTask = true
            }
    }
    
    private var dragPreview: some View {
        let top = min(dragStartY, dragCurrentY)
        let height = abs(dragCurrentY - dragStartY)
        
        // Snap to 15-minute intervals for preview
        let quarterHeight = hourHeight / 4
        let startQuarters = Int(top / quarterHeight)
        let startHour = startQuarters / 4
        let startMinute = (startQuarters % 4) * 15
        
        let endQuarters = max(startQuarters + 1, Int((top + height) / quarterHeight) + 1)
        let endHour = endQuarters / 4
        let endMinute = (endQuarters % 4) * 15
        
        // Snap the preview box to 15-minute grid
        let snappedTop = CGFloat(startQuarters) * quarterHeight
        let snappedHeight = CGFloat(endQuarters - startQuarters) * quarterHeight
        
        // Calculate duration
        let totalMinutes = (endQuarters - startQuarters) * 15
        let durationText = totalMinutes >= 60 
            ? "\(totalMinutes / 60)h \(totalMinutes % 60 > 0 ? "\(totalMinutes % 60)m" : "")"
            : "\(totalMinutes)m"
        
        return VStack(spacing: 4) {
            Text("New Task")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("\(formatHourMinute(startHour, startMinute)) - \(formatHourMinute(endHour, endMinute))")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor.opacity(0.9))
            Text(durationText)
                .font(.system(size: 10))
                .foregroundColor(.accentColor.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(quarterHeight, snappedHeight))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                )
        )
        .padding(.horizontal, 8)
        .offset(y: snappedTop)
        .animation(.spring(response: 0.15, dampingFraction: 0.8), value: snappedTop)
        .animation(.spring(response: 0.15, dampingFraction: 0.8), value: snappedHeight)
    }
    
    private func formatHourMinute(_ hour: Int, _ minute: Int) -> String {
        let h = hour % 24
        let period = h >= 12 ? "PM" : "AM"
        let displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        if minute == 0 {
            return "\(displayHour) \(period)"
        } else {
            return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
        }
    }
    
    // MARK: - Helpers
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func dayNumber(_ date: Date) -> Int {
        Calendar.current.component(.day, from: date)
    }
    
    private func navigatePrevious() {
        withAnimation {
            let unit: Calendar.Component = viewMode == .day ? .day : .weekOfYear
            selectedDate = Calendar.current.date(byAdding: unit, value: -1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func navigateNext() {
        withAnimation {
            let unit: Calendar.Component = viewMode == .day ? .day : .weekOfYear
            selectedDate = Calendar.current.date(byAdding: unit, value: 1, to: selectedDate) ?? selectedDate
        }
    }
    
    private func updateTaskDuration(_ task: TaskItem, offsetMinutes: Int) {
        guard let endTime = task.endTime, let startTime = task.startTime else { return }

        // Round to nearest 15 minutes
        var roundedMinutes = ((offsetMinutes + 7) / 15) * 15
        if roundedMinutes == 0 && abs(offsetMinutes) >= 5 {
            roundedMinutes = offsetMinutes > 0 ? 15 : -15
        }
        guard roundedMinutes != 0 else { return }

        let newEndTime = endTime.addingTimeInterval(Double(roundedMinutes * 60))
        let newDuration = newEndTime.timeIntervalSince(startTime)
        if newDuration < 900 { return }

        // Calculate new end hour/minute
        let totalEndMinutes = task.endHour * 60 + task.endMinute + roundedMinutes
        let newEndHour = (totalEndMinutes / 60) % 24
        let newEndMinute = totalEndMinutes % 60

        // Mark task as being edited to prevent auto-refresh overwrite
        taskManager.beginLocalEdit(taskId: task.id)

        // Update local state IMMEDIATELY for instant feedback
        taskManager.updateTaskEndTimeLocally(taskId: task.id, newEndHour: newEndHour, newEndMinute: newEndMinute)

        // Then update database in background - create time strings
        let endTimeStr = String(format: "%02d:%02d:00", newEndHour, newEndMinute)
        Task {
            await performDatabaseUpdateWithStrings(task: task, newEndTimeStr: endTimeStr)
            // Clear the edit flag after successful update
            await MainActor.run {
                taskManager.endLocalEdit(taskId: task.id)
            }
        }
    }
    
    private func moveTask(_ task: TaskItem, offsetMinutes: Int) {
        let roundedMinutes = ((offsetMinutes + 7) / 15) * 15
        guard roundedMinutes != 0 else {
            return
        }
        
        // Calculate new times using raw hour/minute
        let totalStartMinutes = task.startHour * 60 + task.startMinute + roundedMinutes
        let totalEndMinutes = task.endHour * 60 + task.endMinute + roundedMinutes
        
        let newStartHour = (totalStartMinutes / 60) % 24
        let newStartMinute = ((totalStartMinutes % 60) + 60) % 60
        let newEndHour = (totalEndMinutes / 60) % 24
        let newEndMinute = ((totalEndMinutes % 60) + 60) % 60
        
        if newStartHour < 0 || newStartHour > 23 {
            return
        }
        
        NSLog("MOVE: Task '%@' originalId='%@' type='%@' moved by %d min", task.title, task.originalId, task.originalType, roundedMinutes)
        
        // Mark task as being edited to prevent auto-refresh overwrite
        taskManager.beginLocalEdit(taskId: task.id)
        
        // Update local state IMMEDIATELY
        taskManager.updateTaskTimesLocally(taskId: task.id, newStartHour: newStartHour, newStartMinute: newStartMinute, newEndHour: newEndHour, newEndMinute: newEndMinute)
        
        // Create time strings for database
        let startTimeStr = String(format: "%02d:%02d:00", newStartHour, newStartMinute)
        let endTimeStr = String(format: "%02d:%02d:00", newEndHour, newEndMinute)
        
        // Update database using callback-based approach
        updateTaskTimeInDatabaseWithStrings(
            taskId: task.originalId,
            taskType: task.originalType,
            newStartTimeStr: startTimeStr,
            newEndTimeStr: endTimeStr
        ) { [weak taskManager] success in
            DispatchQueue.main.async {
                taskManager?.endLocalEdit(taskId: task.id)
                if !success {
                    // Revert by refreshing from database
                    if let userId = AuthManager.shared.currentUser?.id {
                        Task {
                            await taskManager?.fetchTasks(for: userId)
                        }
                    }
                }
            }
        }
    }
    
    private func updateTaskTimeInDatabaseWithStrings(taskId: String, taskType: String, newStartTimeStr: String, newEndTimeStr: String, completion: @escaping (Bool) -> Void) {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let table: String
        var updateData: [String: Any] = [:]
        
        if taskType == "meeting" {
            table = "projects_meeting"
            // Parse times to calculate duration
            let startParts = newStartTimeStr.split(separator: ":").compactMap { Int($0) }
            let endParts = newEndTimeStr.split(separator: ":").compactMap { Int($0) }
            if startParts.count >= 2 && endParts.count >= 2 {
                let startMins = startParts[0] * 60 + startParts[1]
                let endMins = endParts[0] * 60 + endParts[1]
                let duration = endMins - startMins
                updateData = ["time": newStartTimeStr, "duration": max(15, duration)]
            }
        } else {
            table = "time_blocks"
            updateData = ["start_time": newStartTimeStr, "end_time": newEndTimeStr]
        }
        
        let urlString = "\(supabaseURL)/rest/v1/\(table)?id=eq.\(taskId)"
        
        guard let url = URL(string: urlString) else {
            NSLog("MOVE DB: Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            NSLog("MOVE DB: JSON error - %@", error.localizedDescription)
            completion(false)
            return
        }
        
        NSLog("MOVE DB: Sending PATCH to %@ with %@", table, updateData.description)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                NSLog("MOVE DB ERROR: %@", error.localizedDescription)
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                let responseStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                NSLog("MOVE DB: Status %d - %@", httpResponse.statusCode, responseStr.prefix(100).description)
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    NSLog("MOVE DB SUCCESS!")
                    completion(true)
                } else {
                    NSLog("MOVE DB FAILED: HTTP %d", httpResponse.statusCode)
                    completion(false)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    
    private func performDatabaseUpdateWithStrings(task: TaskItem, newEndTimeStr: String) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let table: String
        var updateData: [String: Any] = [:]
        
        if task.originalType == "meeting" {
            table = "projects_meeting"
            // Calculate new duration from start to end
            let endParts = newEndTimeStr.split(separator: ":").compactMap { Int($0) }
            if endParts.count >= 2 {
                let endMins = endParts[0] * 60 + endParts[1]
                let startMins = task.startHour * 60 + task.startMinute
                let newDuration = endMins - startMins
                updateData = ["duration": max(15, newDuration)]
            }
        } else {
            table = "time_blocks"
            updateData = ["end_time": newEndTimeStr]
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?id=eq.\(task.originalId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Database update failed: \(error)")
        }
    }
    
    private func performDatabaseMoveUpdate(task: TaskItem, newStartTime: Date, newEndTime: Date) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let table: String
        var updateData: [String: Any] = [:]
        
        if task.originalType == "meeting" {
            table = "meetings"
            let duration = Int(newEndTime.timeIntervalSince(newStartTime) / 60)
            updateData = ["time": timeFormatter.string(from: newStartTime), "duration": duration]
        } else {
            table = "time_blocks"
            updateData = ["start_time": timeFormatter.string(from: newStartTime), "end_time": timeFormatter.string(from: newEndTime)]
        }
        
        print("DEBUG MOVE: Updating \(table) id=\(task.originalId) with data: \(updateData)")
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?id=eq.\(task.originalId)") else {
            print("DEBUG MOVE: Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG MOVE: Response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG MOVE: Successfully updated task time")
                } else {
                    let responseStr = String(data: data, encoding: .utf8) ?? "no data"
                    print("DEBUG MOVE: Error response: \(responseStr)")
                }
            }
        } catch {
            print("DEBUG MOVE: Database move update failed: \(error)")
        }
    }
    
    private func formatTimeDebug(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func updateTaskEndTime(task: TaskItem, newEndTime: Date) async -> Bool {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let table: String
        var updateData: [String: Any] = [:]
        
        if task.originalType == "meeting" {
            table = "meetings"
            guard let startTime = task.startTime else { return false }
            let newDuration = Int(newEndTime.timeIntervalSince(startTime) / 60)
            updateData = ["duration": newDuration]
        } else {
            table = "time_blocks"
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            updateData = ["end_time": timeFormatter.string(from: newEndTime)]
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?id=eq.\(task.originalId)") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
            print("DEBUG RESIZE: Sending PATCH with body: \(updateData)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG RESIZE: Response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG RESIZE: Successfully updated \(table) with \(updateData)")
                    return true
                } else {
                    let responseStr = String(data: data, encoding: .utf8) ?? "no data"
                    print("DEBUG RESIZE: Error response (\(httpResponse.statusCode)): \(responseStr)")
                }
            }
        } catch {
            print("DEBUG RESIZE: Failed to update task: \(error)")
        }
        return false
    }
    
    private func duplicateTask(_ task: TaskItem) {
        guard let userId = authManager.currentUser?.id else { return }
        
        Task {
            await createDuplicateTask(task: task, userId: userId)
            await taskManager.fetchTasks(for: userId)
        }
    }
    
    private func createDuplicateTask(task: TaskItem, userId: Int) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // Duplicate to 1 hour later
        let newStart = (task.startTime ?? Date()).addingTimeInterval(3600)
        let newEnd = (task.endTime ?? Date()).addingTimeInterval(3600)
        
        // Get the type string based on task type
        let typeString: String
        switch task.type {
        case .timeBlock(let blockType):
            typeString = blockType.rawValue
        case .meeting:
            typeString = "meeting"
        case .todo:
            typeString = "todo"
        case .social:
            typeString = "social"
        }
        
        var blockData: [String: Any] = [
            "user_id": userId,
            "date": dateFormatter.string(from: task.date),
            "start_time": timeFormatter.string(from: newStart),
            "end_time": timeFormatter.string(from: newEnd),
            "title": "\(task.title) (Copy)",
            "type": typeString,
            "completed": false,
            "is_recurring": false
        ]
        
        // Include description if present
        if let desc = task.description, !desc.isEmpty {
            blockData["description"] = desc
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks") else {
            print("DEBUG DUPLICATE: Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: blockData)
            print("DEBUG DUPLICATE: Sending request with data: \(blockData)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG DUPLICATE: Response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG DUPLICATE: Successfully created duplicate task")
                } else {
                    let responseStr = String(data: data, encoding: .utf8) ?? "no data"
                    print("DEBUG DUPLICATE: Error response: \(responseStr)")
                }
            }
        } catch {
            print("DEBUG DUPLICATE: Failed to duplicate task: \(error)")
        }
    }
    
    private func taskPosition(_ task: TaskItem) -> (CGFloat, CGFloat) {
        guard let start = task.startTime, let end = task.endTime else {
            return (0, hourHeight)
        }
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: start)
        let startMin = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMin = calendar.component(.minute, from: end)
        
        let top = CGFloat(startHour) * hourHeight + CGFloat(startMin) / 60.0 * hourHeight
        let bottom = CGFloat(endHour) * hourHeight + CGFloat(endMin) / 60.0 * hourHeight
        
        return (top, bottom - top)
    }
    
    private var tasksForDay: [TaskItem] {
        tasksForDate(selectedDate)
    }
    
    private func tasksForDate(_ date: Date) -> [TaskItem] {
        taskManager.todayTasks.filter { task in
            let isDay = Calendar.current.isDate(task.date, inSameDayAs: date)
            let isNotTodo = task.type != .todo
            return isDay && isNotTodo
        }
    }
    
    // MARK: - Overlapping Task Layout
    
    // Represents a task with its layout position
    struct TaskLayout: Identifiable {
        let id: String
        let task: TaskItem
        let column: Int      // Which column (0, 1, 2, ...)
        let totalColumns: Int // Total columns in this overlap group
    }
    
    // Calculate layout for overlapping tasks
    private func calculateTaskLayouts(for tasks: [TaskItem]) -> [TaskLayout] {
        guard !tasks.isEmpty else { return [] }
        
        // Sort tasks by start time
        let sortedTasks = tasks.sorted { t1, t2 in
            guard let s1 = t1.startTime, let s2 = t2.startTime else { return false }
            return s1 < s2
        }
        
        var layouts: [TaskLayout] = []
        var columns: [[TaskItem]] = [] // Each column contains non-overlapping tasks
        
        for task in sortedTasks {
            guard let taskStart = task.startTime, let taskEnd = task.endTime else {
                // Task without times goes in first column
                layouts.append(TaskLayout(id: task.id, task: task, column: 0, totalColumns: 1))
                continue
            }
            
            // Find first column where this task doesn't overlap
            var assignedColumn = -1
            for (colIndex, column) in columns.enumerated() {
                let hasOverlap = column.contains { existingTask in
                    guard let existStart = existingTask.startTime, let existEnd = existingTask.endTime else { return false }
                    // Check if times overlap (with 1 minute buffer)
                    return taskStart < existEnd && taskEnd > existStart
                }
                
                if !hasOverlap {
                    assignedColumn = colIndex
                    break
                }
            }
            
            // If no column found, create new one
            if assignedColumn == -1 {
                assignedColumn = columns.count
                columns.append([])
            }
            
            columns[assignedColumn].append(task)
        }
        
        // Now calculate totalColumns for each overlapping group
        // For simplicity, we'll use the total number of columns
        let totalCols = max(1, columns.count)
        
        // Build layouts with column info
        for (colIndex, column) in columns.enumerated() {
            for task in column {
                // Calculate how many columns overlap with this specific task
                var overlappingCols = 1
                if let taskStart = task.startTime, let taskEnd = task.endTime {
                    for (otherColIndex, otherColumn) in columns.enumerated() {
                        if otherColIndex != colIndex {
                            let hasOverlap = otherColumn.contains { other in
                                guard let otherStart = other.startTime, let otherEnd = other.endTime else { return false }
                                return taskStart < otherEnd && taskEnd > otherStart
                            }
                            if hasOverlap {
                                overlappingCols += 1
                            }
                        }
                    }
                }
                
                layouts.append(TaskLayout(
                    id: task.id,
                    task: task,
                    column: colIndex,
                    totalColumns: overlappingCols
                ))
            }
        }
        
        return layouts
    }
    
    private var dateTitle: String {
        let formatter = DateFormatter()
        if viewMode == .week {
            formatter.dateFormat = "MMMM yyyy"
        } else {
            formatter.dateFormat = "MMMM d, yyyy"
        }
        return formatter.string(from: selectedDate)
    }
    
    private var dateSubtitle: String {
        if viewMode == .week {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            let start = weekDays.first ?? selectedDate
            let end = weekDays.last ?? selectedDate
            return "Week of \(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }
    
    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(h) \(period)"
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Resizable Task Block
struct ResizableTaskBlock: View {
    let task: TaskItem
    let hourHeight: CGFloat
    let isResizing: Bool
    let resizeDelta: CGFloat
    let onTap: () -> Void
    let onResizeStart: () -> Void
    let onResizeChange: (CGFloat) -> Void
    let onResizeEnd: (CGFloat) -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onComplete: () -> Void
    var onMoveEnd: ((CGFloat) -> Void)? = nil

    @EnvironmentObject var taskManager: TaskManager
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Completion animation states
    @State private var isCompletingAnimation = false
    @State private var slideOffset: CGFloat = 0
    @State private var completionOpacity: Double = 1
    @State private var checkmarkScale: CGFloat = 0
    @State private var showCompletionOverlay = false

    private var position: (CGFloat, CGFloat) {
        // Use raw hour/minute values directly
        let top = CGFloat(task.startHour) * hourHeight + CGFloat(task.startMinute) / 60.0 * hourHeight
        let bottom = CGFloat(task.endHour) * hourHeight + CGFloat(task.endMinute) / 60.0 * hourHeight
        return (top, max(30, bottom - top))
    }
    
    private func getPreviewTime(_ offset: CGFloat) -> String {
        let minutes = Int(offset / hourHeight * 60)
        let totalMinutes = task.startHour * 60 + task.startMinute + minutes
        let newHour = (totalMinutes / 60) % 24
        let newMinute = ((totalMinutes % 60) + 60) % 60
        return formatTime12Hour(hour: max(0, newHour), minute: newMinute)
    }
    
    private func getPreviewEndTime() -> String {
        let minutes = Int(resizeDelta / hourHeight * 60)
        let totalMinutes = task.endHour * 60 + task.endMinute + minutes
        let newHour = (totalMinutes / 60) % 24
        let newMinute = ((totalMinutes % 60) + 60) % 60
        return formatTime12Hour(hour: max(0, newHour), minute: newMinute)
    }
    
    private func formatTimeRange() -> String {
        let startStr = formatTime12Hour(hour: task.startHour, minute: task.startMinute)
        let endStr = formatTime12Hour(hour: task.endHour, minute: task.endMinute)
        return "\(startStr) - \(endStr)"
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
    
    private var durationMinutes: Int? {
        guard let start = task.startTime, let end = task.endTime else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }

    var body: some View {
        let (top, baseHeight) = position
        let height = max(40, baseHeight + (isResizing ? resizeDelta : 0))
        
        VStack(spacing: 0) {
            // Main content - drag to move
            HStack(spacing: 0) {
                Rectangle()
                    .fill(task.type.color)
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 3) {
                    if isDragging {
                        Text(getPreviewTime(dragOffset))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(task.type.color)
                    } else if isResizing {
                        Text("End: \(getPreviewEndTime())")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(task.type.color)
                    } else {
                        // Time display
                        Text(formatTimeRange())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(task.type.color)
                        
                        Text(task.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                            .lineLimit(height > 60 ? 2 : 1)
                    }
                    
                    // Duration badge for taller blocks
                    if height > 50 && !isDragging && !isResizing, let mins = durationMinutes {
                        Text("\(mins) min")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                
                Spacer()
                
                if !isDragging && !isResizing {
                    Button {
                        // Animate completion
                        if !task.isCompleted && !isCompletingAnimation {
                            isCompletingAnimation = true
                            showCompletionOverlay = true
                            
                            // Step 1: Checkmark pops in
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                                checkmarkScale = 1.3
                            }
                            
                            // Step 2: Checkmark settles
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                    checkmarkScale = 1.0
                                }
                            }
                            
                            // Step 3: Slide left
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    slideOffset = -120
                                }
                            }
                            
                            // Step 4: Fade out
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    completionOpacity = 0
                                }
                            }
                            
                            // Step 5: Call completion and reset
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                onComplete()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                slideOffset = 0
                                completionOpacity = 1
                                checkmarkScale = 0
                                showCompletionOverlay = false
                                isCompletingAnimation = false
                            }
                        } else {
                            onComplete()
                        }
                    } label: {
                        ZStack {
                            // Background circle for completion animation
                            if showCompletionOverlay || task.isCompleted {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 22, height: 22)
                                    .scaleEffect(showCompletionOverlay ? checkmarkScale : 1.0)
                            }
                            
                            // Empty circle
                            Circle()
                                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 2)
                                .frame(width: 22, height: 22)
                                .opacity(showCompletionOverlay || task.isCompleted ? 0 : 1)
                            
                            // Checkmark
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(showCompletionOverlay ? checkmarkScale : (task.isCompleted ? 1 : 0))
                                .opacity(showCompletionOverlay || task.isCompleted ? 1 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            isDragging = true
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let finalOffset = value.translation.height
                        // Call move handler
                        onMoveEnd?(finalOffset)
                        // Animate back smoothly (the actual position will update via task data)
                        withAnimation(.easeOut(duration: 0.2)) {
                            isDragging = false
                            dragOffset = 0
                        }
                    }
            )

            Spacer(minLength: 0)

            // Resize handle
            HStack(spacing: 2) {
                Spacer()
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(task.type.color.opacity(isResizing ? 1 : 0.5))
                        .frame(width: 10, height: 3)
                }
                Spacer()
            }
            .frame(height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        onResizeStart()
                        onResizeChange(value.translation.height)
                    }
                    .onEnded { value in
                        onResizeEnd(value.translation.height)
                    }
            )
            .onHover { h in
                if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
        }
        .frame(height: height)
        .background(
            ZStack {
                // Green completion background (reveals when sliding left)
                if showCompletionOverlay {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Done!")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.leading, 12)
                            ,
                            alignment: .leading
                        )
                }
                
                // Normal background
                RoundedRectangle(cornerRadius: 6)
                    .fill(task.type.color.opacity(task.isCompleted ? 0.1 : 0.15))
                    .offset(x: slideOffset)
                    .opacity(completionOpacity)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(task.type.color.opacity(isDragging || isResizing ? 1 : 0.4), lineWidth: isDragging || isResizing ? 2 : 1)
                .offset(x: slideOffset)
                .opacity(completionOpacity)
        )
        .padding(.horizontal, 8)
        .offset(y: top + dragOffset)
        .offset(x: slideOffset)
        .opacity(completionOpacity)
        .onTapGesture { onTap() }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button { onDuplicate() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Divider()
            Button { onComplete() } label: { Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: task.isCompleted ? "circle" : "checkmark.circle") }
        }
        .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
    }
}

// MARK: - Week Task Block with Resize
struct WeekTaskBlock: View {
    let task: TaskItem
    let hourHeight: CGFloat
    let onTap: () -> Void
    let onResizeEnd: (CGFloat) -> Void
    var onMoveEnd: ((CGFloat) -> Void)? = nil

    @State private var isResizing = false
    @State private var resizeDelta: CGFloat = 0
    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0

    private var position: (CGFloat, CGFloat) {
        // Use raw hour/minute values directly
        let top = CGFloat(task.startHour) * hourHeight + CGFloat(task.startMinute) / 60.0 * hourHeight
        let bottom = CGFloat(task.endHour) * hourHeight + CGFloat(task.endMinute) / 60.0 * hourHeight
        return (top, max(20, bottom - top))
    }
    
    private func getPreviewTime() -> String {
        let minutes = Int(dragOffset / hourHeight * 60)
        let totalMinutes = task.startHour * 60 + task.startMinute + minutes
        let newHour = (totalMinutes / 60) % 24
        let newMinute = ((totalMinutes % 60) + 60) % 60
        return formatTime12Hour(hour: max(0, newHour), minute: newMinute)
    }
    
    private func getPreviewEndTime() -> String {
        let minutes = Int(resizeDelta / hourHeight * 60)
        let totalMinutes = task.endHour * 60 + task.endMinute + minutes
        let newHour = (totalMinutes / 60) % 24
        let newMinute = ((totalMinutes % 60) + 60) % 60
        return formatTime12Hour(hour: max(0, newHour), minute: newMinute)
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }

    var body: some View {
        let (top, baseHeight) = position
        let height = max(22, baseHeight + (isResizing ? resizeDelta : 0))

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(task.type.color)
                    .frame(width: 3)

                if isDragging {
                    Text(getPreviewTime())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(task.type.color)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                } else if isResizing {
                    Text(getPreviewEndTime())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(task.type.color)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title)
                            .font(.system(size: 9))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .lineLimit(1)
                        // Show time and duration in week view
                        if height > 30 {
                            HStack(spacing: 4) {
                                Text(task.timeText)
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                                if let start = task.startTime, let end = task.endTime {
                                    let mins = Int(end.timeIntervalSince(start) / 60)
                                    Text("• \(mins)m")
                                        .font(.system(size: 7))
                                        .foregroundColor(task.type.color)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 2)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        withAnimation(.interactiveSpring()) {
                            isDragging = true
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let finalOffset = value.translation.height
                        onMoveEnd?(finalOffset)
                        withAnimation(.easeOut(duration: 0.2)) {
                            isDragging = false
                            dragOffset = 0
                        }
                    }
            )

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Capsule()
                    .fill(task.type.color.opacity(isResizing ? 1 : 0.5))
                    .frame(width: 14, height: 3)
                Spacer()
            }
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isResizing = true
                        resizeDelta = value.translation.height
                    }
                    .onEnded { value in
                        onResizeEnd(value.translation.height)
                        isResizing = false
                        resizeDelta = 0
                    }
            )
            .onHover { h in
                if h { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(task.type.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(task.type.color.opacity(isDragging || isResizing ? 1 : 0.4), lineWidth: isDragging || isResizing ? 2 : 1)
        )
        .padding(.horizontal, 1)
        .offset(y: top + dragOffset)
        .onTapGesture { onTap() }
    }
}

// MARK: - Task Popup View
struct TaskPopupView: View {
    let task: TaskItem
    let onEdit: () -> Void
    let onClose: () -> Void
    let onDuplicate: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(task.type.color)
                        .frame(width: 12, height: 12)
                    Text(task.type.displayName)
                        .font(.caption)
                        .foregroundColor(task.type.color)
                }
                
                Spacer()
                
                if task.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Button {
                    dismiss()
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(task.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .strikethrough(task.isCompleted)
                    
                    // Time & Date
                    VStack(spacing: 12) {
                        infoRow(icon: "clock", title: "Time", value: task.timeText)
                        infoRow(icon: "calendar", title: "Date", value: formattedDate(task.date))
                    }
                    
                    // Description
                    if let desc = task.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            Text(desc)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Meeting link
                    if let link = task.meetingLink, !link.isEmpty {
                        Button {
                            if let url = URL(string: link) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "video.fill")
                                Text("Join Meeting")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    dismiss()
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                
                Button {
                    dismiss()
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)
                
                // Delete button
                Button {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Spacer()
                
                Button {
                    Task {
                        await taskManager.toggleComplete(task: task)
                        dismiss()
                    }
                } label: {
                    Label(task.isCompleted ? "Undo" : "Complete", systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(task.isCompleted ? .gray : .green)
            }
            .padding()
            .background(Color(nsColor: NSColor.controlBackgroundColor))
        }
        .frame(width: 420, height: 480)
        .alert("Delete Task", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("Are you sure you want to delete '\(task.title)'? This cannot be undone.")
        }
    }
    
    private func deleteTask() {
        isDeleting = true
        Task {
            await performDelete()
            if let userId = authManager.currentUser?.id {
                await taskManager.fetchTasks(for: userId)
            }
            dismiss()
            onClose()
        }
    }
    
    private func performDelete() async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let table = task.originalType == "meeting" ? "meetings" : "time_blocks"
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(table)?id=eq.\(task.originalId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Delete response: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to delete task: \(error)")
        }
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Quick Add Task Popup
struct QuickAddTaskPopup: View {
    let date: Date
    let startTime: Date?
    let endTime: Date?
    var editTask: TaskItem? = nil
    
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: BlockType = .personal
    @State private var taskDate: Date
    @State private var taskStartTime: Date
    @State private var taskEndTime: Date
    @State private var isAllDay = false
    @State private var isSaving = false
    
    init(date: Date, startTime: Date?, endTime: Date?, editTask: TaskItem? = nil) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.editTask = editTask
        
        let now = Date()
        let calendar = Calendar.current
        let defaultStart = startTime ?? calendar.date(bySettingHour: calendar.component(.hour, from: now), minute: 0, second: 0, of: date) ?? now
        let defaultEnd = endTime ?? defaultStart.addingTimeInterval(3600)
        
        _taskDate = State(initialValue: date)
        _taskStartTime = State(initialValue: defaultStart)
        _taskEndTime = State(initialValue: defaultEnd)
        
        if let task = editTask {
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.description ?? "")
            _taskStartTime = State(initialValue: task.startTime ?? defaultStart)
            _taskEndTime = State(initialValue: task.endTime ?? defaultEnd)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(editTask == nil ? "New Task" : "Edit Task")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Task title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Optional description", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    
                    // Type selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(BlockType.allCases, id: \.self) { type in
                                typeButton(type)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Date & Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date & Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Date")
                                .frame(width: 80, alignment: .leading)
                            DatePicker("", selection: $taskDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        Toggle("All Day", isOn: $isAllDay)
                        
                        if !isAllDay {
                            HStack {
                                Text("Start")
                                    .frame(width: 80, alignment: .leading)
                                DatePicker("", selection: $taskStartTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                
                                Spacer()
                                
                                Text("End")
                                    .frame(width: 40, alignment: .leading)
                                DatePicker("", selection: $taskEndTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            
                            // Duration display
                            HStack {
                                Spacer()
                                Text("Duration: \(durationText)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    saveTask()
                } label: {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(editTask == nil ? "Add Task" : "Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || isSaving)
            }
            .padding()
            .background(Color(nsColor: NSColor.controlBackgroundColor))
        }
        .frame(width: 420, height: 550)
    }
    
    private func typeButton(_ type: BlockType) -> some View {
        Button {
            selectedType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                Text(type.rawValue.capitalized)
                    .font(.system(size: 10))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedType == type ? type.color.opacity(0.2) : Color.secondary.opacity(0.1))
            .foregroundColor(selectedType == type ? type.color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selectedType == type ? type.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var durationText: String {
        let mins = Int(taskEndTime.timeIntervalSince(taskStartTime) / 60)
        if mins < 0 { return "Invalid" }
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }
    
    private func saveTask() {
        guard let userId = authManager.currentUser?.id else { 
            print("DEBUG: No user ID found")
            return 
        }
        print("DEBUG: Starting save for user \(userId)")
        isSaving = true
        
        Task {
            await createOrUpdateTask(userId: userId)
            // Wait a bit for the database to process
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            await taskManager.fetchTasks(for: userId)
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func createOrUpdateTask(userId: Int) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        // Handle todo type separately - save to personal_todos table
        if selectedType == .todo {
            let todoData: [String: Any] = [
                "user_id": userId,
                "title": title,
                "description": description.isEmpty ? NSNull() : description,
                "due_date": dateFormatter.string(from: taskDate),
                "completed": false
            ]
            
            guard let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos") else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: todoData)
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: Todo save status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode >= 400 {
                        print("DEBUG: Error: \(String(data: data, encoding: .utf8) ?? "")")
                    }
                }
            } catch {
                print("Failed to save todo: \(error)")
            }
            return
        }
        
        // For time blocks (non-todo types)
        let typeString = selectedType.rawValue
        
        // Combine taskDate with the time components from taskStartTime and taskEndTime
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: taskStartTime)
        let startMinute = calendar.component(.minute, from: taskStartTime)
        let endHour = calendar.component(.hour, from: taskEndTime)
        let endMinute = calendar.component(.minute, from: taskEndTime)
        
        let startTimeStr = String(format: "%02d:%02d:00", startHour, startMinute)
        let endTimeStr = String(format: "%02d:%02d:00", endHour, endMinute)
        let dateStr = dateFormatter.string(from: taskDate)
        
        print("DEBUG: Date: \(dateStr), Start: \(startTimeStr), End: \(endTimeStr)")
        
        var blockData: [String: Any] = [
            "user_id": userId,
            "date": dateStr,
            "start_time": startTimeStr,
            "end_time": endTimeStr,
            "title": title,
            "type": typeString,
            "completed": false,
            "is_recurring": false
        ]
        
        // Only add description if not empty
        if !description.isEmpty {
            blockData["description"] = description
        }
        
        print("DEBUG: Saving task with data: \(blockData)")
        
        let urlString: String
        let method: String
        
        if let task = editTask {
            urlString = "\(supabaseURL)/rest/v1/time_blocks?id=eq.\(task.originalId)"
            method = "PATCH"
            print("DEBUG: Editing task ID: \(task.originalId)")
        } else {
            urlString = "\(supabaseURL)/rest/v1/time_blocks"
            method = "POST"
            print("DEBUG: Creating new task")
        }
        
        guard let url = URL(string: urlString) else { 
            print("DEBUG: Invalid URL: \(urlString)")
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: blockData)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: Task save response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG: Task saved successfully")
                } else {
                    let responseStr = String(data: data, encoding: .utf8) ?? "no data"
                    print("DEBUG: Error saving task: \(responseStr)")
                }
            }
        } catch {
            print("DEBUG: Failed to save task: \(error)")
        }
    }
}

// MARK: - Full Meetings View
struct FullMeetingsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var currentMonth = Date()
    @State private var selectedDate = Date()
    @State private var selectedMeeting: TaskItem?
    @State private var showMeetingPopup = false
    @State private var showAddMeeting = false
    @State private var showDayMeetings = false
    
    private let weekDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    private var allMeetings: [TaskItem] {
        taskManager.todayTasks.filter { $0.type == .meeting }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    private var upcomingMeetings: [TaskItem] {
        allMeetings.filter { !$0.isCompleted && $0.date >= Calendar.current.startOfDay(for: Date()) }
    }
    
    private var pastMeetings: [TaskItem] {
        allMeetings.filter { $0.isCompleted || $0.date < Calendar.current.startOfDay(for: Date()) }
    }
    
    private func meetingsForDate(_ date: Date) -> [TaskItem] {
        allMeetings.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    private var meetingsThisMonth: Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentMonth)
        let year = calendar.component(.year, from: currentMonth)
        return allMeetings.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }.count
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Stats bar
                statsBar
                
                // Month Calendar View - fills remaining space
                monthCalendarView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .sheet(isPresented: $showMeetingPopup) {
            if let meeting = selectedMeeting {
                MeetingPopupView(meeting: meeting)
                    .environmentObject(taskManager)
                    .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showAddMeeting) {
            AddMeetingSheet(date: selectedDate, startTime: nil, endTime: nil)
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showDayMeetings) {
            dayMeetingsSheet
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.purple)
                        Text("Meeting Schedule")
                            .font(.system(size: 28, weight: .bold))
                    }
                    
                    Text("Schedule and manage team meetings across all projects")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        showAddMeeting = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Schedule Meeting")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 16) {
            statCard(title: "Total Meetings", value: allMeetings.count, icon: "calendar.badge.clock", color: .purple)
            statCard(title: "Upcoming", value: upcomingMeetings.count, icon: "arrow.right.circle", color: .blue)
            statCard(title: "Completed", value: pastMeetings.count, icon: "checkmark.circle", color: .green)
            statCard(title: "This Month", value: meetingsThisMonth, icon: "calendar", color: .orange)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)], startPoint: .top, endPoint: .bottom)
        )
    }
    
    private func statCard(title: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Month Calendar View
    private var monthCalendarView: some View {
        VStack(spacing: 0) {
            // Month Navigation
            HStack {
                Button {
                    withAnimation {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Today") {
                    withAnimation {
                        currentMonth = Date()
                        selectedDate = Date()
                    }
                }
                .buttonStyle(.bordered)
                
                Text(monthYearString)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(minWidth: 200)
                
                Spacer()
                
                Button {
                    withAnimation {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            // Week day headers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                ForEach(daysInMonth, id: \.self) { date in
                    dayCell(date)
                }
            }
            .background(Color.gray.opacity(0.2))
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var daysInMonth: [Date] {
        let calendar = Calendar.current
        
        // Get first day of month
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        
        // Get range of days
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        
        // Get weekday of first day (0 = Sunday)
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        
        // Create array with padding for previous month
        var days: [Date] = []
        
        // Add days from previous month
        for i in (0..<firstWeekday).reversed() {
            if let date = calendar.date(byAdding: .day, value: -(i + 1), to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Add days of current month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }
        
        // Add days from next month to complete grid (6 rows = 42 cells)
        let remaining = 42 - days.count
        if let lastDay = days.last {
            for i in 1...remaining {
                if let date = calendar.date(byAdding: .day, value: i, to: lastDay) {
                    days.append(date)
                }
            }
        }
        
        return days
    }
    
    private func dayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isCurrentMonth = calendar.component(.month, from: date) == calendar.component(.month, from: currentMonth)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let dayMeetings = meetingsForDate(date)
        
        return VStack(spacing: 4) {
            // Day number
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isCurrentMonth ? (isToday ? .white : .primary) : .secondary.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(isToday ? Color.purple : Color.clear)
                .clipShape(Circle())
            
            // Meeting indicators
            if !dayMeetings.isEmpty {
                VStack(spacing: 2) {
                    ForEach(dayMeetings.prefix(3)) { meeting in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(meeting.isCompleted ? Color.green : Color.purple)
                                .frame(width: 6, height: 6)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(meeting.title)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                    .foregroundColor(meeting.isCompleted ? .secondary : .primary)
                                // Show time
                                Text(meeting.timeText)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(meeting.isCompleted ? Color.green.opacity(0.1) : Color.purple.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .onTapGesture {
                            selectedMeeting = meeting
                            showMeetingPopup = true
                        }
                    }
                    
                    if dayMeetings.count > 3 {
                        Button {
                            selectedDate = date
                            showDayMeetings = true
                        } label: {
                            Text("+\(dayMeetings.count - 3) more")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.purple.opacity(0.1) : (isCurrentMonth ? Color(nsColor: NSColor.controlBackgroundColor) : Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
        .onTapGesture(count: 2) {
            // Double-tap to create new meeting
            selectedDate = date
            showAddMeeting = true
        }
        .onTapGesture {
            // Single tap - ALWAYS show meeting list for that day
            selectedDate = date
            showDayMeetings = true
        }
    }
    
    // MARK: - Day Meetings List
    private var dayMeetingsSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayMeetingsTitle)
                        .font(.headline)
                    Text("\(meetingsForDate(selectedDate).count) meetings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showDayMeetings = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            // Meetings list
            let dayMeetings = meetingsForDate(selectedDate)
            
            if dayMeetings.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("No meetings scheduled")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Schedule a meeting for this day")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button {
                        showDayMeetings = false
                        showAddMeeting = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Schedule Meeting")
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(dayMeetings) { meeting in
                            dayMeetingCard(meeting)
                        }
                    }
                    .padding()
                }
                
                // Add meeting button at bottom
                Button {
                    showDayMeetings = false
                    showAddMeeting = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("Schedule New Meeting")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 400, height: 500)
    }
    
    private var dayMeetingsTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }
    
    private func dayMeetingCard(_ meeting: TaskItem) -> some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime12Hour(hour: meeting.startHour, minute: meeting.startMinute))
                    .font(.system(size: 12, weight: .semibold))
                Text(formatTime12Hour(hour: meeting.endHour, minute: meeting.endMinute))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 70)
            
            // Color bar
            Rectangle()
                .fill(meeting.isCompleted ? Color.green : Color.purple)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(meeting.isCompleted)
                
                // Time and Duration
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(meeting.timeText)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.purple)
                    
                    if let start = meeting.startTime, let end = meeting.endTime {
                        let mins = Int(end.timeIntervalSince(start) / 60)
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                            Text("\(mins) min")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.orange)
                    }
                }

                if let desc = meeting.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let link = meeting.meetingLink, !link.isEmpty {
                    Button {
                        if let url = URL(string: link) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Join Meeting", systemImage: "video.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.blue)
                }
            }
            
            Spacer()
            
            // Status
            Image(systemName: meeting.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(meeting.isCompleted ? .green : .secondary)
                .onTapGesture {
                    Task { await taskManager.toggleComplete(task: meeting) }
                }
        }
        .padding(12)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onTapGesture {
            selectedMeeting = meeting
            showMeetingPopup = true
            showDayMeetings = false
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No meetings scheduled")
                .font(.headline)
            
            Text("Click 'Schedule Meeting' to add your first meeting")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showAddMeeting = true
            } label: {
                Label("Schedule Meeting", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Week Meeting Block
struct WeekMeetingBlock: View {
    let meeting: TaskItem
    let hourHeight: CGFloat
    let onTap: () -> Void
    
    private var position: (CGFloat, CGFloat) {
        // Use raw hour/minute values directly
        let top = CGFloat(meeting.startHour) * hourHeight + CGFloat(meeting.startMinute) / 60.0 * hourHeight
        let bottom = CGFloat(meeting.endHour) * hourHeight + CGFloat(meeting.endMinute) / 60.0 * hourHeight
        
        return (top, max(30, bottom - top))
    }
    
    var body: some View {
        let (top, height) = position
        
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: 3)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(meeting.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(meeting.isCompleted ? .secondary : .primary)
                        .lineLimit(height > 40 ? 2 : 1)
                    
                    if height > 25 {
                        HStack(spacing: 4) {
                            Text(formatTime12Hour(hour: meeting.startHour, minute: meeting.startMinute))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            let durationMins = (meeting.endHour * 60 + meeting.endMinute) - (meeting.startHour * 60 + meeting.startMinute)
                            Text("• \(durationMins)m")
                                .font(.system(size: 7))
                                .foregroundColor(.purple)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                
                Spacer(minLength: 0)
                
                if meeting.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                        .padding(.trailing, 4)
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(height: max(20, height - 2))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.purple.opacity(meeting.isCompleted ? 0.1 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 2)
        .offset(y: top)
        .onTapGesture { onTap() }
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Meeting Popup View (Website-style)
struct MeetingPopupView: View {
    let meeting: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showMeetingNotes = false
    @State private var hasExistingNotes = false
    @State private var isCheckingNotes = true
    @State private var meetingAttendees: [String] = []
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient (like website)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Status badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(meeting.isCompleted ? Color.green : Color.purple)
                                .frame(width: 8, height: 8)
                            Text(meeting.isCompleted ? "Completed" : "Scheduled")
                                .font(.system(size: 10, weight: .bold))
                                .textCase(.uppercase)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(meeting.isCompleted ? Color.green.opacity(0.15) : Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                        
                        Text(meeting.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                LinearGradient(colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date/Time/Duration Cards (like website)
                    HStack(spacing: 12) {
                        infoCard(icon: "calendar", label: "Date", value: shortDate(meeting.date), color: .orange)
                        infoCard(icon: "clock", label: "Time", value: meeting.timeText, color: .orange)
                        if let start = meeting.startTime, let end = meeting.endTime {
                            let mins = Int(end.timeIntervalSince(start) / 60)
                            infoCard(icon: "sparkles", label: "Duration", value: "\(mins) min", color: .orange)
                        }
                    }
                    
                    // Meeting Link
                    if let link = meeting.meetingLink, !link.isEmpty {
                        Button {
                            if let url = URL(string: link) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 16))
                                Text("Join Meeting")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Description
                    if let desc = meeting.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DESCRIPTION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    Rectangle()
                                        .fill(Color.orange)
                                        .frame(width: 3)
                                        .clipShape(RoundedRectangle(cornerRadius: 2)),
                                    alignment: .leading
                                )
                        }
                    }
                    
                    // Attendees (if available)
                    if !meetingAttendees.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ATTENDEES (\(meetingAttendees.count))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            
                            FlowLayoutContent(spacing: 8) {
                                ForEach(meetingAttendees, id: \.self) { attendee in
                                    HStack(spacing: 8) {
                                        Text(String(attendee.prefix(1)).uppercased())
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(
                                                LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            )
                                            .clipShape(Circle())
                                        
                                        Text(attendee)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Meeting Notes Button
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MEETING NOTES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        
                        Button {
                            showMeetingNotes = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hasExistingNotes ? "View Meeting Notes" : "Create Meeting Notes")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(hasExistingNotes ? "View and edit discussion points, decisions, action items" : "Add discussion points, decisions, action items")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if isCheckingNotes {
                            HStack {
                                ProgressView().scaleEffect(0.7)
                                Text("Checking for notes...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            // Actions Footer
            HStack(spacing: 12) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Spacer()
                
                Button {
                    Task {
                        await taskManager.toggleComplete(task: meeting)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: meeting.isCompleted ? "arrow.uturn.backward" : "checkmark")
                        Text(meeting.isCompleted ? "Undo" : "Complete")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(meeting.isCompleted ? .gray : .green)
            }
            .padding(16)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
        }
        .frame(width: 520, height: 600)
        .alert("Delete Meeting", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteMeeting() }
        } message: {
            Text("Are you sure you want to delete '\(meeting.title)'?")
        }
        .sheet(isPresented: $showMeetingNotes) {
            FullMeetingNotesSheet(meeting: meeting)
                .environmentObject(taskManager)
        }
        .onAppear {
            checkForExistingNotes()
            loadAttendees()
        }
    }
    
    private func infoCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func checkForExistingNotes() {
        guard let meetingId = Int(meeting.originalId) else {
            isCheckingNotes = false
            return
        }
        
        Task {
            guard let url = URL(string: "\(supabaseURL)/rest/v1/meeting_notes?meeting_id=eq.\(meetingId)&select=id") else {
                await MainActor.run { isCheckingNotes = false }
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let results = try? JSONDecoder().decode([[String: Int]].self, from: data) {
                    await MainActor.run {
                        hasExistingNotes = !results.isEmpty
                        isCheckingNotes = false
                    }
                } else {
                    await MainActor.run { isCheckingNotes = false }
                }
            } catch {
                await MainActor.run { isCheckingNotes = false }
            }
        }
    }
    
    private func loadAttendees() {
        guard let meetingId = Int(meeting.originalId) else { return }
        
        Task {
            guard let url = URL(string: "\(supabaseURL)/rest/v1/meetings?id=eq.\(meetingId)&select=attendees_list") else { return }
            
            var request = URLRequest(url: url)
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                struct MeetingAttendees: Codable {
                    let attendees_list: [String]?
                }
                if let results = try? JSONDecoder().decode([MeetingAttendees].self, from: data),
                   let first = results.first,
                   let attendees = first.attendees_list {
                    await MainActor.run {
                        meetingAttendees = attendees
                    }
                }
            } catch {
                print("Failed to load attendees: \(error)")
            }
        }
    }
    
    private func deleteMeeting() {
        isDeleting = true
        Task {
            await performDelete()
            if let userId = authManager.currentUser?.id {
                await taskManager.fetchTasks(for: userId)
            }
            dismiss()
        }
    }
    
    private func performDelete() async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/meetings?id=eq.\(meeting.originalId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to delete meeting: \(error)")
        }
    }
}

// MARK: - Full Meeting Notes Sheet (uses the comprehensive meeting notes from FocusApp)
struct FullMeetingNotesSheet: View {
    let meeting: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        // Use the MenuBarMeetingSheet which has the full meeting notes system
        MenuBarMeetingSheet(meeting: meeting, onClose: { dismiss() })
            .environmentObject(taskManager)
    }
}

// MARK: - Flow Layout for Attendees (simpler version)
struct FlowLayoutContent<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Project for Meeting
struct ProjectOption: Identifiable {
    let id: Int
    let name: String
    let color: Color
}

// Project Member
struct ProjectMember: Identifiable, Codable {
    var id: Int { user_id }
    let user_id: Int
    let full_name: String?
    let email: String?
}

// MARK: - Add Meeting Sheet (Website-style)
struct AddMeetingSheet: View {
    let date: Date
    let startTime: Date?
    let endTime: Date?
    
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var meetingLink = ""
    @State private var meetingDate: Date
    @State private var meetingTime: Date
    @State private var duration: Int = 60
    @State private var selectedProject: Int = 0
    @State private var isRecurring: Bool = false
    @State private var attendees: [String] = []
    @State private var newAttendee = ""
    @State private var agendaItems: [String] = []
    @State private var newAgendaItem = ""
    @State private var reminderMinutes: Int = 15
    @State private var isSaving = false
    @State private var projects: [ProjectOption] = [ProjectOption(id: 0, name: "Select a project", color: .gray)]
    @State private var projectMembers: [ProjectMember] = []
    @State private var isLoadingProjects = true
    @State private var isLoadingMembers = false
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    init(date: Date, startTime: Date?, endTime: Date?) {
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        
        let now = Date()
        let calendar = Calendar.current
        let defaultStart = startTime ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? now
        
        _meetingDate = State(initialValue: date)
        _meetingTime = State(initialValue: defaultStart)
        
        if let start = startTime, let end = endTime {
            _duration = State(initialValue: Int(end.timeIntervalSince(start) / 60))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Premium Header with gradient
            ZStack {
                LinearGradient(
                    colors: [Color.orange.opacity(0.8), Color.purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 70)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule Meeting")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text(meetingDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }
            
            // Form Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // SECTION 1: Basic Info Card
                    formCard {
                        VStack(alignment: .leading, spacing: 16) {
                            // Title
                            formField(icon: "doc.text.fill", label: "Meeting Title", required: true) {
                                TextField("Enter meeting title...", text: $title)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                            }
                            
                            Divider().opacity(0.3)
                            
                            // Project Selector
                            formField(icon: "folder.fill", label: "Project", required: true) {
                                if isLoadingProjects {
                                    HStack(spacing: 8) {
                                        ProgressView().scaleEffect(0.7)
                                        Text("Loading...").font(.system(size: 13)).foregroundColor(.secondary)
                                    }
                                } else {
                                    Picker("", selection: $selectedProject) {
                                        ForEach(projects) { project in
                                            HStack(spacing: 8) {
                                                Circle().fill(project.color).frame(width: 8, height: 8)
                                                Text(project.name).font(.system(size: 13))
                                            }
                                            .tag(project.id)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            
                            Divider().opacity(0.3)
                            
                            // Description
                            formField(icon: "text.alignleft", label: "Description", required: false) {
                                TextEditor(text: $description)
                                    .font(.system(size: 13))
                                    .frame(height: 60)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                            }
                        }
                    }
                    
                    // SECTION 2: Date & Time Card
                    formCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 16) {
                                // Date
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 12))
                                        Text("Date")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    DatePicker("", selection: $meetingDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Time
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 12))
                                        Text("Time")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    DatePicker("", selection: $meetingTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Duration
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "timer")
                                            .foregroundColor(.green)
                                            .font(.system(size: 12))
                                        Text("Duration")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        TextField("60", value: $duration, format: .number)
                                            .textFieldStyle(.plain)
                                            .font(.system(size: 14, weight: .medium))
                                            .frame(width: 40)
                                            .multilineTextAlignment(.center)
                                            .padding(6)
                                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        Text("min")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            // Recurring toggle
                            HStack {
                                Image(systemName: isRecurring ? "repeat.circle.fill" : "repeat")
                                    .foregroundColor(isRecurring ? .purple : .secondary)
                                    .font(.system(size: 14))
                                Text("Recurring Meeting")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Toggle("", isOn: $isRecurring)
                                    .toggleStyle(.switch)
                                    .scaleEffect(0.8)
                            }
                            .padding(12)
                            .background(isRecurring ? Color.purple.opacity(0.1) : Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // SECTION 3: Attendees Card
                    formCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.purple)
                                Text("Attendees")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                if !attendees.isEmpty {
                                    Text("\(attendees.count) selected")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            if selectedProject == 0 {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.orange)
                                    Text("Select a project first to see team members")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                // Team members selection
                                if isLoadingMembers {
                                    HStack(spacing: 8) {
                                        ProgressView().scaleEffect(0.7)
                                        Text("Loading team...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                } else if !projectMembers.isEmpty {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                                        ForEach(projectMembers) { member in
                                            let memberName = member.full_name ?? member.email ?? "User \(member.user_id)"
                                            let isSelected = attendees.contains(memberName)
                                            
                                            Button {
                                                withAnimation(.spring(response: 0.3)) {
                                                    if isSelected {
                                                        attendees.removeAll { $0 == memberName }
                                                    } else {
                                                        attendees.append(memberName)
                                                    }
                                                }
                                            } label: {
                                                HStack(spacing: 8) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(isSelected ? Color.green : Color.purple.opacity(0.8))
                                                            .frame(width: 28, height: 28)
                                                        if isSelected {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(.white)
                                                        } else {
                                                            Text(String(memberName.prefix(1)).uppercased())
                                                                .font(.system(size: 12, weight: .bold))
                                                                .foregroundColor(.white)
                                                        }
                                                    }
                                                    Text(memberName)
                                                        .font(.system(size: 12))
                                                        .lineLimit(1)
                                                    Spacer(minLength: 0)
                                                }
                                                .padding(8)
                                                .background(isSelected ? Color.green.opacity(0.15) : Color(nsColor: NSColor.controlBackgroundColor))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .strokeBorder(isSelected ? Color.green : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                // Add custom attendee
                                HStack(spacing: 8) {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.secondary)
                                    TextField("Add external attendee...", text: $newAttendee)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13))
                                        .onSubmit { addAttendee() }
                                    if !newAttendee.isEmpty {
                                        Button { addAttendee() } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.system(size: 18))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(10)
                                .background(Color(nsColor: NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    // SECTION 4: Agenda Card
                    formCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "list.bullet.clipboard.fill")
                                    .foregroundColor(.blue)
                                Text("Meeting Agenda")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                if !agendaItems.isEmpty {
                                    Text("\(agendaItems.count) items")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Add agenda input
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                TextField("Add agenda item...", text: $newAgendaItem)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13))
                                    .onSubmit { addAgendaItem() }
                                if !newAgendaItem.isEmpty {
                                    Button { addAgendaItem() } label: {
                                        Text("Add")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(10)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            // Agenda list
                            if agendaItems.isEmpty {
                                HStack {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.yellow)
                                    Text("Add agenda items to keep your meeting focused")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.yellow.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                ForEach(Array(agendaItems.enumerated()), id: \.offset) { idx, item in
                                    HStack(spacing: 10) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                        Text(item)
                                            .font(.system(size: 13))
                                        Spacer()
                                        Button { agendaItems.remove(at: idx) } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 11))
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(10)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    // SECTION 5: Meeting Link & Reminder Card
                    formCard {
                        VStack(alignment: .leading, spacing: 16) {
                            // Meeting Link
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.green)
                                    Text("Meeting Link")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                        .foregroundColor(.secondary)
                                    TextField("https://zoom.us/j/... or meet.google.com/...", text: $meetingLink)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13))
                                }
                                .padding(10)
                                .background(Color(nsColor: NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            Divider().opacity(0.3)
                            
                            // Email Reminder
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.orange)
                                    Text("Email Reminder")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                
                                HStack {
                                    Picker("", selection: $reminderMinutes) {
                                        Label("No reminder", systemImage: "bell.slash").tag(0)
                                        Label("5 min before", systemImage: "bell").tag(5)
                                        Label("15 min before", systemImage: "bell").tag(15)
                                        Label("30 min before", systemImage: "bell").tag(30)
                                        Label("1 hour before", systemImage: "bell.badge").tag(60)
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            // Premium Footer Buttons
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 16) {
                    // Cancel Button
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.3)))
                    }
                    .buttonStyle(.plain)
                    
                    // Schedule Button
                    Button { saveMeeting() } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "calendar.badge.plus")
                                Text("Schedule Meeting")
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: title.isEmpty ? [Color.gray] : [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: Color.orange.opacity(title.isEmpty ? 0 : 0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(title.isEmpty || isSaving)
                }
                .padding(16)
                .background(Color(nsColor: NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 520, height: 780)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
        )
        .onAppear { fetchProjects() }
        .onChange(of: selectedProject) { newValue in
            if newValue > 0 {
                fetchProjectMembers(projectId: newValue)
            } else {
                projectMembers = []
            }
        }
    }
    
    private func fetchProjects() {
        guard let userId = authManager.currentUser?.id else {
            isLoadingProjects = false
            return
        }
        
        Task {
            // First get project IDs the user is a member of
            guard let membershipUrl = URL(string: "\(supabaseURL)/rest/v1/projects_project_members?user_id=eq.\(userId)&select=project_id") else {
                await MainActor.run { isLoadingProjects = false }
                return
            }
            
            var membershipRequest = URLRequest(url: membershipUrl)
            membershipRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            membershipRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let (membershipData, _) = try await URLSession.shared.data(for: membershipRequest)
                
                struct MembershipData: Codable {
                    let project_id: Int
                }
                
                guard let memberships = try? JSONDecoder().decode([MembershipData].self, from: membershipData),
                      !memberships.isEmpty else {
                    print("No project memberships found for user \(userId)")
                    await MainActor.run { isLoadingProjects = false }
                    return
                }
                
                let projectIds = memberships.map { $0.project_id }
                let idsString = projectIds.map { String($0) }.joined(separator: ",")
                
                // Now fetch the actual projects
                guard let projectsUrl = URL(string: "\(supabaseURL)/rest/v1/projects_project?id=in.(\(idsString))&select=id,name") else {
                    await MainActor.run { isLoadingProjects = false }
                    return
                }
                
                var projectsRequest = URLRequest(url: projectsUrl)
                projectsRequest.setValue(supabaseKey, forHTTPHeaderField: "apikey")
                projectsRequest.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
                
                let (projectsData, _) = try await URLSession.shared.data(for: projectsRequest)
                
                struct ProjectData: Codable {
                    let id: Int
                    let name: String
                }
                
                if let results = try? JSONDecoder().decode([ProjectData].self, from: projectsData) {
                    print("Decoded \(results.count) projects for user")
                    await MainActor.run {
                        var loadedProjects = [ProjectOption(id: 0, name: "Select a project", color: .gray)]
                        let colors: [Color] = [.blue, .green, .purple, .orange, .red, .pink, .indigo, .teal]
                        for (index, proj) in results.enumerated() {
                            loadedProjects.append(ProjectOption(id: proj.id, name: proj.name, color: colors[index % colors.count]))
                        }
                        projects = loadedProjects
                        isLoadingProjects = false
                    }
                } else {
                    print("Failed to decode projects")
                    await MainActor.run { isLoadingProjects = false }
                }
            } catch {
                print("Failed to fetch projects: \(error)")
                await MainActor.run { isLoadingProjects = false }
            }
        }
    }
    
    private func fetchProjectMembers(projectId: Int) {
        isLoadingMembers = true
        projectMembers = []
        
        Task {
            // Fetch project members from projects_project_members table joined with auth_user
            guard let url = URL(string: "\(supabaseURL)/rest/v1/projects_project_members?project_id=eq.\(projectId)&select=user_id,auth_user(id,name,email)") else {
                await MainActor.run { isLoadingMembers = false }
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                print("Project members data: \(String(data: data, encoding: .utf8) ?? "nil")")
                
                struct MemberData: Codable {
                    let user_id: Int
                    let auth_user: UserData?
                }
                struct UserData: Codable {
                    let id: Int
                    let name: String?
                    let email: String?
                }
                
                if let results = try? JSONDecoder().decode([MemberData].self, from: data) {
                    await MainActor.run {
                        projectMembers = results.compactMap { member in
                            if let user = member.auth_user {
                                return ProjectMember(user_id: user.id, full_name: user.name, email: user.email)
                            }
                            return nil
                        }
                        print("Loaded \(projectMembers.count) project members")
                        isLoadingMembers = false
                    }
                } else {
                    print("Failed to decode project members")
                    await MainActor.run { isLoadingMembers = false }
                }
            } catch {
                print("Failed to fetch project members: \(error)")
                await MainActor.run { isLoadingMembers = false }
            }
        }
    }
    
    private func fieldSection<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            content()
        }
    }
    
    // Premium card container
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
    
    // Form field with icon
    private func formField<Content: View>(icon: String, label: String, required: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                if required {
                    Text("*")
                        .foregroundColor(.orange)
                        .font(.system(size: 11, weight: .bold))
                }
            }
            content()
        }
    }
    
    private func addAttendee() {
        let trimmed = newAttendee.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !attendees.contains(trimmed) {
            attendees.append(trimmed)
            newAttendee = ""
        }
    }
    
    private func addAgendaItem() {
        let trimmed = newAgendaItem.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            agendaItems.append(trimmed)
            newAgendaItem = ""
        }
    }
    
    private func saveMeeting() {
        guard let userId = authManager.currentUser?.id else { return }
        isSaving = true
        
        Task {
            await createMeeting(userId: userId)
            try? await Task.sleep(nanoseconds: 500_000_000)
            await taskManager.fetchTasks(for: userId)
            await MainActor.run { dismiss() }
        }
    }
    
    private func createMeeting(userId: Int) async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: meetingTime)
        let minute = calendar.component(.minute, from: meetingTime)
        let startTimeStr = String(format: "%02d:%02d:00", hour, minute)
        
        // Calculate end time based on duration
        let endMinutes = hour * 60 + minute + duration
        let endHour = (endMinutes / 60) % 24
        let endMin = endMinutes % 60
        let endTimeStr = String(format: "%02d:%02d:00", endHour, endMin)
        
        var meetingData: [String: Any] = [
            "user_id": userId,
            "title": title,
            "meeting_date": dateFormatter.string(from: meetingDate),
            "start_time": startTimeStr,
            "end_time": endTimeStr,
            "duration": duration,
            "completed": false
        ]
        
        if !description.isEmpty { meetingData["description"] = description }
        if !meetingLink.isEmpty { meetingData["meeting_link"] = meetingLink }
        if !attendees.isEmpty { meetingData["attendees_list"] = attendees }
        if !agendaItems.isEmpty { meetingData["agenda_items"] = agendaItems }
        if selectedProject > 0 {
            meetingData["project_id"] = selectedProject
            meetingData["project_name"] = projects.first { $0.id == selectedProject }?.name ?? ""
        }
        if reminderMinutes > 0 { meetingData["reminder_time"] = reminderMinutes }
        meetingData["is_recurring"] = isRecurring
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/meetings") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: meetingData)
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to save meeting: \(error)")
        }
    }
}

// MARK: - Full Rule Book View
struct FullRuleBookView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var ruleManager = RuleManager.shared
    @State private var selectedPeriod: Int = 1
    @State private var hoveredPeriod: Int? = nil
    
    private var filteredRules: [Rule] {
        switch selectedPeriod {
        case 1: return ruleManager.dailyRules
        case 2: return ruleManager.weeklyRules
        case 3: return ruleManager.monthlyRules
        case 4: return ruleManager.yearlyRules
        default: return ruleManager.dailyRules
        }
    }
    
    private var periodName: String {
        switch selectedPeriod {
        case 1: return "Daily"
        case 2: return "Weekly"
        case 3: return "Monthly"
        case 4: return "Yearly"
        default: return "Daily"
        }
    }
    
    private var periodColor: Color {
        switch selectedPeriod {
        case 1: return .orange
        case 2: return .blue
        case 3: return .purple
        case 4: return .pink
        default: return .orange
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left: Rules Section (60%)
                rulesSection
                    .frame(width: geometry.size.width * 0.6)
                
                // Right: Report Section (40%)
                reportSection
                    .frame(width: geometry.size.width * 0.4)
            }
        }
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
    
    // MARK: - Rules Section
    private var rulesSection: some View {
        VStack(spacing: 0) {
            // Clean Header
            VStack(spacing: 32) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rule Book")
                            .font(.system(size: 34, weight: .bold))
                        Text("Track your habits and build consistency")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        openAddRuleWindow()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("New Rule")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Period Selector - Large Cards
                HStack(spacing: 16) {
                    periodCard("Daily", icon: "sun.max.fill", color: .orange, period: 1)
                    periodCard("Weekly", icon: "calendar.badge.clock", color: .blue, period: 2)
                    periodCard("Monthly", icon: "calendar", color: .purple, period: 3)
                    periodCard("Yearly", icon: "sparkles", color: .pink, period: 4)
                }
            }
            .padding(40)
            .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3))
            
            // Rules List
            if filteredRules.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredRules) { rule in
                            LargeRuleRow(rule: rule, ruleManager: ruleManager, color: periodColor)
                        }
                    }
                    .padding(40)
                }
            }
        }
    }
    
    private func periodCard(_ title: String, icon: String, color: Color, period: Int) -> some View {
        let isSelected = selectedPeriod == period
        let isHovered = hoveredPeriod == period
        let rules = rulesForPeriod(period)
        let completed = rules.filter { $0.isCompletedForPeriod }.count
        let percentage = rules.isEmpty ? 0 : Int(Double(completed) / Double(rules.count) * 100)
        
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selectedPeriod = period
            }
        } label: {
            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(isSelected ? 0.2 : 0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                // Progress
                VStack(spacing: 8) {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.15), lineWidth: 4)
                            .frame(width: 44, height: 44)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(percentage) / 100)
                            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(percentage)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(color)
                    }
                    
                    Text("\(completed)/\(rules.count)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? color.opacity(0.08) : Color(nsColor: NSColor.controlBackgroundColor))
                    .shadow(color: isSelected ? color.opacity(0.2) : .clear, radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? color.opacity(0.4) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                hoveredPeriod = hovering ? period : nil
            }
        }
    }
    
    private func rulesForPeriod(_ period: Int) -> [Rule] {
        switch period {
        case 1: return ruleManager.dailyRules
        case 2: return ruleManager.weeklyRules
        case 3: return ruleManager.monthlyRules
        case 4: return ruleManager.yearlyRules
        default: return ruleManager.dailyRules
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(periodColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(periodColor.opacity(0.5))
            }
            
            VStack(spacing: 12) {
                Text("No \(periodName) Rules")
                    .font(.system(size: 24, weight: .semibold))
                
                Text("Create your first \(periodName.lowercased()) rule to start tracking")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                openAddRuleWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Create Rule")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 12).fill(periodColor))
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Report Section
    private var reportSection: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Report Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Progress Report")
                        .font(.system(size: 28, weight: .bold))
                    Text("Your habit tracking overview")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Large Progress Circle
                progressCircleCard
                
                // Stats Grid
                statsGrid
                
                // Period Breakdown
                periodBreakdown
                
                // Streak Card
                streakCard
            }
            .padding(40)
        }
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private var progressCircleCard: some View {
        let total = ruleManager.rules.count
        let completed = ruleManager.rules.filter { $0.isCompletedForPeriod }.count
        let percentage = total > 0 ? Double(completed) / Double(total) * 100 : 0
        
        return VStack(spacing: 24) {
            ZStack {
                // Background Circle
                Circle()
                    .stroke(Color.green.opacity(0.1), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Progress Circle
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(
                        LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percentage)
                
                // Center Content
                VStack(spacing: 8) {
                    Text("\(Int(percentage))%")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("\(completed) of \(total)")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            
            // Status Message
            Text(percentage == 100 ? "Perfect! All rules completed" : percentage >= 75 ? "Almost there! Keep going" : percentage >= 50 ? "Halfway done! Nice progress" : "Let's build some habits!")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(percentage >= 50 ? .green : .orange)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill((percentage >= 50 ? Color.green : Color.orange).opacity(0.1))
                )
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
        )
    }
    
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            statCard("Points", value: "\(ruleManager.userStats.totalPoints)", icon: "star.fill", color: .yellow)
            statCard("Level", value: "Lv.\(ruleManager.userStats.currentLevel)", icon: "trophy.fill", color: ruleManager.userStats.levelColor)
            statCard("Badges", value: "\(ruleManager.userStats.badges.count)", icon: "medal.fill", color: .purple)
            statCard("Check-ins", value: "\(ruleManager.userStats.totalRulesCompleted)", icon: "checkmark.circle.fill", color: .green)
        }
    }
    
    private func statCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
        )
    }
    
    private var periodBreakdown: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("By Period")
                .font(.system(size: 18, weight: .semibold))
            
            VStack(spacing: 16) {
                breakdownRow("Daily", rules: ruleManager.dailyRules, color: .orange, icon: "sun.max.fill")
                breakdownRow("Weekly", rules: ruleManager.weeklyRules, color: .blue, icon: "calendar.badge.clock")
                breakdownRow("Monthly", rules: ruleManager.monthlyRules, color: .purple, icon: "calendar")
                breakdownRow("Yearly", rules: ruleManager.yearlyRules, color: .pink, icon: "sparkles")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
        )
    }
    
    private func breakdownRow(_ title: String, rules: [Rule], color: Color, icon: String) -> some View {
        let completed = rules.filter { $0.isCompletedForPeriod }.count
        let percentage = rules.isEmpty ? 0 : Double(completed) / Double(rules.count) * 100
        
        return HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }
            
            // Title & Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Text("\(completed)/\(rules.count)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.15))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(percentage) / 100, height: 8)
                    }
                }
                .frame(height: 8)
            }
            
            // Percentage
            Text("\(Int(percentage))%")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
                .frame(width: 50, alignment: .trailing)
        }
    }
    
    private var streakCard: some View {
        HStack(spacing: 24) {
            // Flame Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 72, height: 72)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            
            // Streak Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(ruleManager.userStats.currentDayStreak)")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.orange)
                    Text("day streak")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 6)
                }
                
                Text("Best: \(ruleManager.userStats.longestStreak) days")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(colors: [.orange.opacity(0.15), .red.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
    }
    
    private func openAddRuleWindow() {
        let contentView = AddRuleWindowContent(ruleManager: ruleManager, userId: authManager.currentUser?.id ?? 0)
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Add Rule"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 450, height: 650))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Large Rule Row
struct LargeRuleRow: View {
    let rule: Rule
    @ObservedObject var ruleManager: RuleManager
    let color: Color
    @State private var isHovered = false
    @State private var showCompletion = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showCompletion = true
            }
            
            if rule.isCompletedForPeriod {
                // Uncheck
                ruleManager.decrementRule(rule)
            } else {
                // Check
                ruleManager.incrementRule(rule)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation {
                    showCompletion = false
                }
            }
        } label: {
            HStack(spacing: 24) {
                // Large Checkbox
                ZStack {
                    Circle()
                        .strokeBorder(rule.isCompletedForPeriod ? color : Color.secondary.opacity(0.3), lineWidth: 3)
                        .frame(width: 48, height: 48)
                    
                    if rule.isCompletedForPeriod || showCompletion {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Rule Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(rule.title)
                        .font(.system(size: 18, weight: .semibold))
                        .strikethrough(rule.isCompletedForPeriod, color: .secondary)
                        .foregroundColor(rule.isCompletedForPeriod ? .secondary : .primary)
                    
                    if let description = rule.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Progress & Streak
                    HStack(spacing: 16) {
                        if rule.targetCount > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12))
                                Text("\(rule.currentCount)/\(rule.targetCount)")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(color)
                        }
                        
                        if rule.streakCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                Text("\(rule.streakCount)")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.orange)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                            Text("+\(rule.pointsForCompletion)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.yellow)
                    }
                }
                
                Spacer()
                
                // Status
                if rule.isCompletedForPeriod {
                    Text("Done")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    .shadow(color: isHovered ? color.opacity(0.15) : .black.opacity(0.05), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(rule.isCompletedForPeriod ? color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered && !rule.isCompletedForPeriod ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// Old RuleBookView code was removed here - all kept in new simplified FullRuleBookView above

// MARK: - Rule Check Row (large checkbox style)
struct RuleCheckRow: View {
    let rule: Rule
    @ObservedObject var ruleManager: RuleManager
    @State private var isHovered = false
    @State private var showCheckAnimation = false
    
    var body: some View {
        Button {
            handleCheck()
        } label: {
            HStack(spacing: 20) {
                // Large checkbox
                checkboxView
                
                // Rule info
                ruleInfoSection
                
                Spacer()
                
                // Progress and streak
                progressSection
            }
            .padding(20)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    private var checkboxView: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(rule.isCompletedForPeriod ? rule.color : Color(nsColor: NSColor.controlBackgroundColor))
                .frame(width: 56, height: 56)
            
            // Border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(rule.color, lineWidth: 3)
                .frame(width: 56, height: 56)
            
            // Checkmark or count
            if rule.isCompletedForPeriod {
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(showCheckAnimation ? 1.2 : 1.0)
            } else if rule.targetCount > 1 {
                Text("\(rule.currentCount)/\(rule.targetCount)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(rule.color)
            } else {
                // Empty checkbox indicator
                Circle()
                    .stroke(rule.color.opacity(0.5), lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
        }
    }
    
    private var ruleInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title with icon
            HStack(spacing: 10) {
                if let iconName = rule.emoji {
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(rule.color)
                }
                
                Text(rule.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(rule.isCompletedForPeriod ? .secondary : .primary)
                    .strikethrough(rule.isCompletedForPeriod)
            }
            
            // Target info
            HStack(spacing: 12) {
                if rule.targetCount > 1 {
                    Text("Target: \(rule.targetCount)x per \(rule.period.displayName.lowercased())")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("Once per \(rule.period.displayName.lowercased())")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var progressSection: some View {
        HStack(spacing: 20) {
            // Streak
            if rule.streakCount > 0 {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(rule.streakCount)")
                            .font(.system(size: 18, weight: .bold))
                    }
                    Text("streak")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // Status
            if rule.isCompletedForPeriod {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
            } else {
                // Click hint
                Text("Click to complete")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(rule.isCompletedForPeriod ? rule.color.opacity(0.1) : Color(nsColor: NSColor.controlBackgroundColor))
            .shadow(color: isHovered ? .black.opacity(0.12) : .black.opacity(0.05), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(rule.isCompletedForPeriod ? Color.green.opacity(0.4) : (isHovered ? rule.color.opacity(0.3) : Color.clear), lineWidth: 2)
            )
    }
    
    private func handleCheck() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showCheckAnimation = true
            if rule.isCompletedForPeriod {
                // Uncheck
                ruleManager.decrementRule(rule)
            } else {
                // Check
                ruleManager.incrementRule(rule)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showCheckAnimation = false
        }
    }
}

// MARK: - Full Rule Row (for full app view)
struct FullRuleRow: View {
    let rule: Rule
    @ObservedObject var ruleManager: RuleManager
    @State private var isHovered = false
    @State private var showAnimation = false
    
    var body: some View {
        HStack(spacing: 16) {
            checkButton
            ruleInfo
            Spacer()
            statusIndicator
        }
        .padding(16)
        .background(rowBackground)
        .overlay(rowBorder)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    private var checkButton: some View {
        Button {
            handleCheck()
        } label: {
            ZStack {
                Circle()
                    .stroke(rule.color.opacity(0.3), lineWidth: 3)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .trim(from: 0, to: Double(rule.currentCount) / Double(max(rule.targetCount, 1)))
                    .stroke(rule.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                
                checkContent
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var checkContent: some View {
        if rule.isCompletedForPeriod {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(rule.color)
                .scaleEffect(showAnimation ? 1.3 : 1.0)
        } else {
            Text("\(rule.currentCount)/\(rule.targetCount)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(rule.color)
        }
    }
    
    private var ruleInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            ruleTitleRow
            ruleMetaRow
        }
    }
    
    private var ruleTitleRow: some View {
        HStack(spacing: 8) {
            if let iconName = rule.emoji {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(rule.color)
            }
            
            Text(rule.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(rule.isCompletedForPeriod ? .secondary : .primary)
                .strikethrough(rule.isCompletedForPeriod)
        }
    }
    
    private var ruleMetaRow: some View {
        HStack(spacing: 16) {
            periodBadge
            streakBadge
            pointsBadge
        }
    }
    
    private var periodBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: rule.period.icon)
                .font(.system(size: 11))
            Text(rule.period.displayName)
                .font(.system(size: 12))
        }
        .foregroundColor(rule.period.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(rule.period.color.opacity(0.1))
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private var streakBadge: some View {
        if rule.streakCount > 0 {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                Text("\(rule.streakCount)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.orange)
        }
    }
    
    private var pointsBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
            Text("+\(10 * rule.period.pointsMultiplier) pts")
                .font(.system(size: 12))
        }
        .foregroundColor(.yellow)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        if rule.isCompletedForPeriod {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(nsColor: NSColor.controlBackgroundColor))
            .shadow(color: isHovered ? .black.opacity(0.1) : .clear, radius: 8, y: 4)
    }
    
    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(rule.isCompletedForPeriod ? Color.green.opacity(0.3) : Color.clear, lineWidth: 2)
    }
    
    private func handleCheck() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            showAnimation = true
            if rule.isCompletedForPeriod {
                ruleManager.decrementRule(rule)
            } else {
                ruleManager.incrementRule(rule)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showAnimation = false
        }
    }
}

// MARK: - Full Journal View
struct FullJournalView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var journalManager = JournalManager.shared
    @StateObject private var ruleManager = RuleManager.shared
    
    @State private var viewMode: Int = 0  // 0 = Normal, 1 = Calendar
    @State private var selectedDate = Date()
    @State private var currentEntry: JournalEntry?
    @State private var showEditor = false
    @State private var currentMonth = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            journalHeader
            
            // View mode tabs
            viewModeTabs
            
            // Content
            if viewMode == 0 {
                normalView
            } else {
                calendarView
            }
        }
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .sheet(isPresented: $showEditor) {
            if let entry = currentEntry {
                JournalEditorView(
                    entry: Binding(
                        get: { entry },
                        set: { currentEntry = $0 }
                    ),
                    journalManager: journalManager,
                    taskManager: taskManager,
                    ruleManager: ruleManager
                )
            }
        }
        .onAppear {
            loadTodayEntry()
        }
    }
    
    private func loadTodayEntry() {
        if let userId = authManager.currentUser?.id {
            currentEntry = journalManager.getTodayEntry(userId: userId)
        }
    }
    
    // MARK: - Header
    private var journalHeader: some View {
        HStack(spacing: 16) {
            // Title
            HStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.purple)
                Text("Daily Journal")
                    .font(.system(size: 28, weight: .bold))
            }
            
            Spacer()
            
            // Stats
            HStack(spacing: 16) {
                // Streak
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(journalManager.stats.currentStreak) day streak")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
                
                // Total entries
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                    Text("\(journalManager.stats.totalEntries) entries")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.15))
                .clipShape(Capsule())
                
                // Points
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(journalManager.stats.totalPoints) pts")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.15))
                .clipShape(Capsule())
            }
            
            // Write Today button
            Button {
                if let userId = authManager.currentUser?.id {
                    currentEntry = journalManager.getTodayEntry(userId: userId)
                    showEditor = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 12, weight: .bold))
                    Text("Write Today")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - View Mode Tabs
    private var viewModeTabs: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation { viewMode = 0 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text("Entries")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(viewMode == 0 ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewMode == 0 ? Color.purple : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button {
                withAnimation { viewMode = 1 }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text("Calendar")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(viewMode == 1 ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(viewMode == 1 ? Color.purple : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - Normal View (List)
    private var normalView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Today's entry card (prominent)
                if let todayEntry = journalManager.getEntryForDate(Date()) {
                    todayEntryCard(todayEntry)
                } else {
                    emptyTodayCard
                }
                
                // Past entries
                let pastEntries = journalManager.entries
                    .filter { !Calendar.current.isDateInToday($0.date) }
                    .sorted { $0.date > $1.date }
                
                if !pastEntries.isEmpty {
                    Text("Past Entries")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)
                    
                    ForEach(pastEntries) { entry in
                        entryCard(entry)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func todayEntryCard(_ entry: JournalEntry) -> some View {
        Button {
            currentEntry = entry
            showEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.system(size: 24, weight: .bold))
                        Text(entry.date.formatted(date: .complete, time: .omitted))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Completion circle
                    ZStack {
                        Circle()
                            .stroke(Color.purple.opacity(0.2), lineWidth: 6)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0, to: entry.completionPercentage / 100)
                            .stroke(Color.purple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(entry.completionPercentage))%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.purple)
                    }
                }
                
                // Preview of content
                if !entry.topOutcomes.filter({ !$0.isEmpty }).isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Outcomes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        ForEach(entry.topOutcomes.filter { !$0.isEmpty }, id: \.self) { outcome in
                            HStack(spacing: 8) {
                                Image(systemName: "target")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)
                                Text(outcome)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }
                
                HStack {
                    Text("Click to continue writing...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.purple.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var emptyTodayCard: some View {
        Button {
            if let userId = authManager.currentUser?.id {
                currentEntry = journalManager.getTodayEntry(userId: userId)
                showEditor = true
            }
        } label: {
            VStack(spacing: 20) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 48))
                    .foregroundColor(.purple.opacity(0.5))
                
                Text("Start Today's Journal")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("Reflect on your day, track your progress,\nand grow with every entry")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("Begin Writing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func entryCard(_ entry: JournalEntry) -> some View {
        Button {
            currentEntry = entry
            showEditor = true
        } label: {
            HStack(spacing: 16) {
                // Date
                VStack(spacing: 4) {
                    Text(entry.date.formatted(.dateTime.day()))
                        .font(.system(size: 24, weight: .bold))
                    Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50)
                
                Divider()
                    .frame(height: 40)
                
                // Content preview
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.biggestWin.isEmpty ? "Journal Entry" : entry.biggestWin)
                        .font(.system(size: 16, weight: .medium))
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if !entry.dominantEmotion.isEmpty {
                            Text(entry.dominantEmotion)
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Text("\(Int(entry.completionPercentage))% complete")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Completion indicator
                Circle()
                    .fill(entry.completionPercentage >= 50 ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Calendar View
    private var calendarView: some View {
        HStack(spacing: 0) {
            // Calendar
            VStack(spacing: 16) {
                // Month navigation
                HStack {
                    Button {
                        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Button {
                        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Weekday headers
                let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid
                let days = calendarDays()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        calendarDayCell(date)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .frame(width: 400)
            .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Selected day preview
            VStack(spacing: 16) {
                Text(selectedDate.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let entry = journalManager.getEntryForDate(selectedDate) {
                    entryPreview(entry)
                } else {
                    noEntryView
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
    
    private func calendarDays() -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        var days: [Date] = []
        
        // Add padding for first week
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        for _ in 1..<firstWeekday {
            days.append(Date.distantPast)
        }
        
        // Add days of month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func calendarDayCell(_ date: Date) -> some View {
        let calendar = Calendar.current
        let isValidDate = date != Date.distantPast
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let hasEntry = isValidDate && journalManager.hasEntryForDate(date)
        let completion = journalManager.completionForDate(date)
        
        return Button {
            if isValidDate {
                selectedDate = date
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple)
                }
                
                VStack(spacing: 4) {
                    if isValidDate {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 14, weight: isToday ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : (isToday ? .purple : .primary))
                        
                        if hasEntry {
                            Circle()
                                .fill(completion >= 50 ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!isValidDate)
    }
    
    private func entryPreview(_ entry: JournalEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Completion
                HStack {
                    Text("Completion")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(entry.completionPercentage))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(entry.completionPercentage >= 50 ? .green : .orange)
                }
                
                Divider()
                
                // Biggest win
                if !entry.biggestWin.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Biggest Win")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(entry.biggestWin)
                            .font(.system(size: 14))
                    }
                }
                
                // Dominant emotion
                if !entry.dominantEmotion.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dominant Emotion")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(entry.dominantEmotion)
                            .font(.system(size: 14))
                    }
                }
                
                // Learning
                if !entry.oneLearned.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("One Thing Learned")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(entry.oneLearned)
                            .font(.system(size: 14))
                    }
                }
                
                Spacer()
                
                // Edit button
                Button {
                    currentEntry = entry
                    showEditor = true
                } label: {
                    Text("View Full Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var noEntryView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("No entry for this day")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            if Calendar.current.isDate(selectedDate, inSameDayAs: Date()) || selectedDate < Date() {
                Button {
                    if let userId = authManager.currentUser?.id {
                        currentEntry = journalManager.getOrCreateEntryForDate(selectedDate, userId: userId)
                        showEditor = true
                    }
                } label: {
                    Text("Create Entry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
}

// MARK: - Journal Editor View
struct JournalEditorView: View {
    @Binding var entry: JournalEntry
    @ObservedObject var journalManager: JournalManager
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var ruleManager: RuleManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSection = 0
    @State private var isHoveredSection: Int? = nil
    
    let sectionData: [(title: String, icon: String, color: Color)] = [
        ("Intent", "target", .purple),
        ("Daily Facts", "chart.bar.fill", .blue),
        ("Execution", "checkmark.seal.fill", .green),
        ("Mind", "brain.head.profile", .pink),
        ("Learning", "lightbulb.fill", .yellow),
        ("System", "gearshape.2.fill", .orange)
    ]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Sidebar - Section Navigation
                sidebarNavigation
                    .frame(width: 240)
                
                // Main Content Area
                mainContentArea
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .background(Color(nsColor: NSColor.textBackgroundColor))
    }
    
    // MARK: - Sidebar Navigation
    private var sidebarNavigation: some View {
        VStack(spacing: 0) {
            // Date Header
            VStack(spacing: 8) {
                Text(entry.date.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 32, weight: .bold))
            }
            .padding(.vertical, 32)
            
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.purple.opacity(0.15), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: entry.completionPercentage / 100)
                    .stroke(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(entry.completionPercentage))%")
                        .font(.system(size: 24, weight: .bold))
                    Text("done")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 32)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Section List
            VStack(spacing: 4) {
                ForEach(0..<sectionData.count, id: \.self) { index in
                    sectionButton(index)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Save Button
            Button {
                journalManager.updateEntry(entry)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Save & Close")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func sectionButton(_ index: Int) -> some View {
        let data = sectionData[index]
        let isSelected = selectedSection == index
        let isHovered = isHoveredSection == index
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedSection = index
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? data.color : data.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: data.icon)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? .white : data.color)
                }
                
                Text(data.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(data.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? data.color.opacity(0.1) : (isHovered ? Color.secondary.opacity(0.08) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHoveredSection = hovering ? index : nil
        }
    }
    
    // MARK: - Main Content Area
    private var mainContentArea: some View {
        VStack(spacing: 0) {
            // Top Bar with close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            
            // Section Content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Section Title
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(sectionData[selectedSection].color.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: sectionData[selectedSection].icon)
                                .font(.system(size: 24))
                                .foregroundColor(sectionData[selectedSection].color)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sectionData[selectedSection].title)
                                .font(.system(size: 28, weight: .bold))
                            Text(sectionSubtitle)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 40)
                    
                    // Content
                    Group {
                        switch selectedSection {
                        case 0: intentSection
                        case 1: dailyFactsSection
                        case 2: executionSection
                        case 3: mindSection
                        case 4: learningSection
                        case 5: systemSection
                        default: intentSection
                        }
                    }
                    
                    // Navigation Buttons
                    navigationButtons
                        .padding(.top, 48)
                }
                .padding(48)
                .frame(maxWidth: 700, alignment: .leading)
            }
        }
    }
    
    private var sectionSubtitle: String {
        switch selectedSection {
        case 0: return "Set your intentions for today"
        case 1: return "Track your daily metrics"
        case 2: return "Review what you accomplished"
        case 3: return "Reflect on your emotions"
        case 4: return "Capture your learnings"
        case 5: return "Improve your systems"
        default: return ""
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if selectedSection > 0 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSection -= 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            if selectedSection < sectionData.count - 1 {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedSection += 1
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(sectionData[selectedSection].color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Intent Section
    private var intentSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Top 3 outcomes
            VStack(alignment: .leading, spacing: 16) {
                Text("Top 3 Outcomes")
                    .font(.system(size: 16, weight: .semibold))
                
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            TextField("What do you want to achieve?", text: Binding(
                                get: { entry.topOutcomes.indices.contains(index) ? entry.topOutcomes[index] : "" },
                                set: { newValue in
                                    while entry.topOutcomes.count <= index {
                                        entry.topOutcomes.append("")
                                    }
                                    entry.topOutcomes[index] = newValue
                                }
                            ))
                            .font(.system(size: 15))
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            
            // Must not happen
            cleanFieldRow("Must Not Happen", text: $entry.mustNotHappen, placeholder: "What must you avoid today?", icon: "xmark.octagon")
            
            // Energy mode
            VStack(alignment: .leading, spacing: 12) {
                Text("Energy Mode")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 12) {
                    ForEach(EnergyMode.allCases, id: \.self) { mode in
                        Button {
                            entry.energyMode = mode
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(entry.energyMode == mode ? mode.color : mode.color.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(entry.energyMode == mode ? .white : mode.color)
                                }
                                Text(mode.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(entry.energyMode == mode ? mode.color : .secondary)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(entry.energyMode == mode ? mode.color.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(entry.energyMode == mode ? mode.color.opacity(0.3) : Color.secondary.opacity(0.15), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Main constraint
            cleanFieldRow("Main Constraint", text: $entry.mainConstraint, placeholder: "What's your biggest limitation?", icon: "exclamationmark.triangle")
        }
    }
    
    private var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Tasks")
                .font(.system(size: 14, weight: .semibold))
            
            let todayTasks = taskManager.todayTasks.filter { !$0.isCompleted && $0.type != .meeting }
            
            if todayTasks.isEmpty {
                Text("No tasks scheduled")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                ForEach(todayTasks.prefix(5)) { task in
                    HStack(spacing: 10) {
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Text(task.title)
                            .font(.system(size: 14))
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Daily Facts Section
    private var dailyFactsSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Sleep Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Sleep")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 32) {
                    // Hours
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hours")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            TextField("0", value: $entry.sleepHours, format: .number)
                                .font(.system(size: 24, weight: .semibold))
                                .textFieldStyle(.plain)
                                .frame(width: 60)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .background(Color(nsColor: NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("hrs")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Quality
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quality")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { rating in
                                Button {
                                    entry.sleepQuality = rating
                                } label: {
                                    Image(systemName: rating <= (entry.sleepQuality ?? 0) ? "star.fill" : "star")
                                        .font(.system(size: 24))
                                        .foregroundColor(rating <= (entry.sleepQuality ?? 0) ? .yellow : .secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            cleanFieldRow("Work Blocks", text: $entry.workBlocks, placeholder: "How many deep work sessions?", icon: "square.stack.3d.up")
            cleanFieldRow("Key Actions", text: $entry.keyActions, placeholder: "Your main accomplishments", icon: "bolt.fill")
            cleanFieldRow("Movement", text: $entry.movement, placeholder: "Exercise, walks, activity", icon: "figure.walk")
            cleanFieldRow("Food", text: $entry.foodNote, placeholder: "What did you eat?", icon: "leaf.fill")
            cleanFieldRow("Distractions", text: $entry.distractionNote, placeholder: "What pulled your focus?", icon: "exclamationmark.bubble")
            cleanFieldRow("Spending", text: $entry.moneyNote, placeholder: "Any notable expenses?", icon: "creditcard")
        }
    }
    
    // MARK: - Execution Section
    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Task Summary Cards
            HStack(spacing: 16) {
                let completed = taskManager.todayTasks.filter { $0.isCompleted }
                let missed = taskManager.todayTasks.filter { !$0.isCompleted && $0.type != .meeting }
                
                // Completed Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("\(completed.count)")
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text("Completed")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Missed Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red)
                        Text("\(missed.count)")
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text("Missed")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            cleanFieldRow("Planned vs Actual", text: $entry.plannedVsDid, placeholder: "How did reality compare to your plan?", icon: "arrow.left.arrow.right")
            cleanFieldRow("Biggest Win", text: $entry.biggestWin, placeholder: "What are you most proud of?", icon: "trophy.fill")
            cleanFieldRow("Biggest Miss", text: $entry.biggestMiss, placeholder: "Where did you fall short?", icon: "arrow.down.circle")
            cleanFieldRow("Root Cause", text: $entry.rootCause, placeholder: "Why did this happen?", icon: "magnifyingglass")
            cleanFieldRow("Tomorrow's Fix", text: $entry.fixForTomorrow, placeholder: "How will you improve?", icon: "arrow.up.forward")
        }
    }
    
    // MARK: - Mind Section
    private var mindSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            cleanFieldRow("Dominant Emotion", text: $entry.dominantEmotion, placeholder: "What feeling defined your day?", icon: "heart.fill")
            cleanFieldRow("Trigger", text: $entry.emotionTrigger, placeholder: "What caused this feeling?", icon: "bolt.heart")
            cleanFieldRow("Automatic Reaction", text: $entry.automaticReaction, placeholder: "How did you instinctively respond?", icon: "arrow.uturn.backward")
            cleanFieldRow("Better Response", text: $entry.betterResponse, placeholder: "What would be more effective?", icon: "lightbulb.fill")
        }
    }
    
    // MARK: - Learning Section
    private var learningSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            cleanFieldRow("One Thing Learned", text: $entry.oneLearned, placeholder: "What new insight did you gain?", icon: "brain")
            cleanFieldRow("Source", text: $entry.learningSource, placeholder: "Where did this come from?", icon: "book.fill")
            cleanFieldRow("Application", text: $entry.howToApply, placeholder: "How will you use this?", icon: "hammer.fill")
        }
    }
    
    // MARK: - System Section
    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            // Rules Status
            HStack(spacing: 16) {
                let completed = ruleManager.dailyRules.filter { $0.isCompletedForPeriod }
                let missed = ruleManager.dailyRules.filter { !$0.isCompletedForPeriod }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        Text("\(completed.count)")
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text("Rules Followed")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("\(missed.count)")
                            .font(.system(size: 28, weight: .bold))
                    }
                    Text("Rules Broken")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            cleanFieldRow("System That Failed", text: $entry.systemFailed, placeholder: "What process broke down?", icon: "gearshape.2")
            cleanFieldRow("Why It Failed", text: $entry.whyFailed, placeholder: "What was the root cause?", icon: "questionmark.circle")
            cleanFieldRow("System Fix", text: $entry.systemFix, placeholder: "How will you redesign it?", icon: "wrench.and.screwdriver")
        }
    }
    
    // MARK: - Clean Field Row
    private func cleanFieldRow(_ label: String, text: Binding<String>, placeholder: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .padding(16)
                .frame(minHeight: 52)
                .background(Color(nsColor: NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
        .environmentObject(NotificationManager.shared)
        .environmentObject(ThemeManager.shared)
}
