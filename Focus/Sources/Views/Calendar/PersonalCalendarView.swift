//
//  PersonalCalendarView.swift
//  Focus
//
//  Full calendar view - Apple Calendar style with drag to create
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PersonalCalendarView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .day
    @State private var selectedTask: TaskItem?
    @State private var taskToEdit: TaskItem?
    
    // Drag to create states
    @State private var isDragging = false
    @State private var dragStartHour: Int?
    @State private var dragEndHour: Int?
    @State private var showingQuickAdd = false
    @State private var quickAddStartTime: Date?
    @State private var quickAddEndTime: Date?
    @State private var quickAddTitle = ""
    
    enum ViewMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            calendarHeader
            
            // View toggle
            viewModeToggle
            
            // Calendar content
            Group {
                switch viewMode {
                case .day:
                    dayView
                case .week:
                    weekView
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(minWidth: 500, minHeight: 600)
        .background(Color.systemBackground)
        .sheet(item: $taskToEdit) { task in
            AddEditTaskView(date: selectedDate, task: task, startTime: nil, endTime: nil)
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddTaskSheet(
                startTime: quickAddStartTime ?? Date(),
                endTime: quickAddEndTime ?? Date().addingTimeInterval(3600),
                title: $quickAddTitle,
                onSave: { title, start, end in
                    saveQuickTask(title: title, start: start, end: end)
                }
            )
            .environmentObject(taskManager)
            .environmentObject(authManager)
        }
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack(spacing: 16) {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
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
                    Text(headerTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(daySubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 150)
                
                Button {
                    navigateNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Today button
            Button("Today") {
                withAnimation(.spring(response: 0.3)) {
                    selectedDate = Date()
                }
            }
            .buttonStyle(.bordered)
            
            // Refresh
            Button {
                refreshTasks()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.secondarySystemBackground)
    }
    
    // MARK: - View Mode Toggle
    private var viewModeToggle: some View {
        HStack(spacing: 4) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(viewMode == mode ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewMode == mode ? Color.accentColor : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
        .padding(.vertical, 12)
    }
    
    // MARK: - Day View with Drag to Create
    private var dayView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Hour grid
                    LazyVStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            hourRow(hour)
                                .id(hour)
                        }
                    }
                    
                    // Drag preview overlay
                    if isDragging, let startHour = dragStartHour, let endHour = dragEndHour {
                        dragPreviewOverlay(startHour: startHour, endHour: endHour)
                    }
                }
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            handleDragChanged(value)
                        }
                        .onEnded { value in
                            handleDragEnded(value)
                        }
                )
            }
            .onAppear {
                let currentHour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(0, currentHour - 1), anchor: .top)
            }
        }
    }
    
    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            Text(formatHour(hour))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            // Hour content
            ZStack(alignment: .topLeading) {
                // Grid line
                VStack {
                    Divider()
                    Spacer()
                }
                
                // Current time indicator
                if isCurrentHour(hour) {
                    currentTimeIndicator
                }
                
                // Task blocks for this hour
                let hourTasks = tasksForHour(hour)
                ForEach(hourTasks) { task in
                    taskBlockView(task, in: hour)
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Drag to Create
    private func handleDragChanged(_ value: DragGesture.Value) {
        let hourHeight: CGFloat = 60
        let startY = value.startLocation.y
        let currentY = value.location.y
        
        // Calculate hours from Y position (accounting for time label width)
        let startHour = Int(startY / hourHeight)
        let currentHour = Int(currentY / hourHeight)
        
        let minHour = min(startHour, currentHour)
        let maxHour = max(startHour, currentHour)
        
        isDragging = true
        dragStartHour = max(0, min(23, minHour))
        dragEndHour = max(0, min(23, maxHour))
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        guard let startHour = dragStartHour, let endHour = dragEndHour else {
            isDragging = false
            return
        }
        
        // Create time range
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        startComponents.hour = startHour
        startComponents.minute = 0
        
        var endComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        endComponents.hour = endHour + 1
        endComponents.minute = 0
        
        if let start = calendar.date(from: startComponents),
           let end = calendar.date(from: endComponents) {
            quickAddStartTime = start
            quickAddEndTime = end
            quickAddTitle = ""
            showingQuickAdd = true
        }
        
        isDragging = false
        dragStartHour = nil
        dragEndHour = nil
    }
    
    private func dragPreviewOverlay(startHour: Int, endHour: Int) -> some View {
        let hourHeight: CGFloat = 60
        let topOffset = CGFloat(startHour) * hourHeight
        let height = CGFloat(endHour - startHour + 1) * hourHeight
        
        return RoundedRectangle(cornerRadius: 8)
            .fill(Color.accentColor.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 2, antialiased: true)
            )
            .overlay(
                VStack {
                    Text("New Task")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                    Text("\(formatHour(startHour)) - \(formatHour(endHour + 1))")
                        .font(.caption2)
                        .foregroundColor(.accentColor.opacity(0.8))
                }
            )
            .frame(height: height)
            .padding(.leading, 62) // Account for time label
            .padding(.trailing, 8)
            .offset(y: topOffset)
    }
    
    private func taskBlockView(_ task: TaskItem, in hour: Int) -> some View {
        let duration = taskDuration(task)
        let height = max(50, duration * 60 / 60)
        
        return HStack(spacing: 0) {
            // Color indicator
            Rectangle()
                .fill(task.type.color)
                .frame(width: 4)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
                
                if duration >= 30 {
                    Text(task.timeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            
            Spacer()
            
            // Complete button
            Button {
                Task { await taskManager.toggleComplete(task: task) }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(task.type.color.opacity(task.isCompleted ? 0.08 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(task.type.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.top, 2)
        .onTapGesture {
            selectedTask = task
        }
        .contextMenu {
            Button("Edit Task") { taskToEdit = task }
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                Task { await taskManager.toggleComplete(task: task) }
            }
            Divider()
            Button("Delete", role: .destructive) {
                Task { await deleteTask(task) }
            }
        }
    }
    
    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: Date())
        let offset = CGFloat(minutes) / 60.0 * 60
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
        }
        .offset(y: offset)
    }
    
    // MARK: - Week View
    private var weekView: some View {
        VStack(spacing: 0) {
            // Week day headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 50)
                
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(dayName(day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(dayNumber(day))")
                            .font(.system(size: 14, weight: Calendar.current.isDateInToday(day) ? .bold : .medium))
                            .foregroundColor(Calendar.current.isDateInToday(day) ? .white : .primary)
                            .frame(width: 28, height: 28)
                            .background(Calendar.current.isDateInToday(day) ? Color.accentColor : Color.clear)
                            .clipShape(Circle())
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDate = day
                            viewMode = .day
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color.secondarySystemBackground)
            
            // Week grid
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        weekHourRow(hour)
                    }
                }
            }
        }
    }
    
    private func weekHourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(formatHour(hour))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            ForEach(weekDays, id: \.self) { day in
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.separator.opacity(0.3))
                        .frame(height: 0.5)
                    
                    let dayTasks = tasksForHour(hour, on: day)
                    VStack(spacing: 2) {
                        ForEach(dayTasks) { task in
                            weekTaskBlock(task)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Calendar.current.isDateInToday(day)
                        ? Color.accentColor.opacity(0.05)
                        : Color.clear
                )
            }
        }
    }
    
    private func weekTaskBlock(_ task: TaskItem) -> some View {
        HStack(spacing: 2) {
            Rectangle()
                .fill(task.type.color)
                .frame(width: 2)
            
            Text(task.title)
                .font(.system(size: 9))
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 3)
        .background(task.type.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onTapGesture {
            selectedTask = task
        }
    }
    
    // MARK: - Helpers
    private var headerTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var daySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }
    
    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func dayNumber(_ date: Date) -> Int {
        Calendar.current.component(.day, from: date)
    }
    
    private func isCurrentHour(_ hour: Int) -> Bool {
        Calendar.current.isDateInToday(selectedDate) &&
        Calendar.current.component(.hour, from: Date()) == hour
    }
    
    private func tasksForHour(_ hour: Int) -> [TaskItem] {
        tasksForHour(hour, on: selectedDate)
    }
    
    private func tasksForHour(_ hour: Int, on date: Date) -> [TaskItem] {
        taskManager.todayTasks.filter { task in
            guard let startTime = task.startTime else { return false }
            let taskHour = Calendar.current.component(.hour, from: startTime)
            let isSameDay = Calendar.current.isDate(task.date, inSameDayAs: date)
            return taskHour == hour && isSameDay
        }
    }
    
    private func taskDuration(_ task: TaskItem) -> CGFloat {
        guard let start = task.startTime, let end = task.endTime else { return 30 }
        return CGFloat(end.timeIntervalSince(start) / 60)
    }
    
    private func navigatePrevious() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let calendar = Calendar.current
            switch viewMode {
            case .day:
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            }
        }
    }
    
    private func navigateNext() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let calendar = Calendar.current
            switch viewMode {
            case .day:
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            case .week:
                selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            }
        }
    }
    
    private func refreshTasks() {
        if let userId = authManager.currentUser?.id {
            Task {
                await taskManager.fetchTasks(for: userId)
            }
        }
    }
    
    private func saveQuickTask(title: String, start: Date, end: Date) {
        guard let userId = authManager.currentUser?.id, !title.isEmpty else { return }
        
        Task {
            await createTask(title: title, start: start, end: end, userId: userId)
            await taskManager.fetchTasks(for: userId)
        }
    }
    
    private func createTask(title: String, start: Date, end: Date, userId: Int) async {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let blockData: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": userId,
            "date": dateFormatter.string(from: start),
            "start_time": timeFormatter.string(from: start),
            "end_time": timeFormatter.string(from: end),
            "title": title,
            "type": "personal",
            "completed": false,
            "is_recurring": false
        ]
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: blockData)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to create task: \(error)")
        }
    }
    
    private func deleteTask(_ task: TaskItem) async {
        guard task.originalType == "timeblock" else { return }
        
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks?id=eq.\(task.originalId)") else { return }
        
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
            print("Failed to delete task: \(error)")
        }
    }
}

