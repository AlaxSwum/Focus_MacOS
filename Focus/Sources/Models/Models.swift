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
    var name: String?           // matches auth_user.name
    var role: String?           // matches auth_user.role  
    var position: String?       // matches auth_user.position
    var phone: String?          // matches auth_user.phone
    var isActive: Bool?         // matches auth_user.is_active
    var dateJoined: String?     // matches auth_user.date_joined
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case role
        case position
        case phone
        case isActive = "is_active"
        case dateJoined = "date_joined"
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
    var excludedDates: [String]?  // Dates to skip for recurring blocks
    var recurringEndDate: String? // End date for recurring blocks
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
        case excludedDates = "excluded_dates"
        case recurringEndDate = "recurring_end_date"
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
    var time: String?  // Made optional - could be null in DB
    var duration: Int?  // Made optional - could be null in DB
    var projectId: Int?
    var attendeeIds: [Int]?
    var meetingLink: String?
    var agendaItems: [String]?
    var notes: String?
    var location: String?
    var isCompleted: Bool?
    var userId: Int?
    var endTime_db: String?  // From database if exists
    var createdAt: String?
    var updatedAt: String?
    var isRecurring: Bool?
    var reminderTime: Int?
    var attendeesList: String?
    
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
        case userId = "user_id"
        case endTime_db = "end_time"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isRecurring = "is_recurring"
        case reminderTime = "reminder_time"
        case attendeesList = "attendees_list"
    }
    
    var startTime: Date? {
        guard let timeStr = time else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        // Handle time format with or without seconds
        let cleanTime = timeStr.count > 5 ? String(timeStr.prefix(5)) : timeStr
        return formatter.date(from: "\(date) \(cleanTime)")
    }
    
    var endTime: Date? {
        guard let start = startTime else { return nil }
        let dur = duration ?? 60  // Default 60 minutes
        return start.addingTimeInterval(Double(dur) * 60)
    }
    
    // Safe duration accessor
    var safeDuration: Int {
        duration ?? 60
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
    var date: Date  // Made mutable for day-change drag
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
    let isRecurring: Bool  // Whether this is a recurring task
    
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

// MARK: - Rule Book Models

/// Period type for rules
enum RulePeriod: String, Codable, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .yearly: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .daily: return .orange
        case .weekly: return .blue
        case .monthly: return .purple
        case .yearly: return .yellow
        }
    }
    
    var pointsMultiplier: Int {
        switch self {
        case .daily: return 1
        case .weekly: return 5
        case .monthly: return 20
        case .yearly: return 100
        }
    }
}

/// A single rule in the rule book
struct Rule: Codable, Identifiable, Hashable {
    var id: String
    var userId: Int
    var title: String
    var description: String?
    var period: RulePeriod
    var targetCount: Int  // How many times per period (e.g., 4 for "gym 4x/week")
    var currentCount: Int // Current progress this period
    var streakCount: Int  // Consecutive periods completed
    var bestStreak: Int   // Best streak ever
    var totalCompletions: Int // Total times completed all-time
    var totalPoints: Int  // Points earned from this rule
    var isActive: Bool
    var createdAt: Date
    var lastResetAt: Date
    var lastCompletedAt: Date?
    var emoji: String?    // Custom emoji for the rule
    var colorHex: String? // Custom color
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case period
        case targetCount = "target_count"
        case currentCount = "current_count"
        case streakCount = "streak_count"
        case bestStreak = "best_streak"
        case totalCompletions = "total_completions"
        case totalPoints = "total_points"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastResetAt = "last_reset_at"
        case lastCompletedAt = "last_completed_at"
        case emoji
        case colorHex = "color_hex"
    }
    
    var isCompletedForPeriod: Bool {
        currentCount >= targetCount
    }
    
    var progressPercentage: Double {
        guard targetCount > 0 else { return 0 }
        return min(Double(currentCount) / Double(targetCount) * 100, 100)
    }
    
    var pointsForCompletion: Int {
        period.pointsMultiplier * 10
    }
    
    var color: Color {
        if let hex = colorHex, let color = Color(hex: hex) {
            return color
        }
        return period.color
    }
    
    static func == (lhs: Rule, rhs: Rule) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Daily rule check record
