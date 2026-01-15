//
//  MenuBarDropdown.swift
//  Focus
//
//  Menu bar popup showing today's tasks
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MenuBarDropdown: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                authenticatedContent
            } else {
                loginPrompt
            }
        }
        .frame(width: 320)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
    
    // MARK: - Login Prompt
    private var loginPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Focus")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Open the app to sign in")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Open Focus") {
                openMainApp()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
    
    // MARK: - Authenticated Content
    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Today (\(taskManager.todayTasks.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Stats
                HStack(spacing: 12) {
                    miniStat(value: taskManager.completedTodayCount, color: .green)
                    miniStat(value: taskManager.upcomingCount, color: .orange)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            // Task list
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    // Current task
                    if let current = taskManager.currentTask {
                        currentTaskRow(current)
                    }
                    
                    // Upcoming tasks
                    let upcoming = taskManager.todayTasks.filter { !$0.isCompleted && !$0.isPast && !$0.isSkipped }
                        .prefix(5)
                    
                    ForEach(Array(upcoming)) { task in
                        taskRow(task)
                    }
                    
                    if upcoming.isEmpty && taskManager.currentTask == nil {
                        emptyState
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 280)
            
            Divider()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    openMainApp()
                } label: {
                    Label("Open Full App", systemImage: "arrow.up.forward.app")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Button {
                    openSettings()
                } label: {
                    Text("Settings")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
        }
    }
    
    // MARK: - Mini Stat
    private func miniStat(value: Int, color: Color) -> some View {
        Text("\(value)")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }
    
    // MARK: - Current Task Row
    private func currentTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            Rectangle()
                .fill(task.type.color)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("NOW")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.green)
                
                Text(task.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(task.timeText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(task.type.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Task Row
    private func taskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Circle()
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 14, height: 14)
            
            Rectangle()
                .fill(task.type.color)
                .frame(width: 2)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                
                Text(task.type.displayName)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(task.timeText)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundColor(.green)
            
            Text("All clear!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Actions
    private func openMainApp() {
        #if os(macOS)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isVisible == false }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open new window
            NSApp.sendAction(Selector(("newWindowForTab:")), to: nil, from: nil)
        }
        #endif
    }

    private func openSettings() {
        #if os(macOS)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        #endif
    }
    
}

#Preview {
    MenuBarDropdown()
        .environmentObject(AuthManager.shared)
        .environmentObject(TaskManager.shared)
}
