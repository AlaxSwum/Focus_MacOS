//
//  TasksView.swift
//  Focus
//
//  Tasks list view
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject var taskManager: TaskManager
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var showingAddTask = false
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case completed = "Completed"
        case skipped = "Skipped"
    }
    
    var filteredTasks: [TaskItem] {
        var tasks = taskManager.todayTasks
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .upcoming:
            tasks = tasks.filter { !$0.isCompleted && !$0.isSkipped && $0.isUpcoming }
        case .completed:
            tasks = tasks.filter { $0.isCompleted }
        case .skipped:
            tasks = tasks.filter { $0.isSkipped }
        }
        
        // Apply search
        if !searchText.isEmpty {
            tasks = tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return tasks
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Tasks list
            if filteredTasks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredTasks) { task in
                        TaskListRow(task: task)
                            .swipeActions(edge: .trailing) {
                                if !task.isCompleted {
                                    Button {
                                        Task { await taskManager.toggleComplete(task: task) }
                                    } label: {
                                        Label("Complete", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !task.isSkipped && !task.isCompleted {
                                    Button {
                                        taskManager.skipTask(task, reason: nil)
                                    } label: {
                                        Label("Skip", systemImage: "forward")
                                    }
                                    .tint(.orange)
                                }
                            }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
        .searchable(text: $searchText, prompt: "Search tasks")
        .navigationTitle("Tasks")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddTask = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "tray"
        case .upcoming: return "clock"
        case .completed: return "checkmark.circle"
        case .skipped: return "forward"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Tasks"
        case .upcoming: return "No Upcoming Tasks"
        case .completed: return "No Completed Tasks"
        case .skipped: return "No Skipped Tasks"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "Add a task to get started"
        case .upcoming: return "You're all caught up!"
        case .completed: return "Complete tasks to see them here"
        case .skipped: return "Skipped tasks will appear here"
        }
    }
}

// MARK: - Task List Row
struct TaskListRow: View {
    let task: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(task.type.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted || task.isSkipped)
                    .foregroundColor(task.isCompleted || task.isSkipped ? .secondary : .primary)
                
                HStack(spacing: 8) {
                    if !task.timeText.isEmpty {
                        Label(task.timeText, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(task.isSkipped ? "Skipped" : task.type.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(task.isSkipped ? Color.orange.opacity(0.15) : task.type.color.opacity(0.15))
                        .foregroundColor(task.isSkipped ? .orange : task.type.color)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            // Complete button
            if !task.isCompleted && !task.isSkipped {
                Button {
                    Task { await taskManager.toggleComplete(task: task) }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                Task { await taskManager.toggleComplete(task: task) }
            }
            if !task.isSkipped {
                Button("Skip Task") {
                    taskManager.skipTask(task, reason: nil)
                }
            }
        }
    }
    
    private var statusIcon: String {
        if task.isCompleted { return "checkmark" }
        if task.isSkipped { return "forward.fill" }
        return task.type.icon
    }
    
    private var statusColor: Color {
        if task.isCompleted { return .green }
        if task.isSkipped { return .orange }
        return task.type.color
    }
}

#Preview {
    NavigationStack {
        TasksView()
            .environmentObject(TaskManager.shared)
    }
}