struct RuleCheck: Codable, Identifiable {
    var id: String
    var ruleId: String
    var userId: Int
    var checkedAt: Date
    var periodStart: Date
    var periodEnd: Date
    var points: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case ruleId = "rule_id"
        case userId = "user_id"
        case checkedAt = "checked_at"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case points
    }
}

/// User's gamification stats
struct UserRuleStats: Codable {
    var userId: Int
    var totalPoints: Int
    var currentLevel: Int
    var totalRulesCompleted: Int
    var longestStreak: Int
    var currentDayStreak: Int
    var badges: [String]
    var lastActiveDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case totalPoints = "total_points"
        case currentLevel = "current_level"
        case totalRulesCompleted = "total_rules_completed"
        case longestStreak = "longest_streak"
        case currentDayStreak = "current_day_streak"
        case badges
        case lastActiveDate = "last_active_date"
    }
    
    var levelName: String {
        switch currentLevel {
        case 0...2: return "Rookie"
        case 3...5: return "Beginner"
        case 6...9: return "Apprentice"
        case 10...14: return "Rising Star"
        case 15...19: return "Achiever"
        case 20...29: return "Pro"
        case 30...39: return "Expert"
        case 40...49: return "Master"
        case 50...59: return "Grandmaster"
        case 60...74: return "Champion"
        case 75...89: return "Legend"
        case 90...99: return "Mythic"
        case 100...149: return "Immortal"
        case 150...199: return "Titan"
        default: return "God Tier"
        }
    }
    
    var levelColor: Color {
        switch currentLevel {
        case 0...2: return .gray
        case 3...5: return .mint
        case 6...9: return .green
        case 10...14: return .teal
        case 15...19: return .cyan
        case 20...29: return .blue
        case 30...39: return .indigo
        case 40...49: return .purple
        case 50...59: return .pink
        case 60...74: return .orange
        case 75...89: return .red
        case 90...99: return .yellow
        case 100...149: return Color(red: 1, green: 0.84, blue: 0) // Gold
        case 150...199: return Color(red: 0.9, green: 0.9, blue: 1) // Platinum
        default: return Color(red: 1, green: 0.5, blue: 0.8) // God Tier Pink/Gold
        }
    }
    
    var levelIcon: String {
        switch currentLevel {
        case 0...2: return "person.fill"
        case 3...5: return "star"
        case 6...9: return "star.fill"
        case 10...14: return "sparkle"
        case 15...19: return "bolt.fill"
        case 20...29: return "flame"
        case 30...39: return "flame.fill"
        case 40...49: return "crown"
        case 50...59: return "crown.fill"
        case 60...74: return "trophy"
        case 75...89: return "trophy.fill"
        case 90...99: return "sparkles"
        case 100...149: return "seal.fill"
        case 150...199: return "diamond.fill"
        default: return "wand.and.stars"
        }
    }
    
    var pointsToNextLevel: Int {
        let nextLevel = currentLevel + 1
        return nextLevel * 100 - totalPoints
    }
    
    var levelProgress: Double {
        let currentLevelPoints = currentLevel * 100
        let nextLevelPoints = (currentLevel + 1) * 100
        let progressPoints = totalPoints - currentLevelPoints
        let neededPoints = nextLevelPoints - currentLevelPoints
        return Double(progressPoints) / Double(neededPoints) * 100
    }
}

/// Badge definition
struct Badge: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let requirement: String
    
    static let allBadges: [Badge] = [
        Badge(id: "first_rule", name: "Rule Maker", description: "Create your first rule", icon: "star.fill", color: .yellow, requirement: "Create 1 rule"),
        Badge(id: "week_warrior", name: "Week Warrior", description: "Complete all rules for a week", icon: "flame.fill", color: .orange, requirement: "7 day streak"),
        Badge(id: "month_master", name: "Month Master", description: "Complete all rules for a month", icon: "crown.fill", color: .purple, requirement: "30 day streak"),
        Badge(id: "century", name: "Century", description: "Earn 100 points", icon: "100.circle.fill", color: .blue, requirement: "100 points"),
        Badge(id: "thousand", name: "Thousand Club", description: "Earn 1000 points", icon: "bolt.fill", color: .yellow, requirement: "1000 points"),
        Badge(id: "perfectionist", name: "Perfectionist", description: "Complete all daily rules 10 times", icon: "checkmark.seal.fill", color: .green, requirement: "10 perfect days"),
        Badge(id: "consistent", name: "Consistent", description: "Maintain a 14 day streak", icon: "repeat.circle.fill", color: .mint, requirement: "14 day streak"),
        Badge(id: "dedicated", name: "Dedicated", description: "Use the app for 30 days", icon: "heart.fill", color: .red, requirement: "30 days active"),
    ]
}

