//
//  TaskManager.swift
//  Focus
//
//  Manages tasks, time blocks, meetings from Supabase
//

import Foundation
import SwiftUI

@MainActor
class TaskManager: ObservableObject {
    static let shared = TaskManager()
    
    @Published var timeBlocks: [TimeBlock] = []
    @Published var meetings: [Meeting] = []
    @Published var todos: [PersonalTodo] = []
    @Published var todayTasks: [TaskItem] = []
    @Published var upcomingTasks: [TaskItem] = []
    @Published var completedTasks: [TaskItem] = []
    @Published var skippedTasks: Set<String> = []
    @Published var skipReasons: [String: String] = [:]
    
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    @Published var pauseAutoRefresh = false  // Pause during drag operations
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    private var refreshTimer: Timer?
    private var pendingLocalUpdates: Set<String> = []  // Track tasks being edited
    
    // MARK: - Computed Properties
    
    var completedTodayCount: Int {
        todayTasks.filter { $0.isCompleted }.count
    }
    
    var upcomingCount: Int {
        todayTasks.filter { $0.isUpcoming && !$0.isCompleted }.count
    }
    
    var currentTask: TaskItem? {
        todayTasks.first { $0.isNow && !$0.isCompleted }
    }
    
    var nextTask: TaskItem? {
        todayTasks.first { $0.isUpcoming && !$0.isCompleted }
    }
    
    var meetingsCount: Int {
        todayTasks.filter { $0.type == .meeting }.count
    }
    
    var blocksCount: Int {
        todayTasks.filter { 
            if case .timeBlock(_) = $0.type { return true }
            return false
        }.count
    }
    
    // MARK: - Public Methods
    
    func fetchTasks(for userId: Int) async {
        isLoading = true
        
        let today = DateFormatter.dateFormatter.string(from: Date())
        let dayOfWeek = Calendar.current.component(.weekday, from: Date()) - 1 // 0 = Sunday
        
        async let blocksResult = fetchTimeBlocks(userId: userId, date: today, dayOfWeek: dayOfWeek)
        async let meetingsResult = fetchMeetings(userId: userId, date: today)
        async let todosResult = fetchTodos(userId: userId)
        
        let (blocks, mtgs, tds) = await (blocksResult, meetingsResult, todosResult)
        
        self.timeBlocks = blocks
        self.meetings = mtgs
        self.todos = tds
        
        // Process into unified task items
        processTasks(date: today)
        
        isLoading = false
        lastRefresh = Date()
        
        // Schedule notifications for upcoming tasks
        NotificationManager.shared.scheduleNotifications(for: todayTasks)
        
        // Start auto-refresh
        startAutoRefresh(userId: userId)
    }
    
    func toggleComplete(task: TaskItem) async {
        // Calculate new completion state BEFORE toggling local state
        let newCompletedState = !task.isCompleted
        
        // Update local state immediately
        if let index = todayTasks.firstIndex(where: { $0.id == task.id }) {
            todayTasks[index].isCompleted = newCompletedState
        }
        
        // Update in database with the NEW state
        await updateTaskCompletion(task: task, completed: newCompletedState)
    }
    
    func skipTask(_ task: TaskItem, reason: String?) {
        skippedTasks.insert(task.id)
        if let reason = reason, !reason.isEmpty {
            skipReasons[task.id] = reason
        }
        
        // Update local state
        if let index = todayTasks.firstIndex(where: { $0.id == task.id }) {
            todayTasks[index].isSkipped = true
            todayTasks[index].skipReason = reason
        }
        
        // Save to database (fire and forget)
        Task {
            await saveSkippedTask(task: task, reason: reason)
        }
    }
    
    func unskipTask(_ task: TaskItem) {
        skippedTasks.remove(task.id)
        skipReasons.removeValue(forKey: task.id)
        
        // Update local state
        if let index = todayTasks.firstIndex(where: { $0.id == task.id }) {
            todayTasks[index].isSkipped = false
            todayTasks[index].skipReason = nil
        }
        
        // Remove from database (fire and forget)
        Task {
            await removeSkippedTask(taskId: task.id)
        }
    }
    
