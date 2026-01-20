//
//  TaskDetailView.swift
//  Focus
//
//  Task detail sheet
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct TaskDetailView: View {
    let task: TaskItem
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingSkipSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header card
                    headerCard
                    
                    // Time info
                    if !task.timeText.isEmpty {
                        timeCard
                    }
                    
                    // Description
                    if let description = task.description, !description.isEmpty {
                        descriptionCard(description)
                    }
                    
                    // Meeting link
                    if let link = task.meetingLink, !link.isEmpty {
                        linkCard(link)
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Task Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSkipSheet) {
            SkipTaskSheet(task: task) { reason in
                taskManager.skipTask(task, reason: reason)
                dismiss()
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(task.type.color.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: task.type.icon)
                    .font(.system(size: 32))
                    .foregroundColor(task.type.color)
            }
            
            // Title
            Text(task.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .strikethrough(task.isCompleted || task.isSkipped)
            
            // Status badge
            HStack(spacing: 8) {
                if task.isCompleted {
                    statusBadge(text: "Completed", color: .green, icon: "checkmark.circle.fill")
                } else if task.isSkipped {
                    statusBadge(text: "Skipped", color: .orange, icon: "forward.fill")
                } else if task.isNow {
                    statusBadge(text: "In Progress", color: .blue, icon: "play.fill")
                } else if task.isPast {
                    statusBadge(text: "Passed", color: .gray, icon: "clock")
                } else {
                    statusBadge(text: "Upcoming", color: .green, icon: "clock.badge.checkmark")
                }
                
                Text(task.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(task.type.color.opacity(0.15))
                    .foregroundColor(task.type.color)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private func statusBadge(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
    
    // MARK: - Time Card
    private var timeCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Time")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(task.timeText)
                    .font(.headline)
            }
            
            Spacer()
            
            if let start = task.startTime, let end = task.endTime {
                let minutes = Int(end.timeIntervalSince(start) / 60)
                let hours = minutes / 60
                let mins = minutes % 60
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m")
                        .font(.headline)
                }
            }
        }
        .padding()
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Description Card
    private func descriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.secondary)
                Text("Description")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(description)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Link Card
    private func linkCard(_ link: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                Text("Meeting Link")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button {
                if let url = URL(string: link) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                Text(link)
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if !task.isCompleted && !task.isSkipped {
                // Complete button
                Button {
                    Task {
                        await taskManager.toggleComplete(task: task)
                        dismiss()
                    }
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                // Skip button
                Button {
                    showingSkipSheet = true
                } label: {
                    Label("Skip Task", systemImage: "forward.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            
            if task.isSkipped, let reason = task.skipReason {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundColor(.orange)
                        Text("Skip Reason")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(reason)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

#Preview {
    TaskDetailView(
        task: TaskItem(
            id: "1",
            title: "Team Meeting",
            description: "Weekly sync with the team to discuss progress and blockers",
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            type: .meeting,
            priority: .high,
            isCompleted: false,
            isSkipped: false,
            skipReason: nil,
            meetingLink: "https://example.com/meet",
            originalId: "1",
            originalType: "meeting",
            notes: nil,
            isRecurring: false,
            startHour: 14,
            startMinute: 30,
            endHour: 15,
            endMinute: 30
        )
    )
    .environmentObject(TaskManager.shared)
}