// MARK: - Journal Models

/// Energy mode for the day
enum EnergyMode: String, Codable, CaseIterable {
    case push = "Push"
    case maintain = "Maintain"
    case recover = "Recover"
    
    var icon: String {
        switch self {
        case .push: return "flame.fill"
        case .maintain: return "equal.circle.fill"
        case .recover: return "leaf.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .push: return .orange
        case .maintain: return .blue
        case .recover: return .green
        }
    }
}

/// Journal entry for daily reflection
struct JournalEntry: Codable, Identifiable {
    var id: String
    var userId: Int
    var date: Date
    var createdAt: Date
    var updatedAt: Date
    
    // 1. Intent Section
    var topOutcomes: [String]  // Top 3 outcomes
    var mustNotHappen: String
    var energyMode: EnergyMode
    var mainConstraint: String
    
    // 2. Daily Facts Section
    var sleepHours: Double?
    var sleepQuality: Int?  // 1-5
    var workBlocks: String
    var keyActions: String
    var movement: String
    var foodNote: String
    var distractionNote: String
    var moneyNote: String
    
    // 3. Execution Review Section
    var plannedVsDid: String
    var biggestWin: String
    var biggestMiss: String
    var rootCause: String
    var fixForTomorrow: String
    
    // 4. Mind & Emotion Section
    var dominantEmotion: String
    var emotionTrigger: String
    var automaticReaction: String
    var betterResponse: String
    
    // 5. Learning Section
    var oneLearned: String
    var learningSource: String
    var howToApply: String
    
    // 6. System Improvement Section
    var systemFailed: String
    var whyFailed: String
    var systemFix: String
    
    // Linked data (auto-populated)
    var completedTaskIds: [String]
    var missedTaskIds: [String]
    var completedRuleIds: [String]
    var missedRuleIds: [String]
    
    // Rich content
    var freeformNotes: String  // Rich text / markdown
    var imageUrls: [String]
    var tags: [String]
    