    func deleteTask(_ task: TaskItem) async {
        // Remove from local state immediately with animation
        if let index = todayTasks.firstIndex(where: { $0.id == task.id }) {
            todayTasks.remove(at: index)
        }
        
        // Delete from database based on task type
        if task.originalType == "todo" {
            await deleteTodoFromDatabase(id: task.originalId)
        } else if task.originalType == "timeblock" {
            await deleteTimeBlockFromDatabase(id: task.id)
        }
    }
    
    private func deleteTodoFromDatabase(id: String) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos?id=eq.\(id)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Delete todo response: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to delete todo: \(error)")
        }
    }
    
    private func deleteTimeBlockFromDatabase(id: String) async {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks?id=eq.\(id)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Delete time block response: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to delete time block: \(error)")
        }
    }
    
    func clearTasks() {
        timeBlocks = []
        meetings = []
        todos = []
        todayTasks = []
        upcomingTasks = []
        completedTasks = []
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Local Updates (for immediate UI feedback)
    
    func updateTaskEndTimeLocally(taskId: String, newEndHour: Int, newEndMinute: Int) {
        if let index = todayTasks.firstIndex(where: { $0.id == taskId }) {
            let task = todayTasks[index]
            todayTasks[index] = TaskItem(
                id: task.id,
                title: task.title,
                description: task.description,
                date: task.date,
                startTime: task.startTime,
                endTime: task.endTime,
                type: task.type,
                priority: task.priority,
                isCompleted: task.isCompleted,
                isSkipped: task.isSkipped,
                skipReason: task.skipReason,
                meetingLink: task.meetingLink,
                originalId: task.originalId,
                originalType: task.originalType,
                notes: task.notes,
                startHour: task.startHour,
                startMinute: task.startMinute,
                endHour: newEndHour,
                endMinute: newEndMinute
            )
        }
    }
    
    func updateTaskTimesLocally(taskId: String, newStartHour: Int, newStartMinute: Int, newEndHour: Int, newEndMinute: Int) {
        if let index = todayTasks.firstIndex(where: { $0.id == taskId }) {
            let task = todayTasks[index]
            todayTasks[index] = TaskItem(
                id: task.id,
                title: task.title,
                description: task.description,
                date: task.date,
                startTime: task.startTime,
                endTime: task.endTime,
                type: task.type,
                priority: task.priority,
                isCompleted: task.isCompleted,
                isSkipped: task.isSkipped,
                skipReason: task.skipReason,
                meetingLink: task.meetingLink,
                originalId: task.originalId,
                originalType: task.originalType,
                notes: task.notes,
                startHour: newStartHour,
                startMinute: newStartMinute,
                endHour: newEndHour,
                endMinute: newEndMinute
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchTimeBlocks(userId: Int, date: String, dayOfWeek: Int) async -> [TimeBlock] {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = dateFormatter.date(from: date) ?? Date()
            
            // Calculate date range for the week (past 7 days + next 7 days)
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: today)!
            let weekAgoStr = dateFormatter.string(from: weekAgo)
            let weekLaterStr = dateFormatter.string(from: weekLater)
            
            // Fetch blocks for the entire 2-week range
            let rangeURL = URL(string: "\(supabaseURL)/rest/v1/time_blocks?user_id=eq.\(userId)&date=gte.\(weekAgoStr)&date=lte.\(weekLaterStr)&select=*")!
            let rangeBlocks = try await fetchFromSupabase(url: rangeURL, type: [TimeBlock].self) ?? []
            
            // Fetch recurring blocks
            let recurringURL = URL(string: "\(supabaseURL)/rest/v1/time_blocks?user_id=eq.\(userId)&is_recurring=eq.true&select=*")!
            let recurringBlocks = try await fetchFromSupabase(url: recurringURL, type: [TimeBlock].self) ?? []
            
            // Expand recurring blocks for each day in the range
            var expandedRecurring: [TimeBlock] = []
            var currentDate = weekAgo
            while currentDate <= weekLater {
                let currentDayOfWeek = Calendar.current.component(.weekday, from: currentDate) - 1
                let currentDateStr = dateFormatter.string(from: currentDate)
                
                for block in recurringBlocks {
                    if let days = block.recurringDays, days.contains(currentDayOfWeek) {
                        var expanded = block
                        expanded.date = currentDateStr
                        // Create unique ID for this recurring instance
                        expanded.id = "\(block.id)-\(currentDateStr)"
                        expandedRecurring.append(expanded)
                    }
                }
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            // Merge and deduplicate (prefer specific date blocks over recurring)
            var blockDict: [String: TimeBlock] = [:]
            for block in expandedRecurring {
                let key = "\(block.date)-\(block.title)-\(block.startTime)"
                blockDict[key] = block
            }
            for block in rangeBlocks {
                let key = "\(block.date)-\(block.title)-\(block.startTime)"
                blockDict[key] = block // Override recurring with specific
            }
            
            let result = Array(blockDict.values)
            print("Fetched \(result.count) time blocks for week view")
            return result
        } catch {
            print("Failed to fetch time blocks: \(error)")
            return []
        }
    }
    
    private func fetchMeetings(userId: Int, date: String) async -> [Meeting] {
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let today = dateFormatter.date(from: date) ?? Date()
            
            // Fetch meetings where user is creator OR is in attendees
            // Using OR filter: user_id=eq.{userId} or attendee_ids=cs.{[userId]}
            let allUrl = URL(string: "\(supabaseURL)/rest/v1/projects_meeting?or=(user_id.eq.\(userId),attendee_ids.cs.%7B\(userId)%7D)&select=*&order=date.desc")!
            
            var request = URLRequest(url: allUrl)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Meetings API response status: \(httpResponse.statusCode)")
            }
            
            // Debug: Print raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Meetings raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let allMeetings = try decoder.decode([Meeting].self, from: data)
                print("Successfully decoded \(allMeetings.count) meetings for user \(userId)")
                
                // Filter by date range AND ensure user access (double-check in code)
                let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: today)!
                let futureDate = Calendar.current.date(byAdding: .day, value: 90, to: today)!
                
                let filtered = allMeetings.filter { meeting in
                    // Check date range
                    guard let meetingDate = dateFormatter.date(from: meeting.date) else { return false }
                    let inDateRange = meetingDate >= monthAgo && meetingDate <= futureDate
                    
                    // Check user access: user created it OR user is in attendees
                    let isCreator = meeting.userId == userId
                    let isAttendee = meeting.attendeeIds?.contains(userId) ?? false
                    let hasAccess = isCreator || isAttendee
                    
                    return inDateRange && hasAccess
                }
                
                print("After filtering: \(filtered.count) meetings accessible to user \(userId)")
                return filtered
            } catch let decodingError {
                print("Meeting decoding error: \(decodingError)")
                
                // Try manual parsing as fallback
                if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("Raw JSON has \(jsonArray.count) items - trying manual parsing")
                    if let first = jsonArray.first {
                        print("First meeting keys: \(first.keys)")
                    }
                    
                    var manualMeetings: [Meeting] = []
                    for item in jsonArray {
                        if let id = item["id"] as? Int,
                           let title = item["title"] as? String,
                           let date = item["date"] as? String {
                            let meeting = Meeting(
                                id: id,
                                title: title,
                                description: item["description"] as? String,
                                date: date,
                                time: item["time"] as? String,
                                duration: item["duration"] as? Int,
                                projectId: item["project_id"] as? Int,
                                attendeeIds: item["attendee_ids"] as? [Int],
                                meetingLink: item["meeting_link"] as? String,
                                agendaItems: item["agenda_items"] as? [String],
                                notes: item["notes"] as? String,
                                location: item["location"] as? String,
                                isCompleted: item["completed"] as? Bool,
                                userId: item["user_id"] as? Int,
                                endTime_db: item["end_time"] as? String,
                                createdAt: item["created_at"] as? String,
                                updatedAt: item["updated_at"] as? String,
                                isRecurring: item["is_recurring"] as? Bool,
                                reminderTime: item["reminder_time"] as? Int,
                                attendeesList: item["attendees_list"] as? String
                            )
                            manualMeetings.append(meeting)
                        }
                    }
                    
                    print("Manually parsed \(manualMeetings.count) meetings")
                    
                    // Filter by date range AND user access
                    let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: today)!
                    let futureDate = Calendar.current.date(byAdding: .day, value: 90, to: today)!
                    
                    let filtered = manualMeetings.filter { meeting in
                        // Check date range
                        guard let meetingDate = dateFormatter.date(from: meeting.date) else { return false }
                        let inDateRange = meetingDate >= monthAgo && meetingDate <= futureDate
                        
                        // Check user access: user created it OR user is in attendees
                        let isCreator = meeting.userId == userId
                        let isAttendee = meeting.attendeeIds?.contains(userId) ?? false
                        let hasAccess = isCreator || isAttendee
                        
                        return inDateRange && hasAccess
                    }
                    
                    print("After filtering: \(filtered.count) meetings accessible to user \(userId)")
                    return filtered
                }
                return []
            }
        } catch {
            print("Failed to fetch meetings: \(error)")
            return []
        }
    }
    
    private func fetchTodos(userId: Int) async -> [PersonalTodo] {
        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos?user_id=eq.\(userId)&select=*")!
            return try await fetchFromSupabase(url: url, type: [PersonalTodo].self) ?? []
        } catch {
            print("Failed to fetch todos: \(error)")
            return []
        }
    }
    
    private func fetchFromSupabase<T: Decodable>(url: URL, type: T.Type) async throws -> T? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
    
    private func processTasks(date: String) {
        var items: [TaskItem] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.date(from: date) ?? Date()
        
        // Convert time blocks - use each block's own date
        for block in timeBlocks {
            let blockDate: Date
            if let parsedDate = dateFormatter.date(from: block.date) {
                blockDate = parsedDate
            } else {
                blockDate = today
            }
            if let item = createTaskItem(from: block, date: blockDate) {
                items.append(item)
            }
        }
        
        // Convert meetings - include all meetings for display
        for meeting in meetings {
            // Parse meeting date
            if let meetingDate = dateFormatter.date(from: meeting.date) {
                if let item = createTaskItem(from: meeting, date: meetingDate) {
                    items.append(item)
                }
            }
        }

        // Convert personal todos
        for todo in todos {
            if let item = createTaskItem(from: todo, date: today) {
                items.append(item)
            }
        }
        
        // Sort by date then start time
        items.sort { 
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            return ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture)
        }
        
        let timeBlockCount = items.filter { 
            if case .timeBlock(_) = $0.type { return true }
            return false
        }.count
        print("Processed \(items.count) total tasks: \(timeBlockCount) time blocks, \(items.filter { $0.type == .meeting }.count) meetings")
        
        todayTasks = items
        completedTasks = items.filter { $0.isCompleted }
        upcomingTasks = items.filter { $0.isUpcoming && !$0.isCompleted }
    }
    
    private func createTaskItem(from block: TimeBlock, date: Date) -> TaskItem? {
        // Parse raw hour/minute directly from time strings
        guard let (startHour, startMinute) = parseTimeComponents(block.startTime),
              let (endHour, endMinute) = parseTimeComponents(block.endTime) else {
            return nil
        }
        
        return TaskItem(
            id: block.id,
            title: block.title,
            description: block.description,
            date: date,
            startTime: nil,
            endTime: nil,
            type: .timeBlock(block.type),
            priority: .normal,
            isCompleted: block.isCompleted,
            isSkipped: skippedTasks.contains(block.id),
            skipReason: skipReasons[block.id],
            meetingLink: block.meetingLink,
            originalId: block.id,
            originalType: "timeblock",
            notes: nil,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
    }
    
    private func createTaskItem(from meeting: Meeting, date: Date) -> TaskItem? {
        // Handle optional time - default to 09:00 if not set
        var startHour = 9
        var startMinute = 0
        
        if let timeStr = meeting.time, let (h, m) = parseTimeComponents(timeStr) {
            startHour = h
            startMinute = m
        }
        
        // Calculate end time from duration (use safeDuration which defaults to 60)
        let totalMinutes = startHour * 60 + startMinute + meeting.safeDuration
        let endHour = (totalMinutes / 60) % 24
        let endMinute = totalMinutes % 60
        
        return TaskItem(
            id: "meeting-\(meeting.id)",
            title: meeting.title,
            description: meeting.description,
            date: date,
            startTime: nil,
            endTime: nil,
            type: .meeting,
            priority: .high,
            isCompleted: meeting.isCompleted ?? false,
            isSkipped: skippedTasks.contains("meeting-\(meeting.id)"),
            skipReason: skipReasons["meeting-\(meeting.id)"],
            meetingLink: meeting.meetingLink,
            originalId: String(meeting.id),
            originalType: "meeting",
            notes: meeting.notes,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
    }

    private func createTaskItem(from todo: PersonalTodo, date: Date) -> TaskItem? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let baseDate = todo.startDate.flatMap { dateFormatter.date(from: $0) } ?? date
        
        // Parse time if available, default to 9 AM
        var startHour = 9
        var startMinute = 0
        if let timeStr = todo.startTime, let (h, m) = parseTimeComponents(timeStr) {
            startHour = h
            startMinute = m
        }

        return TaskItem(
            id: "todo-\(todo.id)",
            title: todo.taskName,
            description: todo.description,
            date: baseDate,
            startTime: nil,
            endTime: nil,
            type: .todo,
            priority: todo.priority,
            isCompleted: todo.isCompleted,
            isSkipped: skippedTasks.contains("todo-\(todo.id)"),
            skipReason: skipReasons["todo-\(todo.id)"],
            meetingLink: nil,
            originalId: todo.id,
            originalType: "todo",
            notes: nil,
            startHour: startHour,
            startMinute: startMinute,
            endHour: startHour + 1,
            endMinute: startMinute
        )
    }
    
    private func updateTaskCompletion(task: TaskItem, completed: Bool) async {
        // Determine the correct table and endpoint based on task type
        let tableName: String
        switch task.originalType {
        case "timeblock":
            tableName = "time_blocks"
        case "todo":
            tableName = "personal_todos"
        case "meeting":
            tableName = "projects_meeting"  // Fixed: was "meetings", should be "projects_meeting"
        default:
            print("Unknown task type: \(task.originalType), skipping database update")
            return
        }
        
        print("DEBUG: Updating \(tableName) id=\(task.originalId) completed=\(completed)")
        
        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(task.originalId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONEncoder().encode(["completed": completed])
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: \(tableName) update response: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    print("DEBUG: Response body: \(String(data: data, encoding: .utf8) ?? "none")")
                }
            }
        } catch {
            print("Failed to update task: \(error)")
        }
    }
    
    private func saveSkippedTask(task: TaskItem, reason: String?) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        let skipData: [String: Any] = [
            "user_id": userId,
            "task_id": task.originalId,
            "task_type": task.originalType,
            "task_title": task.title,
            "task_date": DateFormatter.dateFormatter.string(from: task.date),
            "skip_reason": reason ?? NSNull()
        ]

        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/focus_skipped_tasks")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: skipData)

            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to save skipped task: \(error)")
        }
    }
    
    private func removeSkippedTask(taskId: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        
        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/focus_skipped_tasks?user_id=eq.\(userId)&task_id=eq.\(taskId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to remove skipped task: \(error)")
        }
    }

    private func startAutoRefresh(userId: Int) {
        refreshTimer?.invalidate()
        // Refresh every 5 minutes instead of every minute to reduce interference with local edits
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // Skip refresh if there are pending local updates or refresh is paused
                if !self.pauseAutoRefresh && self.pendingLocalUpdates.isEmpty {
                    await self.fetchTasks(for: userId)
                } else {
                    print("Auto-refresh skipped: pauseAutoRefresh=\(self.pauseAutoRefresh), pending=\(self.pendingLocalUpdates.count)")
                }
            }
        }
    }
    
    // Call when starting a drag/resize operation
    func beginLocalEdit(taskId: String) {
        pendingLocalUpdates.insert(taskId)
    }
    
    // Call when drag/resize completes and database is updated
    func endLocalEdit(taskId: String) {
        pendingLocalUpdates.remove(taskId)
    }

    private func parseTimeComponents(_ value: String) -> (hour: Int, minute: Int)? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        let components = trimmed.components(separatedBy: ":")
        guard components.count >= 2,
              let hour = Int(components[0]),
              let minute = Int(components[1].prefix(2)) else {
            return nil
        }
        
        return (hour, minute)
    }
    
    private func parseTime(_ value: String) -> Date? {
        guard let (hour, minute) = parseTimeComponents(value) else { return nil }
        
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components)
    }
}
