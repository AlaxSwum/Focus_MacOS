//
//  MenuBarView.swift
//  Focus
//
//  Compact macOS Menu Bar dropdown
//

import SwiftUI

#if os(macOS)
struct MenuBarView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Focus")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Stats
                HStack(spacing: 12) {
                    statBadge(value: taskManager.completedTodayCount, color: .green)
                    statBadge(value: taskManager.upcomingCount, color: .orange)
                }
            }
            .padding(12)
            
            Divider()
            
            // Current task
            if let current = taskManager.currentTask {
                currentTaskRow(current)
                Divider()
            }
            
            // Task list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(taskManager.todayTasks.prefix(6)) { task in
                        menuTaskRow(task)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 200)
            
            Divider()
            
            // Footer
            HStack {
                Button {
                    if let userId = authManager.currentUser?.id {
                        Task { await taskManager.fetchTasks(for: userId) }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("Open App") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }
    
    private func statBadge(value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
    
    private func currentTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(task.timeText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task { await taskManager.toggleComplete(task: task) }
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(task.type.color.opacity(0.1))
    }
    
    private func menuTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            // Checkbox
            Button {
                Task { await taskManager.toggleComplete(task: task) }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: 14, height: 14)
                    
                    if task.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.caption)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                
                if let time = task.startTime {
                    Text(formatTime(time))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Circle()
                .fill(task.type.color)
                .frame(width: 6, height: 6)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(task.isNow ? task.type.color.opacity(0.1) : Color.clear)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
#endif
