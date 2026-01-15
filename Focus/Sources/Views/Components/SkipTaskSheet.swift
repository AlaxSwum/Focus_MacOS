//
//  SkipTaskSheet.swift
//  Focus
//
//  Sheet for skipping a task with reason
//

import SwiftUI

struct SkipTaskSheet: View {
    let task: TaskItem
    let onSkip: (String?) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var reason = ""
    @FocusState private var isReasonFocused: Bool
    
    // Quick reasons
    private let quickReasons = [
        "Not enough time",
        "Higher priority task",
        "Feeling unwell",
        "Waiting on someone",
        "Need more preparation",
        "Rescheduling for later"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Task info
                    taskInfoCard
                    
                    // Quick reasons
                    quickReasonsSection
                    
                    // Custom reason
                    customReasonSection
                    
                    // Skip button
                    skipButton
                }
                .padding()
            }
            .background(Color.systemGroupedBackground)
            .navigationTitle("Skip Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Task Info Card
    private var taskInfoCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(task.type.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: task.type.icon)
                    .font(.title2)
                    .foregroundColor(task.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                
                if !task.timeText.isEmpty {
                    Text(task.timeText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(task.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(task.type.color.opacity(0.15))
                    .foregroundColor(task.type.color)
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding()
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Quick Reasons
    private var quickReasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick reasons")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(quickReasons, id: \.self) { quickReason in
                    Button(action: {
                        reason = quickReason
                    }) {
                        Text(quickReason)
                            .font(.subheadline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                            .background(
                                reason == quickReason
                                    ? Color.orange.opacity(0.15)
                                    : Color.secondarySystemGroupedBackground
                            )
                            .foregroundColor(reason == quickReason ? .orange : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        reason == quickReason ? Color.orange : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Custom Reason
    private var customReasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or write your own")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            TextEditor(text: $reason)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.secondarySystemGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($isReasonFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isReasonFocused ? Color.orange : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .topLeading) {
                    if reason.isEmpty {
                        Text("Why are you skipping this task? (optional)")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    // MARK: - Skip Button
    private var skipButton: some View {
        Button(action: {
            onSkip(reason.isEmpty ? nil : reason)
            dismiss()
        }) {
            HStack {
                Image(systemName: "forward.fill")
                Text("Skip Task")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.orange.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

#Preview {
    SkipTaskSheet(
        task: TaskItem(
            id: "1",
            title: "Team Meeting",
            description: "Weekly sync",
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
            startHour: 14,
            startMinute: 30,
            endHour: 15,
            endMinute: 30
        )
    ) { reason in
        print("Skipped with reason: \(reason ?? "none")")
    }
}
