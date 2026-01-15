//
//  Models.swift
//  Focus
//
//  Data models for Focus app - syncs with Supabase database
//

import Foundation
import SwiftUI

// MARK: - User
struct User: Codable, Identifiable {
    let id: Int
    var email: String
    var fullName: String?
    var avatarUrl: String?
    var createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

// MARK: - Time Block
struct TimeBlock: Codable, Identifiable, Hashable {
    var id: String
    var userId: Int
    var date: String
    var startTime: String
    var endTime: String
    var title: String
    var description: String?
    var type: BlockType
    var category: String?
    var isCompleted: Bool
    var isRecurring: Bool
    var recurringDays: [Int]?
    var checklist: [ChecklistItem]?
    var meetingLink: String?
    var notificationTime: Int?
    var color: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case title
        case description
        case type
        case category
        case isCompleted = "completed"
        case isRecurring = "is_recurring"
        case recurringDays = "recurring_days"
        case checklist
        case meetingLink = "meeting_link"
        case notificationTime = "notification_time"
        case color
    }
    
    // Computed properties
    var startDate: Date? {
        DateFormatter.timeFormatter.date(from: startTime)
    }
    
    var endDate: Date? {
        DateFormatter.timeFormatter.date(from: endTime)
    }
    
    var duration: TimeInterval {
        guard let start = startDate, let end = endDate else { return 0 }
        return end.timeIntervalSince(start)
    }
    
    var durationText: String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
    
    var blockColor: Color {
        if let colorHex = color {
            return Color(hex: colorHex) ?? type.color
        }
        return type.color
    }
}

// MARK: - Block Type
enum BlockType: String, Codable, CaseIterable {
    case focus
    case meeting
    case personal
    case goal
    case project
    case routine
    case work
    case social
    case todo
    
    var color: Color {
        switch self {
        case .focus: return .blue
        case .meeting: return .purple
        case .personal: return .green
        case .goal: return .orange
        case .project: return .pink
        case .routine: return .teal
        case .work: return .indigo
        case .social: return .red
        case .todo: return .cyan
        }
    }
    
    var icon: String {
        switch self {
        case .focus: return "sparkles"
        case .meeting: return "video.fill"
        case .personal: return "person.fill"
        case .goal: return "flag.fill"
        case .project: return "folder.fill"
        case .routine: return "repeat"
        case .work: return "briefcase.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .todo: return "checklist"
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Checklist Item
struct ChecklistItem: Codable, Identifiable, Hashable {
    var id: String
    var text: String
    var isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case isCompleted = "completed"
    }
    
    init(id: String = UUID().uuidString, text: String, isCompleted: Bool = false) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
    }
}

// MARK: - Meeting
struct Meeting: Codable, Identifiable, Hashable {
    var id: Int
    var title: String
    var description: String?
    var date: String
    var time: String
    var duration: Int // minutes
    var projectId: Int?
    var attendeeIds: [Int]?
    var meetingLink: String?
    var agendaItems: [String]?
    var notes: String?
    var location: String?
    var isCompleted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case date
        case time
        case duration
        case projectId = "project_id"
        case attendeeIds = "attendee_ids"
        case meetingLink = "meeting_link"
        case agendaItems = "agenda_items"
        case notes
        case location
        case isCompleted = "completed"
    }
    
    var startTime: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(date) \(time)")
    }
    
    var endTime: Date? {
        guard let start = startTime else { return nil }
        return start.addingTimeInterval(Double(duration) * 60)
    }
}

// MARK: - Personal Todo
struct PersonalTodo: Codable, Identifiable, Hashable {
    var id: String
    var userId: String  // Changed to String to match Supabase
    var taskName: String
    var description: String?
    var deadline: String?
    var priority: Priority
    var isCompleted: Bool
    var startDate: String?
    var startTime: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskName = "task_name"
        case description
        case deadline
        case priority
        case isCompleted = "completed"
        case startDate = "start_date"
        case startTime = "start_time"
    }
    
    // Custom decoder to handle user_id as either Int or String
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        // Handle user_id as either Int or String
        if let intUserId = try? container.decode(Int.self, forKey: .userId) {
            userId = String(intUserId)
        } else {
            userId = try container.decode(String.self, forKey: .userId)
        }
        
        taskName = try container.decode(String.self, forKey: .taskName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        deadline = try container.decodeIfPresent(String.self, forKey: .deadline)
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .normal
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
    }
}

// MARK: - Priority
enum Priority: String, Codable, CaseIterable {
    case low
    case normal
    case high
    case urgent
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .normal: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .normal: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}

// MARK: - Task Type
enum TaskType: Hashable {
    case timeBlock(BlockType)
    case meeting
    case todo
    case social
    
    var color: Color {
        switch self {
        case .timeBlock(let blockType): return blockType.color
        case .meeting: return .purple
        case .todo: return .blue
        case .social: return .pink
        }
    }
    
    var icon: String {
        switch self {
        case .timeBlock(let blockType): return blockType.icon
        case .meeting: return "video.fill"
        case .todo: return "checkmark.circle"
        case .social: return "bubble.left.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .timeBlock(let blockType): return blockType.displayName
        case .meeting: return "Meeting"
        case .todo: return "Task"
        case .social: return "Social"
        }
    }
}

// MARK: - Task Item (Unified for display)
struct TaskItem: Identifiable, Hashable, Equatable {
    let id: String
    let title: String
    let description: String?
    let date: Date
    let startTime: Date?
    let endTime: Date?
    let type: TaskType
    let priority: Priority
    var isCompleted: Bool
    var isSkipped: Bool
    var skipReason: String?
    let meetingLink: String?
    let originalId: String
    let originalType: String
    let notes: String?
    
    // Raw hour/minute for positioning (avoids timezone issues)
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var timeText: String {
        let startStr = formatTime12Hour(hour: startHour, minute: startMinute)
        let endStr = formatTime12Hour(hour: endHour, minute: endMinute)
        return "\(startStr) - \(endStr)"
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
    
    var isUpcoming: Bool {
        guard let start = startTime else { return false }
        return start > Date()
    }
    
    var isNow: Bool {
        guard let start = startTime, let end = endTime else { return false }
        let now = Date()
        return now >= start && now <= end
    }
    
    var isPast: Bool {
        guard let end = endTime ?? startTime else { return false }
        return end < Date()
    }
}

// MARK: - Skipped Task
struct SkippedTask: Codable, Identifiable {
    var id: String
    var userId: Int
    var taskId: String
    var taskType: String
    var taskTitle: String
    var taskDate: String
    var skipReason: String?
    var skippedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case taskId = "task_id"
        case taskType = "task_type"
        case taskTitle = "task_title"
        case taskDate = "task_date"
        case skipReason = "skip_reason"
        case skippedAt = "skipped_at"
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    // Cross-platform system colors
    static var systemBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
    
    static var secondarySystemBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    static var systemGroupedBackground: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }
    
    static var secondarySystemGroupedBackground: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
    
    static var separator: Color {
        #if os(macOS)
        return Color(nsColor: .separatorColor)
        #else
        return Color(uiColor: .separator)
        #endif
    }
    
    static var systemGray6: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .systemGray6)
        #endif
    }
}
