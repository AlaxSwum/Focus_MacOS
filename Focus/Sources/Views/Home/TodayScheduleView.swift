//
//  TodayScheduleView.swift
//  Focus
//
//  Today's schedule - only shows today's tasks, meetings, and skipped
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TodayScheduleView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedSegment = 0 // 0 = Upcoming, 1 = Completed, 2 = Skipped
    @State private var showSkipSheet = false
    @State private var taskToSkip: TaskItem?
    @State private var selectedTask: TaskItem?
    @State private var showingCalendarSheet = false
    
    // Only today's tasks (excluding meetings from other days)
    private var todayOnlyTasks: [TaskItem] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        return taskManager.todayTasks.filter { task in
            let taskDate = calendar.startOfDay(for: task.date)
            return taskDate >= todayStart && taskDate < tomorrowStart
        }
    }
    
    private var upcomingTasks: [TaskItem] {
        todayOnlyTasks.filter { !$0.isCompleted && !$0.isSkipped }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    private var completedTasks: [TaskItem] {
        todayOnlyTasks.filter { $0.isCompleted }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    private var skippedTasks: [TaskItem] {
        todayOnlyTasks.filter { $0.isSkipped }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    private var todayMeetingsCount: Int {
        todayOnlyTasks.filter { $0.type == .meeting }.count
    }
    
    private var todayBlocksCount: Int {
        todayOnlyTasks.filter { 
            if case .timeBlock = $0.type { return true }
            return false
        }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            segmentControl
            statsBar
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    switch selectedSegment {
                    case 0:
                        if upcomingTasks.isEmpty {
                            emptyState(message: "No upcoming tasks for today", icon: "checkmark.circle")
                        } else {
                            ForEach(upcomingTasks) { task in
                                taskRow(task)
                            }
                        }
                    case 1:
                        if completedTasks.isEmpty {
                            emptyState(message: "No completed tasks yet", icon: "checkmark.circle")
                        } else {
                            ForEach(completedTasks) { task in
                                taskRow(task)
                            }
                        }
                    case 2:
                        if skippedTasks.isEmpty {
                            emptyState(message: "No skipped tasks", icon: "forward.circle")
                        } else {
                            ForEach(skippedTasks) { task in
                                skippedRow(task)
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.systemBackground)
        .sheet(isPresented: $showSkipSheet) {
            if let task = taskToSkip {
                SkipTaskSheet(task: task) { reason in
                    taskManager.skipTask(task, reason: reason)
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: $showingCalendarSheet) {
            PersonalCalendarView()
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                showingCalendarSheet = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Segment Control
    private var segmentControl: some View {
        HStack(spacing: 4) {
            segmentButton(title: "Upcoming", count: upcomingTasks.count, index: 0, color: .blue)
            segmentButton(title: "Done", count: completedTasks.count, index: 1, color: .green)
            segmentButton(title: "Skipped", count: skippedTasks.count, index: 2, color: .orange)
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
    
    private func segmentButton(title: String, count: Int, index: Int, color: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedSegment = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        selectedSegment == index
                            ? Color.white.opacity(0.3)
                            : Color.secondary.opacity(0.2)
                    )
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                selectedSegment == index ? color : Color.clear
            )
            .foregroundColor(selectedSegment == index ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 8) {
            statItem(value: "\(todayOnlyTasks.count)", label: "TOTAL", color: .blue)
            statItem(value: "\(todayMeetingsCount)", label: "MEETINGS", color: .purple)
            statItem(value: "\(todayBlocksCount)", label: "BLOCKS", color: .cyan)
            statItem(value: "\(completedTasks.count)", label: "DONE", color: .green)
        }
        .padding(12)
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Task Row
    private func taskRow(_ taskItem: TaskItem) -> some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                let item = taskItem
                withAnimation(.spring(response: 0.25)) {
                    Task {
                        await taskManager.toggleComplete(task: item)
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(taskItem.isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
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
            }
            .buttonStyle(.plain)
            
            // Color bar
            Rectangle()
                .fill(taskItem.type.color)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(taskItem.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(taskItem.isCompleted || taskItem.isSkipped)
                    .foregroundColor(taskItem.isCompleted || taskItem.isSkipped ? .secondary : .primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Type badge
                    Text(taskItem.type.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(taskItem.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(taskItem.type.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    // Time
                    if !taskItem.timeText.isEmpty {
                        Text(taskItem.timeText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    // Skip button
                    if !taskItem.isCompleted && !taskItem.isSkipped {
                        Button {
                            taskToSkip = taskItem
                            showSkipSheet = true
                        } label: {
                            Text("Skip")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Spacer()
            
            // Detail arrow
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(taskItem.isNow ? taskItem.type.color.opacity(0.1) : Color.secondary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(taskItem.isNow ? taskItem.type.color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTask = taskItem
        }
        .contextMenu {
            Button(taskItem.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                Task {
                    await taskManager.toggleComplete(task: taskItem)
                }
            }
            if !taskItem.isSkipped && !taskItem.isCompleted {
                Button("Skip Task") {
                    taskToSkip = taskItem
                    showSkipSheet = true
                }
            }
        }
    }
    
    // MARK: - Skipped Row
    private func skippedRow(_ taskItem: TaskItem) -> some View {
        HStack(spacing: 10) {
            // Skip icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Image(systemName: "forward.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
            
            // Color bar
            Rectangle()
                .fill(taskItem.type.color)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(taskItem.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(taskItem.type.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(taskItem.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(taskItem.type.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if !taskItem.timeText.isEmpty {
                        Text(taskItem.timeText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Restore button
            Button {
                taskManager.unskipTask(taskItem)
            } label: {
                Text("Restore")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTask = taskItem
        }
        .contextMenu {
            Button("Restore Task") {
                taskManager.unskipTask(taskItem)
            }
            Button("Mark Complete") {
                Task { await taskManager.toggleComplete(task: taskItem) }
            }
        }
    }
    
    // MARK: - Empty State
    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Helpers
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
    
    private func refreshTasks() {
        if let userId = authManager.currentUser?.id {
            Task {
                await taskManager.fetchTasks(for: userId)
            }
        }
    }
}

// MARK: - Task Detail Sheet
struct TaskDetailSheet: View {
    let task: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(task.type.color)
                            .frame(width: 12, height: 12)
                        
                        Text(task.type.displayName)
                            .font(.caption)
                            .foregroundColor(task.type.color)
                        
                        if task.isCompleted {
                            Text("COMPLETED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        if task.isSkipped {
                            Text("SKIPPED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    
                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .strikethrough(task.isCompleted || task.isSkipped)
                        .foregroundColor(task.isCompleted || task.isSkipped ? .secondary : .primary)
                }
                
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
            
            Divider()
            
            // Time
            if !task.timeText.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    
                    Text(task.timeText)
                        .font(.subheadline)
                }
            }
            
            // Date
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                
                Text(formattedDate(task.date))
                    .font(.subheadline)
            }
            
            // Description
            if let description = task.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Meeting Link
            if let link = task.meetingLink, !link.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meeting Link")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button {
                        if let url = URL(string: link) {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Join Meeting")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            
            // Skip reason
            if let skipReason = task.skipReason, !skipReason.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skip Reason")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(skipReason)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Spacer()
            
            // Actions
            HStack {
                if task.isSkipped {
                    Button {
                        taskManager.unskipTask(task)
                        dismiss()
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button {
                    Task {
                        await taskManager.toggleComplete(task: task)
                        dismiss()
                    }
                } label: {
                    Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                          systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(task.isCompleted ? .gray : .green)
            }
        }
        .padding(24)
        .frame(minWidth: 380, minHeight: 350)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    TodayScheduleView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
        .frame(width: 380, height: 500)
}