// MARK: - Quick Add Task Sheet
struct QuickAddTaskSheet: View {
    let startTime: Date
    let endTime: Date
    @Binding var title: String
    let onSave: (String, Date, Date) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var localStartTime: Date
    @State private var localEndTime: Date
    @State private var selectedType: BlockType = .personal
    @FocusState private var isTitleFocused: Bool
    
    init(startTime: Date, endTime: Date, title: Binding<String>, onSave: @escaping (String, Date, Date) -> Void) {
        self.startTime = startTime
        self.endTime = endTime
        self._title = title
        self.onSave = onSave
        self._localStartTime = State(initialValue: startTime)
        self._localEndTime = State(initialValue: endTime)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("New Task")
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
            
            // Title input
            TextField("Task title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($isTitleFocused)
            
            // Time pickers
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $localStartTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    DatePicker("", selection: $localEndTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                
                Spacer()
                
                // Duration display
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(durationText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Adjust with arrow keys hint
            Text("Tip: Use arrow keys to adjust time by 15 minutes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add Task") {
                    onSave(title, localStartTime, localEndTime)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350, height: 280)
        .onAppear {
            isTitleFocused = true
        }
        .onKeyPress(.upArrow) {
            localEndTime = localEndTime.addingTimeInterval(15 * 60)
            return .handled
        }
        .onKeyPress(.downArrow) {
            localEndTime = localEndTime.addingTimeInterval(-15 * 60)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            localStartTime = localStartTime.addingTimeInterval(-15 * 60)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            localStartTime = localStartTime.addingTimeInterval(15 * 60)
            return .handled
        }
    }
    
    private var durationText: String {
        let minutes = Int(localEndTime.timeIntervalSince(localStartTime) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

#Preview {
    PersonalCalendarView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
