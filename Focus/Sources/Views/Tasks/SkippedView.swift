//
//  SkippedView.swift
//  Focus
//
//  Shows all skipped tasks
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SkippedView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTask: TaskItem?
    
    private var skippedTasks: [TaskItem] {
        taskManager.todayTasks.filter { $0.isSkipped }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            statsBar
            
            if skippedTasks.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(skippedTasks) { task in
                            skippedRow(task)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            SkippedDetailSheet(task: task)
                .environmentObject(taskManager)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skipped Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(skippedTasks.count) tasks skipped")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                refreshTasks()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var statsBar: some View {
        HStack(spacing: 8) {
            let meetings = skippedTasks.filter { $0.type == .meeting }.count
            let blocks = skippedTasks.filter { 
                if case .timeBlock = $0.type { return true }
                return false
            }.count
            let todos = skippedTasks.filter { $0.type == .todo }.count
            
            statItem(value: "\(skippedTasks.count)", label: "TOTAL", color: .orange)
            statItem(value: "\(meetings)", label: "MEETINGS", color: .purple)
            statItem(value: "\(blocks)", label: "BLOCKS", color: .blue)
            statItem(value: "\(todos)", label: "TODOS", color: .cyan)
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
    
    private func skippedRow(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            // Skip icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "forward.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
            
            // Color bar
            Rectangle()
                .fill(task.type.color)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough()
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    // Type badge
                    Text(task.type.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(task.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(task.type.color.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    // Time
                    if !task.timeText.isEmpty {
                        Text(task.timeText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Restore button
            Button {
                Task {
                    taskManager.unskipTask(task)
                }
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
        .onTapGesture {
            selectedTask = task
        }
        .contextMenu {
            Button("Restore Task") {
                taskManager.unskipTask(task)
            }
            Button("Mark Complete") {
                Task { await taskManager.toggleComplete(task: task) }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "forward.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No skipped tasks")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Tasks you skip will appear here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func refreshTasks() {
        if let userId = authManager.currentUser?.id {
            Task {
                await taskManager.fetchTasks(for: userId)
            }
        }
    }
}

// MARK: - Skipped Detail Sheet
struct SkippedDetailSheet: View {
    let task: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(task.type.color)
                            .frame(width: 12, height: 12)
                        
                        Text(task.type.displayName)
                            .font(.caption)
                            .foregroundColor(task.type.color)
                        
                        Text("SKIPPED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Text(task.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .strikethrough()
                        .foregroundColor(.secondary)
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
                Label(task.timeText, systemImage: "clock")
                    .font(.subheadline)
            }
            
            // Skip reason (if available)
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
            
            // Description
            if let description = task.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.body)
                }
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button {
                    taskManager.unskipTask(task)
                    dismiss()
                } label: {
                    Label("Restore Task", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button {
                    Task {
                        await taskManager.toggleComplete(task: task)
                        dismiss()
                    }
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(24)
        .frame(minWidth: 350, minHeight: 300)
    }
}

#Preview {
    SkippedView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
