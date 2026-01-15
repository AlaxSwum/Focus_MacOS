//
//  ScheduleView.swift
//  Focus
//
//  Calendar view like Personal page with time blocks
//

import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .day
    @State private var showingAddTask = false
    @State private var selectedTask: TaskItem?
    @State private var dragOffset: CGFloat = 0
    
    enum ViewMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            calendarHeader
            
            // View toggle
            viewToggle
            
            // Calendar content
            Group {
                switch viewMode {
                case .day:
                    dayCalendarView
                case .week:
                    weekCalendarView
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if value.translation.width > 50 {
                                navigatePrevious()
                            } else if value.translation.width < -50 {
                                navigateNext()
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
                .presentationDetents([.medium])
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
                .presentationDetents([.medium])
        }
    }
    
    // MARK: - Calendar Header
    private var calendarHeader: some View {
        HStack {
            Button(action: navigatePrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(headerTitle)
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                if viewMode == .day {
                    Text(daySubtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .animation(.spring(response: 0.3), value: selectedDate)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Today") {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = Date()
                    }
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
                
                Button(action: navigateNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - View Toggle
    private var viewToggle: some View {
        HStack(spacing: 4) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.caption)
                        .fontWeight(viewMode == mode ? .semibold : .regular)
                        .foregroundColor(viewMode == mode ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(viewMode == mode ? Color.accentColor : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Day Calendar View (Like Personal Page)
    private var dayCalendarView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(6..<23, id: \.self) { hour in
                        hourRow(hour)
                            .id(hour)
                    }
                }
                .padding(.horizontal, 12)
            }
            .onAppear {
                let currentHour = Calendar.current.component(.hour, from: Date())
                proxy.scrollTo(max(6, currentHour - 1), anchor: .top)
            }
        }
    }
    
    // MARK: - Hour Row
    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Time label
            Text(formatHour(hour))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            
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
                    taskBlock(task, in: hour)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Task Block (Like Personal Page)
    private func taskBlock(_ task: TaskItem, in hour: Int) -> some View {
        let duration = taskDuration(task)
        let height = max(44, duration * 52 / 60)
        
        return HStack(spacing: 0) {
            // Color indicator
            Rectangle()
                .fill(task.type.color)
                .frame(width: 3)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(1)
                
                if duration >= 30 {
                    Text(task.timeText)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            Spacer()
            
            // Completion indicator
            if task.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.trailing, 6)
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(task.type.color.opacity(task.isCompleted ? 0.08 : 0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(task.type.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.top, 2)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                selectedTask = task
            }
        }
    }
    
    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: Date())
        let offset = CGFloat(minutes) / 60.0 * 52
        
        return HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .offset(y: offset)
    }
    
    // MARK: - Week Calendar View
    private var weekCalendarView: some View {
        VStack(spacing: 0) {
            // Week day headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 40)
                
                ForEach(weekDays, id: \.self) { day in
                    VStack(spacing: 4) {
                        Text(dayName(day))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(dayNumber(day))")
                            .font(.caption)
                            .fontWeight(Calendar.current.isDateInToday(day) ? .bold : .medium)
                            .foregroundColor(Calendar.current.isDateInToday(day) ? .white : .primary)
                            .frame(width: 24, height: 24)
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
                    ForEach(6..<23, id: \.self) { hour in
                        weekHourRow(hour)
                    }
                }
            }
        }
    }
    
    // MARK: - Week Hour Row
    private func weekHourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(formatHour(hour))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
            
            ForEach(weekDays, id: \.self) { day in
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color.separator.opacity(0.3))
                        .frame(height: 0.5)
                    
                    let dayTasks = tasksForHour(hour, on: day)
                    VStack(spacing: 1) {
                        ForEach(dayTasks) { task in
                            weekTaskBlock(task)
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Calendar.current.isDateInToday(day)
                        ? Color.accentColor.opacity(0.05)
                        : Color.clear
                )
            }
        }
    }
    
    // MARK: - Week Task Block
    private func weekTaskBlock(_ task: TaskItem) -> some View {
        HStack(spacing: 2) {
            Rectangle()
                .fill(task.type.color)
                .frame(width: 2)
            
            Text(task.title)
                .font(.system(size: 8))
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .background(task.type.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onTapGesture {
            selectedTask = task
        }
    }
    
    // MARK: - Helpers
    private var headerTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = viewMode == .week ? "MMMM yyyy" : "MMM d, yyyy"
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
        return "\(displayHour)\(period)"
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
}

#Preview {
    ScheduleView()
        .environmentObject(TaskManager.shared)
        .frame(width: 360, height: 600)
}
