//
//  MeetingsView.swift
//  Focus
//
//  Meetings list view - Today first, Tomorrow available
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MeetingsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDateFilter: DateFilter = .today
    @State private var selectedStatusFilter: StatusFilter = .all
    @State private var selectedMeeting: TaskItem?
    @State private var showingCalendarSheet = false
    
    enum DateFilter: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
    }
    
    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case completed = "Done"
    }
    
    private var allMeetings: [TaskItem] {
        taskManager.todayTasks.filter { $0.type == .meeting }
    }
    
    private var filteredMeetings: [TaskItem] {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: todayStart)!
        
        // First filter by date
        var dateFiltered: [TaskItem]
        switch selectedDateFilter {
        case .today:
            dateFiltered = allMeetings.filter { meeting in
                let meetingDate = calendar.startOfDay(for: meeting.date)
                return meetingDate >= todayStart && meetingDate < tomorrowStart
            }
        case .tomorrow:
            dateFiltered = allMeetings.filter { meeting in
                let meetingDate = calendar.startOfDay(for: meeting.date)
                return meetingDate >= tomorrowStart && meetingDate < dayAfterTomorrow
            }
        }
        
        // Then filter by status
        switch selectedStatusFilter {
        case .all:
            return dateFiltered.sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
        case .upcoming:
            return dateFiltered.filter { !$0.isCompleted && !$0.isSkipped }
                .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
        case .completed:
            return dateFiltered.filter { $0.isCompleted || $0.isSkipped }
                .sorted { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
        }
    }
    
    private var todayMeetingsCount: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        return allMeetings.filter { meeting in
            let meetingDate = calendar.startOfDay(for: meeting.date)
            return meetingDate >= todayStart && meetingDate < tomorrowStart
        }.count
    }
    
    private var tomorrowMeetingsCount: Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: todayStart)!
        return allMeetings.filter { meeting in
            let meetingDate = calendar.startOfDay(for: meeting.date)
            return meetingDate >= tomorrowStart && meetingDate < dayAfterTomorrow
        }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            // Date filter tabs
            dateFilterTabs
            
            // Status filter
            statusFilterPicker
            
            // Stats for selected date
            meetingStats
            
            // Meeting list
            if filteredMeetings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredMeetings) { meeting in
                            meetingCard(meeting)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .sheet(item: $selectedMeeting) { meeting in
            MeetingDetailSheet(meeting: meeting)
                .environmentObject(taskManager)
        }
        .sheet(isPresented: $showingCalendarSheet) {
            PersonalCalendarView()
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meetings")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Open Calendar
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    private var headerSubtitle: String {
        switch selectedDateFilter {
        case .today:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: Date())
        case .tomorrow:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: tomorrow)
        }
    }
    
    // MARK: - Date Filter Tabs
    private var dateFilterTabs: some View {
        HStack(spacing: 8) {
            dateTab(.today, count: todayMeetingsCount)
            dateTab(.tomorrow, count: tomorrowMeetingsCount)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private func dateTab(_ filter: DateFilter, count: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.25)) {
                selectedDateFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.rawValue)
                    .font(.system(size: 12, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        selectedDateFilter == filter
                            ? Color.white.opacity(0.3)
                            : Color.secondary.opacity(0.2)
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                selectedDateFilter == filter
                    ? Color.purple
                    : Color.secondary.opacity(0.1)
            )
            .foregroundColor(selectedDateFilter == filter ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Status Filter
    private var statusFilterPicker: some View {
        Picker("Status", selection: $selectedStatusFilter) {
            ForEach(StatusFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private var meetingStats: some View {
        HStack(spacing: 8) {
            let meetings = filteredMeetings
            let pending = meetings.filter { !$0.isCompleted && !$0.isSkipped }.count
            let done = meetings.filter { $0.isCompleted }.count
            
            statItem(value: "\(meetings.count)", label: "TOTAL", color: .purple)
            statItem(value: "\(pending)", label: "PENDING", color: .orange)
            statItem(value: "\(done)", label: "DONE", color: .green)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func meetingCard(_ meeting: TaskItem) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                Task { await taskManager.toggleComplete(task: meeting) }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(meeting.isCompleted ? Color.green : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if meeting.isCompleted {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Icon
            ZStack {
                Circle()
                    .fill(meeting.type.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: meeting.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(meeting.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .semibold))
                    .strikethrough(meeting.isCompleted || meeting.isSkipped)
                    .foregroundColor(meeting.isCompleted || meeting.isSkipped ? .secondary : .primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Time
                    if !meeting.timeText.isEmpty {
                        Label(meeting.timeText, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Meeting link indicator
                if meeting.meetingLink != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text("Has link")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Join meeting button if has link
            if let link = meeting.meetingLink, !link.isEmpty {
                Button {
                    if let url = URL(string: link) {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Detail arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(meeting.isCompleted ? Color.green.opacity(0.05) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(meeting.isCompleted ? Color.green.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            selectedMeeting = meeting
        }
        .contextMenu {
            Button(meeting.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                Task { await taskManager.toggleComplete(task: meeting) }
            }
            
            if let link = meeting.meetingLink, !link.isEmpty {
                Button("Join Meeting") {
                    if let url = URL(string: link) {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }
            }
            
            if !meeting.isSkipped {
                Divider()
                Button("Skip Meeting") {
                    taskManager.skipTask(meeting, reason: nil)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if selectedDateFilter == .today {
                Button("Check Tomorrow") {
                    withAnimation {
                        selectedDateFilter = .tomorrow
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateMessage: String {
        switch selectedDateFilter {
        case .today:
            return "No meetings scheduled for today"
        case .tomorrow:
            return "No meetings scheduled for tomorrow"
        }
    }
    
    private func refreshData() {
        if let userId = authManager.currentUser?.id {
            Task {
                await taskManager.fetchTasks(for: userId)
            }
        }
    }
}

// MARK: - Meeting Detail Sheet
struct MeetingDetailSheet: View {
    let meeting: TaskItem
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(meeting.type.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: meeting.type.icon)
                        .font(.title2)
                        .foregroundColor(meeting.type.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meeting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(meeting.title)
                        .font(.title3)
                        .fontWeight(.bold)
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
            
            // Date & Time
            HStack(spacing: 16) {
                Label {
                    let dateFormatter = DateFormatter()
                    let _ = dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
                    Text(dateFormatter.string(from: meeting.date))
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.subheadline)
            }
            
            if !meeting.timeText.isEmpty {
                Label(meeting.timeText, systemImage: "clock")
                    .font(.subheadline)
            }
            
            // Description
            if let description = meeting.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.body)
                }
            }
            
            // Meeting Link
            if let link = meeting.meetingLink, !link.isEmpty {
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
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            
            Spacer()
            
            // Status
            HStack {
                if meeting.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if meeting.isSkipped {
                    Label("Skipped", systemImage: "forward.fill")
                        .foregroundColor(.orange)
                } else {
                    Label("Pending", systemImage: "clock")
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button {
                    Task {
                        await taskManager.toggleComplete(task: meeting)
                        dismiss()
                    }
                } label: {
                    Text(meeting.isCompleted ? "Mark Incomplete" : "Mark Complete")
                }
                .buttonStyle(.bordered)
                .tint(meeting.isCompleted ? .gray : .green)
            }
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 350)
    }
}

#Preview {
    MeetingsView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
        .frame(width: 380, height: 600)
}