    // Gamification
    var pointsEarned: Int
    var streak: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case topOutcomes = "top_outcomes"
        case mustNotHappen = "must_not_happen"
        case energyMode = "energy_mode"
        case mainConstraint = "main_constraint"
        case sleepHours = "sleep_hours"
        case sleepQuality = "sleep_quality"
        case workBlocks = "work_blocks"
        case keyActions = "key_actions"
        case movement
        case foodNote = "food_note"
        case distractionNote = "distraction_note"
        case moneyNote = "money_note"
        case plannedVsDid = "planned_vs_did"
        case biggestWin = "biggest_win"
        case biggestMiss = "biggest_miss"
        case rootCause = "root_cause"
        case fixForTomorrow = "fix_for_tomorrow"
        case dominantEmotion = "dominant_emotion"
        case emotionTrigger = "emotion_trigger"
        case automaticReaction = "automatic_reaction"
        case betterResponse = "better_response"
        case oneLearned = "one_learned"
        case learningSource = "learning_source"
        case howToApply = "how_to_apply"
        case systemFailed = "system_failed"
        case whyFailed = "why_failed"
        case systemFix = "system_fix"
        case completedTaskIds = "completed_task_ids"
        case missedTaskIds = "missed_task_ids"
        case completedRuleIds = "completed_rule_ids"
        case missedRuleIds = "missed_rule_ids"
        case freeformNotes = "freeform_notes"
        case imageUrls = "image_urls"
        case tags
        case pointsEarned = "points_earned"
        case streak
    }
    
    // Empty entry for today
    static func newEntry(userId: Int, date: Date = Date()) -> JournalEntry {
        JournalEntry(
            id: UUID().uuidString,
            userId: userId,
            date: date,
            createdAt: Date(),
            updatedAt: Date(),
            topOutcomes: ["", "", ""],
            mustNotHappen: "",
            energyMode: .maintain,
            mainConstraint: "",
            sleepHours: nil,
            sleepQuality: nil,
            workBlocks: "",
            keyActions: "",
            movement: "",
            foodNote: "",
            distractionNote: "",
            moneyNote: "",
            plannedVsDid: "",
            biggestWin: "",
            biggestMiss: "",
            rootCause: "",
            fixForTomorrow: "",
            dominantEmotion: "",
            emotionTrigger: "",
            automaticReaction: "",
            betterResponse: "",
            oneLearned: "",
            learningSource: "",
            howToApply: "",
            systemFailed: "",
            whyFailed: "",
            systemFix: "",
            completedTaskIds: [],
            missedTaskIds: [],
            completedRuleIds: [],
            missedRuleIds: [],
            freeformNotes: "",
            imageUrls: [],
            tags: [],
            pointsEarned: 0,
            streak: 0
        )
    }
    
    var isComplete: Bool {
        // Entry is complete if at least the intent section and one other is filled
        let hasIntent = !topOutcomes.filter { !$0.isEmpty }.isEmpty || !mustNotHappen.isEmpty
        let hasFacts = sleepHours != nil || !workBlocks.isEmpty || !keyActions.isEmpty
        let hasReview = !biggestWin.isEmpty || !biggestMiss.isEmpty
        let hasEmotion = !dominantEmotion.isEmpty
        let hasLearning = !oneLearned.isEmpty
        
        return hasIntent && (hasFacts || hasReview || hasEmotion || hasLearning)
    }
    
    var completionPercentage: Double {
        var filled = 0
        var total = 20
        
        // Intent (4 fields)
        if !topOutcomes.filter({ !$0.isEmpty }).isEmpty { filled += 1 }
        if !mustNotHappen.isEmpty { filled += 1 }
        if !mainConstraint.isEmpty { filled += 1 }
        filled += 1  // energyMode always has value
        
        // Facts (7 fields)
        if sleepHours != nil { filled += 1 }
        if !workBlocks.isEmpty { filled += 1 }
        if !keyActions.isEmpty { filled += 1 }
        if !movement.isEmpty { filled += 1 }
        if !foodNote.isEmpty { filled += 1 }
        if !distractionNote.isEmpty { filled += 1 }
        if !moneyNote.isEmpty { filled += 1 }
        
        // Review (5 fields)
        if !plannedVsDid.isEmpty { filled += 1 }
        if !biggestWin.isEmpty { filled += 1 }
        if !biggestMiss.isEmpty { filled += 1 }
        if !rootCause.isEmpty { filled += 1 }
        if !fixForTomorrow.isEmpty { filled += 1 }
        
        // Emotion (4 fields)
        total += 4
        if !dominantEmotion.isEmpty { filled += 1 }
        if !emotionTrigger.isEmpty { filled += 1 }
        if !automaticReaction.isEmpty { filled += 1 }
        if !betterResponse.isEmpty { filled += 1 }
        
        // Learning (3 fields)
        total += 3
        if !oneLearned.isEmpty { filled += 1 }
        if !learningSource.isEmpty { filled += 1 }
        if !howToApply.isEmpty { filled += 1 }
        
        // System (3 fields)
        total += 3
        if !systemFailed.isEmpty { filled += 1 }
        if !whyFailed.isEmpty { filled += 1 }
        if !systemFix.isEmpty { filled += 1 }
        
        return Double(filled) / Double(total) * 100
    }
}

/// Journal statistics
struct JournalStats: Codable {
    var userId: Int
    var totalEntries: Int
    var currentStreak: Int
    var longestStreak: Int
    var totalPoints: Int
    var averageCompletion: Double
    var lastEntryDate: Date?
    
    static func empty(userId: Int) -> JournalStats {
        JournalStats(
            userId: userId,
            totalEntries: 0,
            currentStreak: 0,
            longestStreak: 0,
            totalPoints: 0,
            averageCompletion: 0,
            lastEntryDate: nil
        )
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
