//
//  TodoListView.swift
//  Focus
//
//  Todo list view - shows only todo items
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct TodoListView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedSegment = 0 // 0 = Active, 1 = Completed
    @State private var selectedTask: TaskItem?
    @State private var showSkipSheet = false
    @State private var taskToSkip: TaskItem?
    
    private var todoItems: [TaskItem] {
        taskManager.todayTasks.filter { $0.type == .todo }
    }
    
    private var activeTodos: [TaskItem] {
        todoItems.filter { !$0.isCompleted && !$0.isSkipped }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    private var completedTodos: [TaskItem] {
        todoItems.filter { $0.isCompleted }
            .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            segmentControl
            statsBar
            
            if currentList.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(currentList) { todo in
                            todoRow(todo)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(task: task)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: $showSkipSheet) {
            if let task = taskToSkip {
                SkipTaskSheet(task: task) { reason in
                    taskManager.skipTask(task, reason: reason)
                }
            }
        }
    }
    
    private var currentList: [TaskItem] {
        selectedSegment == 0 ? activeTodos : completedTodos
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Todo List")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(activeTodos.count) active, \(completedTodos.count) completed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var segmentControl: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Active", count: activeTodos.count, index: 0)
            segmentButton(title: "Completed", count: completedTodos.count, index: 1)
        }
        .padding(4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
    
    private func segmentButton(title: String, count: Int, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedSegment = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        selectedSegment == index
                            ? Color.white.opacity(0.3)
                            : Color.secondary.opacity(0.2)
                    )
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedSegment == index ? Color.orange : Color.clear
            )
            .foregroundColor(selectedSegment == index ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
    
    private var statsBar: some View {
        HStack(spacing: 8) {
            statItem(value: "\(todoItems.count)", label: "TOTAL", color: .orange)
            statItem(value: "\(activeTodos.count)", label: "ACTIVE", color: .blue)
            statItem(value: "\(completedTodos.count)", label: "DONE", color: .green)
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
    
    private func todoRow(_ task: TaskItem) -> some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                Task { await taskManager.toggleComplete(task: task) }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? Color.green : Color.orange.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if task.isCompleted {
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
                .fill(Color.orange)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                
                if let description = task.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Skip button
            if !task.isCompleted && !task.isSkipped {
                Button {
                    taskToSkip = task
                    showSkipSheet = true
                } label: {
                    Text("Skip")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .onTapGesture {
            selectedTask = task
        }
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                Task { await taskManager.toggleComplete(task: task) }
            }
            if !task.isSkipped && !task.isCompleted {
                Button("Skip Task") {
                    taskToSkip = task
                    showSkipSheet = true
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedSegment == 0 ? "checklist" : "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(selectedSegment == 0 ? "No active todos" : "No completed todos")
                .font(.subheadline)
                .foregroundColor(.secondary)
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

#Preview {
    TodoListView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
