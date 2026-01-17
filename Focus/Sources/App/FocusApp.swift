//
//  FocusApp.swift
//  Focus - Native macOS Menu Bar App
//
//  Menu bar dropdown with full app window support
//

import SwiftUI
import UserNotifications
#if os(macOS)
import AppKit
#endif

// MARK: - Rule Manager
@MainActor
class RuleManager: ObservableObject {
    static let shared = RuleManager()
    
    @Published var rules: [Rule] = []
    @Published var userStats: UserRuleStats = UserRuleStats(
        userId: 0,
        totalPoints: 0,
        currentLevel: 0,
        totalRulesCompleted: 0,
        longestStreak: 0,
        currentDayStreak: 0,
        badges: [],
        lastActiveDate: nil
    )
    @Published var isLoading = false
    @Published var showLevelUpAnimation = false
    @Published var newBadge: Badge? = nil
    
    private init() {
        loadFromLocalStorage()
    }
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: "focus_rules"),
           let savedRules = try? JSONDecoder().decode([Rule].self, from: data) {
            self.rules = savedRules
        }
        if let statsData = UserDefaults.standard.data(forKey: "focus_user_stats"),
           let savedStats = try? JSONDecoder().decode(UserRuleStats.self, from: statsData) {
            self.userStats = savedStats
        }
    }
    
    private func saveToLocalStorage() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: "focus_rules")
        }
        if let statsData = try? JSONEncoder().encode(userStats) {
            UserDefaults.standard.set(statsData, forKey: "focus_user_stats")
        }
    }
    
    var dailyRules: [Rule] { rules.filter { $0.period == .daily && $0.isActive } }
    var weeklyRules: [Rule] { rules.filter { $0.period == .weekly && $0.isActive } }
    var monthlyRules: [Rule] { rules.filter { $0.period == .monthly && $0.isActive } }
    var yearlyRules: [Rule] { rules.filter { $0.period == .yearly && $0.isActive } }
    
    func addRule(title: String, description: String?, period: RulePeriod, targetCount: Int, emoji: String?, colorHex: String?, userId: Int) {
        let now = Date()
        let rule = Rule(
            id: UUID().uuidString, userId: userId, title: title, description: description,
            period: period, targetCount: max(1, targetCount), currentCount: 0,
            streakCount: 0, bestStreak: 0, totalCompletions: 0, totalPoints: 0,
            isActive: true, createdAt: now, lastResetAt: now, lastCompletedAt: nil,
            emoji: emoji, colorHex: colorHex
        )
        rules.append(rule)
        saveToLocalStorage()
    }
    
    func incrementRule(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updatedRule = rules[index]
        if updatedRule.currentCount < updatedRule.targetCount {
            updatedRule.currentCount += 1
            updatedRule.lastCompletedAt = Date()
            let points = 10 * updatedRule.period.pointsMultiplier
            updatedRule.totalPoints += points
            userStats.totalPoints += points
            
            if updatedRule.currentCount >= updatedRule.targetCount {
                updatedRule.streakCount += 1
                updatedRule.totalCompletions += 1
                userStats.totalRulesCompleted += 1
                if updatedRule.streakCount > updatedRule.bestStreak {
                    updatedRule.bestStreak = updatedRule.streakCount
                }
                let bonusPoints = updatedRule.pointsForCompletion
                updatedRule.totalPoints += bonusPoints
                userStats.totalPoints += bonusPoints
            }
            
            let oldLevel = userStats.currentLevel
            userStats.currentLevel = userStats.totalPoints / 100
            if userStats.currentLevel > oldLevel {
                showLevelUpAnimation = true
            }
            rules[index] = updatedRule
            saveToLocalStorage()
        }
    }
    
    func decrementRule(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var updatedRule = rules[index]
        if updatedRule.currentCount > 0 {
            // If was completed, reverse the completion bonus
            if updatedRule.currentCount >= updatedRule.targetCount {
                updatedRule.streakCount = max(0, updatedRule.streakCount - 1)
                userStats.totalRulesCompleted = max(0, userStats.totalRulesCompleted - 1)
                let bonusPoints = updatedRule.pointsForCompletion
                updatedRule.totalPoints = max(0, updatedRule.totalPoints - bonusPoints)
                userStats.totalPoints = max(0, userStats.totalPoints - bonusPoints)
            }
            
            // Decrement count and remove points
            updatedRule.currentCount -= 1
            let points = 10 * updatedRule.period.pointsMultiplier
            updatedRule.totalPoints = max(0, updatedRule.totalPoints - points)
            userStats.totalPoints = max(0, userStats.totalPoints - points)
            
            userStats.currentLevel = userStats.totalPoints / 100
            rules[index] = updatedRule
            saveToLocalStorage()
        }
    }
    
    func checkAndResetPeriods() {
        let now = Date()
        let calendar = Calendar.current
        
        for index in rules.indices {
            var rule = rules[index]
            var needsReset = false
            
            switch rule.period {
            case .daily:
                if !calendar.isDateInToday(rule.lastResetAt) { needsReset = true }
            case .weekly:
                let lastWeek = calendar.component(.weekOfYear, from: rule.lastResetAt)
                let currentWeek = calendar.component(.weekOfYear, from: now)
                if currentWeek != lastWeek { needsReset = true }
            case .monthly:
                let lastMonth = calendar.component(.month, from: rule.lastResetAt)
                let currentMonth = calendar.component(.month, from: now)
                if currentMonth != lastMonth { needsReset = true }
            case .yearly:
                let lastYear = calendar.component(.year, from: rule.lastResetAt)
                let currentYear = calendar.component(.year, from: now)
                if currentYear != lastYear { needsReset = true }
            }
            
            if needsReset {
                if rule.currentCount < rule.targetCount { rule.streakCount = 0 }
                rule.currentCount = 0
                rule.lastResetAt = now
                rules[index] = rule
            }
        }
        saveToLocalStorage()
        
        if let lastActive = userStats.lastActiveDate {
            if calendar.isDateInYesterday(lastActive) {
                userStats.currentDayStreak += 1
                if userStats.currentDayStreak > userStats.longestStreak {
                    userStats.longestStreak = userStats.currentDayStreak
                }
            } else if !calendar.isDateInToday(lastActive) {
                userStats.currentDayStreak = 1
            }
        } else {
            userStats.currentDayStreak = 1
        }
        userStats.lastActiveDate = now
        saveToLocalStorage()
    }
}

// MARK: - Journal Manager
@MainActor
class JournalManager: ObservableObject {
    static let shared = JournalManager()
    
    @Published var entries: [JournalEntry] = []
    @Published var stats: JournalStats = JournalStats.empty(userId: 0)
    @Published var isLoading = false
    @Published var currentEntry: JournalEntry?
    
    private let storageKey = "journal_entries"
    private let statsKey = "journal_stats"
    
    init() {
        loadFromLocalStorage()
    }
    
    // MARK: - Entry Management
    
    func getOrCreateEntryForDate(_ date: Date, userId: Int) -> JournalEntry {
        let calendar = Calendar.current
        if let existing = entries.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return existing
        }
        
        // Create new entry
        let newEntry = JournalEntry.newEntry(userId: userId, date: date)
        entries.append(newEntry)
        saveToLocalStorage()
        return newEntry
    }
    
    func getTodayEntry(userId: Int) -> JournalEntry {
        return getOrCreateEntryForDate(Date(), userId: userId)
    }
    
    func updateEntry(_ entry: JournalEntry) {
        var updatedEntry = entry
        updatedEntry.updatedAt = Date()
        
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = updatedEntry
        } else {
            entries.append(updatedEntry)
        }
        
        // Calculate points
        let completionPoints = Int(entry.completionPercentage / 10)
        updatedEntry.pointsEarned = completionPoints
        
        updateStats()
        saveToLocalStorage()
    }
    
    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        updateStats()
        saveToLocalStorage()
    }
    
    func getEntryForDate(_ date: Date) -> JournalEntry? {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func getEntriesForMonth(_ date: Date) -> [JournalEntry] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        return entries.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }.sorted { $0.date > $1.date }
    }
    
    // MARK: - Link with Tasks and Rules
    
    func linkCompletedTasks(_ taskIds: [String], to entry: inout JournalEntry) {
        entry.completedTaskIds = taskIds
    }
    
    func linkMissedTasks(_ taskIds: [String], to entry: inout JournalEntry) {
        entry.missedTaskIds = taskIds
    }
    
    func linkCompletedRules(_ ruleIds: [String], to entry: inout JournalEntry) {
        entry.completedRuleIds = ruleIds
    }
    
    func linkMissedRules(_ ruleIds: [String], to entry: inout JournalEntry) {
        entry.missedRuleIds = ruleIds
    }
    
    // MARK: - Statistics
    
    private func updateStats() {
        let calendar = Calendar.current
        let sortedEntries = entries.sorted { $0.date > $1.date }
        
        // Calculate streak
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        for entry in sortedEntries {
            let entryDate = calendar.startOfDay(for: entry.date)
            if entryDate == checkDate && entry.isComplete {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else if entryDate < checkDate {
                break
            }
        }
        
        stats.currentStreak = streak
        stats.longestStreak = max(stats.longestStreak, streak)
        stats.totalEntries = entries.count
        
        // Calculate average completion
        if !entries.isEmpty {
            let totalCompletion = entries.reduce(0.0) { $0 + $1.completionPercentage }
            stats.averageCompletion = totalCompletion / Double(entries.count)
        }
        
        // Total points
        stats.totalPoints = entries.reduce(0) { $0 + $1.pointsEarned }
        stats.lastEntryDate = sortedEntries.first?.date
    }
    
    // MARK: - Persistence
    
    private func saveToLocalStorage() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private func loadFromLocalStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = decoded
        }
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(JournalStats.self, from: data) {
            stats = decoded
        }
    }
    
    // MARK: - Date helpers
    
    func hasEntryForDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return entries.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func completionForDate(_ date: Date) -> Double {
        getEntryForDate(date)?.completionPercentage ?? 0
    }
}

@main
struct FocusApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var taskManager = TaskManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var inAppNotificationManager = InAppNotificationManager.shared
    
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    
    var body: some Scene {
        #if os(macOS)
        // Menu Bar Only - No floating window
        MenuBarExtra {
            MenuBarDropdownView()
                .environmentObject(authManager)
                .environmentObject(taskManager)
        } label: {
            // Load icon - try multiple paths
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)
        
        // Full App Window (opened separately)
        Window("Focus", id: "full-app") {
            ZStack {
                FullAppWindowView()
                    .environmentObject(authManager)
                    .environmentObject(taskManager)
                
                // Rize-style in-app notification overlay
                NotificationToastStack(manager: inAppNotificationManager)
                    .allowsHitTesting(true)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 900)
        
        // Add Todo Window (separate from menu bar to prevent focus issues)
        Window("Add Todo", id: "add-todo") {
            MenuBarAddTodoSheet()
                .environmentObject(taskManager)
                .environmentObject(authManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Settings {
            SettingsView()
                .environmentObject(authManager)
                .environmentObject(themeManager)
                .environmentObject(notificationManager)
                .environmentObject(taskManager)
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(taskManager)
                .environmentObject(notificationManager)
                .environmentObject(themeManager)
        }
        #endif
    }
}

// MARK: - Menu Bar Icon View
#if os(macOS)

// Global logo loader function
func loadAppLogo() -> NSImage? {
    // Try multiple loading methods
    let names = ["AppLogo", "MenuBarIcon", "logo", "projectnextlogo"]
    
    // Method 1: Bundle.main.image
    for name in names {
        if let img = Bundle.main.image(forResource: name) {
            return img
        }
    }
    
    // Method 2: From Resources folder in bundle (nested structure)
    if let resourcePath = Bundle.main.resourcePath {
        let paths = [
            // Nested Resources folder (common with Xcode copy phase)
            "\(resourcePath)/Resources/AppLogo.png",
            "\(resourcePath)/Resources/MenuBarIcon.png",
            "\(resourcePath)/Resources/projectnextlogo.png",
            "\(resourcePath)/Resources/logo.png",
            // Direct in Resources
            "\(resourcePath)/AppLogo.png",
            "\(resourcePath)/projectnextlogo.png",
            "\(resourcePath)/logo.png"
        ]
        for path in paths {
            if let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
    }
    
    // Method 3: Named image from asset catalog
    if let img = NSImage(named: "AppIcon") {
        return img
    }
    
    return nil
}

// MARK: - Advanced Animation Components

// Animated Button with hover, press, and ripple effects
struct AnimatedButton<Content: View>: View {
    let action: () -> Void
    let content: () -> Content
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var showRipple = false
    @State private var rippleScale: CGFloat = 0
    
    init(action: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.action = action
        self.content = content
    }
    
    var body: some View {
        Button(action: {
            // Trigger press animation
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                isPressed = true
            }
            
            // Ripple effect
            showRipple = true
            withAnimation(.easeOut(duration: 0.4)) {
                rippleScale = 2.5
            }
            
            // Reset and call action
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showRipple = false
                rippleScale = 0
            }
        }) {
            content()
                .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.03 : 1.0))
                .brightness(isHovered ? 0.05 : 0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
                .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPressed)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// Animated Icon Button with bounce effect
struct AnimatedIconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var bounce = false
    
    init(icon: String, color: Color = .primary, size: CGFloat = 16, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                isPressed = true
                bounce = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(isHovered ? color : color.opacity(0.7))
                .scaleEffect(isPressed ? 0.8 : (isHovered ? 1.15 : 1.0))
                .rotationEffect(.degrees(isPressed ? -10 : 0))
                .symbolEffect(.bounce, value: bounce)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

// Scale Button Style - for all buttons
struct ScaleButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Bounce Button Style - more playful
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? -2 : 0))
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// Animated List Row - for task list items
struct AnimatedListRow<Content: View>: View {
    let index: Int
    let content: () -> Content
    
    @State private var appeared = false
    @State private var isHovered = false
    
    var body: some View {
        content()
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -30)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.05), value: appeared)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
            .onAppear {
                appeared = true
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// Animated Card - for task blocks, meeting cards etc
struct AnimatedCard<Content: View>: View {
    let content: () -> Content
    
    @State private var isHovered = false
    @State private var appeared = false
    
    var body: some View {
        content()
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
            .shadow(
                color: isHovered ? Color.black.opacity(0.15) : Color.black.opacity(0.05),
                radius: isHovered ? 12 : 4,
                x: 0,
                y: isHovered ? 6 : 2
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appeared)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
            .onAppear {
                withAnimation {
                    appeared = true
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// Success Checkmark Animation
struct SuccessCheckmark: View {
    @Binding var show: Bool
    
    @State private var circleScale: CGFloat = 0
    @State private var checkScale: CGFloat = 0
    @State private var circleOpacity: Double = 1
    
    var body: some View {
        ZStack {
            // Expanding circle
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 60, height: 60)
                .scaleEffect(circleScale)
                .opacity(circleOpacity)
            
            // Green circle
            Circle()
                .fill(Color.green)
                .frame(width: 40, height: 40)
                .scaleEffect(checkScale)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(checkScale)
        }
        .opacity(show ? 1 : 0)
        .onChange(of: show) { _, newValue in
            if newValue {
                // Animate in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    circleScale = 1.5
                    checkScale = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        checkScale = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        circleScale = 2.0
                        circleOpacity = 0
                    }
                }
                
                // Reset
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    show = false
                    circleScale = 0
                    checkScale = 0
                    circleOpacity = 1
                }
            }
        }
    }
}

// Pulse Effect View
struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    func pulseEffect(color: Color = .blue) -> some View {
        modifier(PulseEffect(color: color))
    }
}

// Shimmer Loading Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + phase * geo.size.width * 2)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// Appear Animation Modifier
struct AppearAnimation: ViewModifier {
    @State private var appeared = false
    let delay: Double
    let direction: Edge
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(
                x: appeared ? 0 : (direction == .leading ? -30 : (direction == .trailing ? 30 : 0)),
                y: appeared ? 0 : (direction == .top ? -20 : (direction == .bottom ? 20 : 0))
            )
            .scaleEffect(appeared ? 1 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: appeared)
            .onAppear {
                appeared = true
            }
    }
}

extension View {
    func appearAnimation(delay: Double = 0, from direction: Edge = .bottom) -> some View {
        modifier(AppearAnimation(delay: delay, direction: direction))
    }
}

// MARK: - Animated Checkbox with Check Drawing Animation
struct AnimatedCheckbox: View {
    let isCompleted: Bool
    let action: () -> Void
    
    @State private var isAnimating = false
    @State private var showCheck = false
    @State private var circleScale: CGFloat = 1.0
    @State private var checkScale: CGFloat = 0
    @State private var rippleScale: CGFloat = 1.0
    @State private var rippleOpacity: CGFloat = 0
    
    var body: some View {
        Button(action: {
            guard !isAnimating else { return }
            
            if !isCompleted {
                // COMPLETING - Play full animation
                isAnimating = true
                
                // Step 1: Shrink circle
                withAnimation(.easeIn(duration: 0.1)) {
                    circleScale = 0.85
                }
                
                // Step 2: Bounce back and show green fill + checkmark
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                        circleScale = 1.15
                        showCheck = true
                        checkScale = 1.2
                    }
                }
                
                // Step 3: Settle to normal size
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        circleScale = 1.0
                        checkScale = 1.0
                    }
                    
                    // Ripple effect
                    rippleOpacity = 0.6
                    withAnimation(.easeOut(duration: 0.4)) {
                        rippleScale = 2.0
                        rippleOpacity = 0
                    }
                }
                
                // Step 4: Call the action after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    action()
                }
                
                // Reset animation lock
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isAnimating = false
                    rippleScale = 1.0
                }
            } else {
                // UNCOMPLETING - Quick reverse
                withAnimation(.easeOut(duration: 0.2)) {
                    showCheck = false
                    checkScale = 0
                }
                action()
            }
        }) {
            ZStack {
                // Ripple effect circle
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                
                // Background circle (gray when unchecked)
                Circle()
                    .strokeBorder(Color.gray.opacity(0.4), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .opacity(showCheck || isCompleted ? 0 : 1)
                
                // Green filled circle (shown when checked)
                Circle()
                    .fill(Color.green)
                    .frame(width: 22, height: 22)
                    .opacity(showCheck || isCompleted ? 1 : 0)
                
                // Green border when checked
                Circle()
                    .strokeBorder(Color.green, lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .opacity(showCheck || isCompleted ? 1 : 0)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(showCheck || isCompleted ? (isAnimating ? checkScale : 1.0) : 0)
                    .opacity(showCheck || isCompleted ? 1 : 0)
            }
            .scaleEffect(circleScale)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onAppear {
            // Sync initial state
            if isCompleted {
                showCheck = true
                checkScale = 1.0
            }
        }
        .onChange(of: isCompleted) { oldValue, newValue in
            // Sync when external state changes
            if !isAnimating {
                showCheck = newValue
                checkScale = newValue ? 1.0 : 0
            }
        }
    }
}

// Custom checkmark shape for drawing animation
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Start from left, go down to bottom-middle, then up to right
        let startX = rect.minX
        let startY = rect.midY
        let midX = rect.width * 0.35
        let midY = rect.maxY
        let endX = rect.maxX
        let endY = rect.minY
        
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: midX, y: midY))
        path.addLine(to: CGPoint(x: endX, y: endY))
        
        return path
    }
}

struct MenuBarIconView: View {
    private static func loadLogo() -> NSImage? {
        return loadAppLogo()
    }
    
    private static func createIcon() -> NSImage? {
        guard let original = loadLogo() else { return nil }
        let newSize = NSSize(width: 18, height: 18)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        original.draw(in: NSRect(origin: .zero, size: newSize),
                     from: NSRect(origin: .zero, size: original.size),
                     operation: .copy,
                     fraction: 1.0)
        newImage.unlockFocus()
        newImage.isTemplate = false
        return newImage
    }
    
    private static let cachedIcon = createIcon()
    
    var body: some View {
        if let icon = Self.cachedIcon {
            Image(nsImage: icon)
        } else {
            Image(systemName: "checkmark.circle.fill")
        }
    }
}

// Focus Logo - loads from app bundle
struct ProjectNextLogo: View {
    var size: CGFloat = 24
    
    var body: some View {
        Group {
            if let nsImage = loadAppLogo() {
                Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                // Fallback if file not found
                fallbackLogo
            }
        }
    }
    
    private var fallbackLogo: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.231, green: 0.255, blue: 0.275))
                .frame(width: size * 0.6, height: size * 0.6)
                .offset(x: size * 0.15, y: size * 0.15)
            
            Circle()
                .fill(Color(red: 0.231, green: 0.255, blue: 0.275))
                .frame(width: size * 0.55, height: size * 0.55)
                .offset(x: -size * 0.05, y: -size * 0.05)
            
            Circle()
                .fill(Color(red: 0.976, green: 0.698, blue: 0.2))
                .frame(width: size * 0.45, height: size * 0.45)
                .offset(x: -size * 0.15, y: -size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Menu Bar Dropdown View
struct MenuBarDropdownView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @StateObject var ruleManager = RuleManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab = 0
    @State private var todaySubTab = 0  // 0 = Upcoming, 1 = Completed
    @State private var checklistSubTab = 0  // 0 = To Do, 1 = Rules
    @State private var selectedRulePeriod = 0  // 0 = Daily, 1 = Weekly, 2 = Monthly, 3 = Yearly
    @State private var selectedMeeting: TaskItem?
    @State private var tabDirection: Int = 0
    @State private var isHoveringFooter = false
    @State private var subTabDirection: Int = 0
    @State private var footerPressed = false
    // showAddRule removed - now uses floating window
    
    var body: some View {
        ZStack {
            // Main content
        VStack(spacing: 0) {
            headerView
            tabBar
            contentView
            footerView
        }
            .opacity(selectedMeeting == nil ? 1 : 0)
            
            // Meeting Details overlay
            if let meeting = selectedMeeting {
                MeetingDetailsInline(meeting: meeting, onClose: { 
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedMeeting = nil
                    }
                })
                    .environmentObject(taskManager)
                    .transition(.opacity)
            }
        }
        .frame(width: 380, height: 500)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await taskManager.fetchTasks(for: userId)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // Focus Logo with pulse animation
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                ProjectNextLogo(size: 22)
            }

            VStack(alignment: .leading, spacing: 1) {
            Text("Focus")
                    .font(.system(size: 14, weight: .bold))
                Text(Date(), style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress indicator with animation
            let progress = getProgress()
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                        .frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress.completed) / CGFloat(max(progress.total, 1)))
                        .stroke(
                            progress.completed == progress.total ? Color.green : Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: progress.completed)
                    
                    Text("\(progress.completed)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(progress.completed == progress.total ? .green : .accentColor)
                }
                
                Text("/\(progress.total)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("Today", icon: "sun.max.fill", index: 0)
            tabButton("Checklist", icon: "list.bullet.clipboard", index: 1)
            tabButton("Meetings", icon: "video.fill", index: 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        TabButtonAnimated(
            title: title,
            icon: icon,
            isSelected: selectedTab == index,
            action: {
                let oldTab = selectedTab
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    tabDirection = index > oldTab ? 1 : -1
            selectedTab = index
                }
            }
        )
    }
}

// Animated Tab Button Component
struct TabButtonAnimated: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                    .rotationEffect(.degrees(isPressed ? -5 : 0))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(isPressed ? 0.92 : (isSelected ? 1.03 : (isHovered ? 1.02 : 1.0)))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: isPressed)
    }
}

// Continue MenuBarDropdownView extension
extension MenuBarDropdownView {
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                switch selectedTab {
                case 0:
                    todayContent
                        .transition(.asymmetric(
                            insertion: .move(edge: tabDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: tabDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
                        ))
                case 1:
                    checklistContent
                        .transition(.asymmetric(
                            insertion: .move(edge: tabDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: tabDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
                        ))
                case 2:
                    meetingsContent
                        .transition(.asymmetric(
                            insertion: .move(edge: tabDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: tabDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
                        ))
                default:
                    todayContent
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedTab)
    }
    
    // Filter to today only - sorted by time
    private var todayTasks: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return taskManager.todayTasks.filter { task in
            Calendar.current.isDate(task.date, inSameDayAs: today)
        }.sorted { task1, task2 in
            // Sort by start hour then minute
            let time1 = task1.startHour * 60 + task1.startMinute
            let time2 = task2.startHour * 60 + task2.startMinute
            return time1 < time2
        }
    }
    
    // Today's meetings only - sorted by time
    private var todayMeetings: [TaskItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return taskManager.todayTasks.filter { task in
            task.type == .meeting && Calendar.current.isDate(task.date, inSameDayAs: today)
        }.sorted { task1, task2 in
            let time1 = task1.startHour * 60 + task1.startMinute
            let time2 = task2.startHour * 60 + task2.startMinute
            return time1 < time2
        }
    }
    
    private var upcomingTasks: [TaskItem] {
        todayTasks.filter { !$0.isCompleted }
    }
    
    private var completedTasks: [TaskItem] {
        todayTasks.filter { $0.isCompleted }
    }
    
    private var todayContent: some View {
        VStack(spacing: 0) {
            // Upcoming / Completed toggle with smooth animation
            HStack(spacing: 0) {
                Button {
                    subTabDirection = -1
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { todaySubTab = 0 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("Upcoming (\(upcomingTasks.count))")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(todaySubTab == 0 ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(todaySubTab == 0 ? Color.accentColor : Color.clear)
                    )
                    .scaleEffect(todaySubTab == 0 ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                
                Button {
                    subTabDirection = 1
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { todaySubTab = 1 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 9))
                        Text("Completed (\(completedTasks.count))")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(todaySubTab == 1 ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(todaySubTab == 1 ? Color.green : Color.clear)
                    )
                    .scaleEffect(todaySubTab == 1 ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
            }
            .padding(3)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: todaySubTab)
            
            // Task list with smooth transition
        Group {
                let tasks = todaySubTab == 0 ? upcomingTasks : completedTasks
                
                if tasks.isEmpty {
                    emptyStateView(todaySubTab == 0 ? "All caught up!" : "No completed tasks")
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                    ForEach(tasks) { task in
                        unifiedTaskRow(task)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: subTabDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: subTabDirection >= 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: todaySubTab)
        }
    }
    
    // Unified row style for both tasks and meetings
    private func unifiedTaskRow(_ task: TaskItem) -> some View {
        TaskRowAnimated(task: task, taskManager: taskManager, taskColor: taskColor(task), taskIcon: taskIcon(task)) {
                    if task.type == .meeting {
                selectedMeeting = task
            }
        }
    }
}

// Animated Task Row Component
struct TaskRowAnimated: View {
    let task: TaskItem
    @ObservedObject var taskManager: TaskManager
    let taskColor: Color
    let taskIcon: String
    var onDoubleTap: (() -> Void)? = nil
    
    // Animation states
    @State private var slideOffset: CGFloat = 0
    @State private var rowOpacity: Double = 1
    @State private var rowScale: CGFloat = 1.0
    @State private var rowRotation: Double = 0
    @State private var isAnimating = false
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkRotation: Double = -180
    @State private var successGlow: Double = 0
    @State private var progressWidth: CGFloat = 0
    @State private var showParticles = false
    @State private var isHovered = false
    @State private var appeared = false
    @State private var circleScale: CGFloat = 0
    @State private var circleOpacity: Double = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Animated success background that reveals during slide
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [Color.green.opacity(0.9), Color.green, Color.mint.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Animated shimmer effect
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60)
                        .offset(x: isAnimating ? geo.size.width + 60 : -60)
                        .animation(.easeInOut(duration: 0.8).delay(0.2), value: isAnimating)
                }
                
                // Success content
                HStack(spacing: 12) {
                    // Animated checkmark with ring
                    ZStack {
                        // Expanding ring
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .scaleEffect(circleScale)
                            .opacity(circleOpacity)
                        
                        // Checkmark
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(checkmarkScale)
                            .rotationEffect(.degrees(checkmarkRotation))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completed!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Great job!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    // Star burst particles
                    if showParticles {
                        ParticleEmitter()
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isAnimating ? 1 : 0)
            .shadow(color: .green.opacity(successGlow), radius: 12, x: 0, y: 0)
            
            // Main row content
            HStack(spacing: 12) {
                // Custom animated checkbox
                Button {
                    if !task.isCompleted {
                        triggerCompletionAnimation()
                        // Delay the actual completion so animation can play
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            Task { await taskManager.toggleComplete(task: task) }
                        }
                    } else {
                        // Uncompleting - do immediately
                        Task { await taskManager.toggleComplete(task: task) }
                    }
                } label: {
                    ZStack {
                        // Outer ring
                        Circle()
                            .strokeBorder(
                                isHovered ? taskColor : Color.secondary.opacity(0.4),
                                lineWidth: isHovered ? 2.5 : 2
                            )
                            .frame(width: 26, height: 26)
                        
                        // Fill on hover
                        Circle()
                            .fill(isHovered ? taskColor.opacity(0.15) : Color.clear)
                            .frame(width: 22, height: 22)
                        
                        // Check icon on hover
                        if isHovered && !task.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(taskColor)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Completed state
                        if task.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 26, height: 26)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: task.isCompleted)
                }
                .buttonStyle(.plain)
                
                // Task icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(taskColor.opacity(task.isCompleted ? 0.08 : 0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: taskIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(task.isCompleted ? taskColor.opacity(0.5) : taskColor)
                        .symbolEffect(.bounce, value: task.isCompleted)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(task.timeText)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .opacity(task.isCompleted ? 0.6 : 1)
                }
                
                Spacer()
                
                // Type badge
                HStack(spacing: 6) {
                    Text(task.type == .meeting ? "Meeting" : task.type.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(task.isCompleted ? taskColor.opacity(0.5) : taskColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(taskColor.opacity(task.isCompleted ? 0.05 : 0.12))
                        .clipShape(Capsule())
                    
                    if task.type == .meeting {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    
                    // Hover glow
                    if isHovered {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(taskColor.opacity(0.03))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isHovered ? taskColor.opacity(0.4) : Color(nsColor: NSColor.separatorColor).opacity(0.3),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .shadow(
                color: isHovered ? taskColor.opacity(0.15) : .black.opacity(0.05),
                radius: isHovered ? 8 : 2,
                x: 0,
                y: isHovered ? 4 : 1
            )
            .offset(x: slideOffset)
            .opacity(rowOpacity)
            .scaleEffect(rowScale)
            .rotationEffect(.degrees(rowRotation))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            onDoubleTap?()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0...0.15)) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
        }
    }
    
    private func triggerCompletionAnimation() {
        isAnimating = true
        
        // Step 1: Quick bounce
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            rowScale = 1.08
        }
        
        // Step 2: Show success elements immediately
        withAnimation(.easeOut(duration: 0.2)) {
            successGlow = 0.8
            checkmarkScale = 1.0
            checkmarkRotation = 0
        }
        
        // Step 3: Expanding ring effect
        withAnimation(.easeOut(duration: 0.4)) {
            circleScale = 1.8
            circleOpacity = 1.0
        }
        
        // Step 4: Scale back and show particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                rowScale = 1.0
            }
            showParticles = true
            
            // Fade ring
            withAnimation(.easeOut(duration: 0.3)) {
                circleOpacity = 0
            }
        }
        
        // Step 5: VISIBLE SLIDE TO THE RIGHT - slower and clearer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.5)) {
                slideOffset = 120  // Slide RIGHT - visible amount
                rowRotation = 3    // Slight tilt
            }
        }
        
        // Step 6: Continue sliding RIGHT and fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeIn(duration: 0.4)) {
                slideOffset = 400  // Far RIGHT
                rowOpacity = 0
                rowRotation = 8
                rowScale = 0.85
            }
        }
        
        // Step 7: Reset after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            slideOffset = 0
            rowOpacity = 1
            rowScale = 1.0
            rowRotation = 0
            checkmarkScale = 0
            checkmarkRotation = -180
            successGlow = 0
            circleScale = 0
            circleOpacity = 0
            showParticles = false
            isAnimating = false
        }
    }
}

// Particle effect for completion celebration
struct ParticleEmitter: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = []
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Image(systemName: ["star.fill", "sparkle", "circle.fill"].randomElement()!)
                    .font(.system(size: CGFloat.random(in: 6...10)))
                    .foregroundColor([.yellow, .white, .orange].randomElement()!)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .offset(x: particle.x, y: particle.y)
            }
        }
        .onAppear {
            for i in 0..<8 {
                let delay = Double(i) * 0.05
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let id = i
                    let startX: CGFloat = CGFloat.random(in: -10...10)
                    let startY: CGFloat = CGFloat.random(in: -5...5)
                    
                    particles.append((id: id, x: startX, y: startY, scale: 0, opacity: 1))
                    
                    withAnimation(.easeOut(duration: 0.6)) {
                        if let index = particles.firstIndex(where: { $0.id == id }) {
                            particles[index].x = CGFloat.random(in: -40...40)
                            particles[index].y = CGFloat.random(in: -30...30)
                            particles[index].scale = CGFloat.random(in: 0.8...1.2)
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let index = particles.firstIndex(where: { $0.id == id }) {
                                particles[index].opacity = 0
                            }
                        }
                    }
                }
            }
        }
    }
}

// Extension to add back the helper functions to MenuBarDropdownView
extension MenuBarDropdownView {
    func taskColor(_ task: TaskItem) -> Color {
        switch task.type {
        case .meeting: return .purple
        case .todo: return .blue
        case .social: return .pink
        case .timeBlock: return .orange
        }
    }
    
    private func taskIcon(_ task: TaskItem) -> String {
        switch task.type {
        case .meeting: return "video.fill"
        case .todo: return "checklist"
        case .social: return "person.2.fill"
        case .timeBlock: return "clock.fill"
        }
    }
    
    private var todoContent: some View {
        VStack(spacing: 0) {
            // Todo list
            let todos = taskManager.todayTasks.filter { $0.type == .todo }.sorted { task1, task2 in
                let time1 = task1.endHour * 60 + task1.endMinute
                let time2 = task2.endHour * 60 + task2.endMinute
                return time1 < time2
            }
            
            if todos.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.1))
                            .frame(width: 60, height: 60)
                    Image(systemName: "checklist")
                            .font(.system(size: 28))
                            .foregroundColor(.purple.opacity(0.6))
                    }
                    VStack(spacing: 4) {
                        Text("All clear!")
                            .font(.system(size: 14, weight: .semibold))
                        Text("No todo items yet")
                            .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale.combined(with: .opacity))
            } else {
                ForEach(todos) { task in
                    taskRow(task)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            
            Spacer()
            
            // Add Todo Button at bottom with gradient
            Button {
                openAddTodoWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Todo")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.purple.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: taskManager.todayTasks.count)
    }
    
    // MARK: - Checklist Content (To Do + Rules)
    private var checklistContent: some View {
        VStack(spacing: 0) {
            // Sub-tab selector
            checklistSubTabBar
            
            // Content based on sub-tab
            if checklistSubTab == 0 {
                todoContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                rulesContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: checklistSubTab)
    }
    
    private var checklistSubTabBar: some View {
        HStack(spacing: 4) {
            checklistSubTabButton("To Do", icon: "checklist", index: 0)
            checklistSubTabButton("Rules", icon: "book.fill", index: 1)
        }
        .padding(4)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    private func checklistSubTabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                checklistSubTab = index
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: checklistSubTab == index ? .bold : .medium))
                Text(title)
                    .font(.system(size: 11, weight: checklistSubTab == index ? .bold : .medium))
            }
            .foregroundColor(checklistSubTab == index ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(checklistSubTab == index ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Rules Content with Mini Tabs
    private var rulesContent: some View {
        VStack(spacing: 0) {
            // Mini period tabs (Daily, Weekly, Monthly, Yearly)
            rulesPeriodMiniTabs
            
            // Stats header
            rulesStatsHeader
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    let filteredRules = filteredRulesByPeriod
                    
                    if filteredRules.isEmpty {
                        rulesEmptyState
                    } else {
                        ForEach(filteredRules) { rule in
                            RuleRowView(rule: rule, ruleManager: ruleManager)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedRulePeriod)
            }
            
            // Add Rule Button
            Button {
                openAddRuleWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("Add Rule")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.green.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
    
    // Mini period tabs - Daily, Weekly, Monthly, Yearly only
    private var rulesPeriodMiniTabs: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                let title = ["Daily", "Weekly", "Monthly", "Yearly"][index]
                let color: Color = [.orange, .blue, .purple, .pink][index]
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedRulePeriod = index
                    }
                } label: {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selectedRulePeriod == index ? .white : color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedRulePeriod == index ? color : color.opacity(0.12)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // Filter rules by selected period (0=Daily, 1=Weekly, 2=Monthly, 3=Yearly)
    private var filteredRulesByPeriod: [Rule] {
        switch selectedRulePeriod {
        case 0: return ruleManager.dailyRules
        case 1: return ruleManager.weeklyRules
        case 2: return ruleManager.monthlyRules
        case 3: return ruleManager.yearlyRules
        default: return ruleManager.dailyRules
        }
    }
    
    private var rulesStatsHeader: some View {
        VStack(spacing: 8) {
            // Completion percentage bar
            let completedCount = ruleManager.rules.filter { $0.isCompletedForPeriod }.count
            let totalCount = max(ruleManager.rules.count, 1)
            let percentage = Double(completedCount) / Double(totalCount) * 100
            
            HStack(spacing: 10) {
                // Percentage circle
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: percentage / 100)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(percentage))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Progress")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(completedCount) of \(ruleManager.rules.count) completed")
                        .font(.system(size: 13, weight: .semibold))
                }
                
                Spacer()
                
                // Streak flame
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("\(ruleManager.userStats.currentDayStreak)")
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // Stats row
            HStack(spacing: 8) {
                // Points
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text("\(ruleManager.userStats.totalPoints) pts")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.15))
                .clipShape(Capsule())
                
                // Level
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ruleManager.userStats.levelColor)
                    Text("Lv.\(ruleManager.userStats.currentLevel)")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ruleManager.userStats.levelColor.opacity(0.1))
                .clipShape(Capsule())
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
    }
    
    private func ruleSection(_ title: String, rules: [Rule], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                let completed = rules.filter { $0.isCompletedForPeriod }.count
                Text("\(completed)/\(rules.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 4)
            
            ForEach(rules) { rule in
                RuleRowView(rule: rule, ruleManager: ruleManager)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var rulesEmptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 70, height: 70)
                Image(systemName: "book.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green.opacity(0.6))
            }
            VStack(spacing: 4) {
                Text("No Rules Yet")
                    .font(.system(size: 15, weight: .semibold))
                Text("Create rules to build habits")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func openAddTodoWindow() {
        // Create a new floating window for Add Todo
        let contentView = MenuBarAddTodoSheet()
            .environmentObject(TaskManager.shared)
            .environmentObject(AuthManager.shared)

        let hostingController = NSHostingController(rootView: contentView)

        // Create floating window that stays above all apps
        let window = FloatingAppWindow(contentViewController: hostingController)
        window.title = "Add Todo"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 520))
        window.center()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func openAddRuleWindow() {
        // Create a new floating window for Add Rule
        let contentView = AddRuleWindowContent(ruleManager: ruleManager, userId: authManager.currentUser?.id ?? 0)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        // Create floating window that stays above all apps
        let window = FloatingAppWindow(contentViewController: hostingController)
        window.title = "Add Rule"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 600))
        window.center()
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private var meetingsContent: some View {
        Group {
            if todayMeetings.isEmpty {
                emptyStateView("No meetings today")
            } else {
                ForEach(todayMeetings) { task in
                    meetingRow(task)
                }
            }
        }
    }
    
    private func emptyStateView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func taskRow(_ task: TaskItem) -> some View {
        TaskRowWithSwipe(taskItem: task, taskManager: taskManager)
    }
    
    // Improved meeting row design
    private func meetingRow(_ task: TaskItem) -> some View {
        Button {
            selectedMeeting = task
        } label: {
            HStack(spacing: 12) {
                // Meeting icon with gradient
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "video.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(task.timeText)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    
                    if let desc = task.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    if task.meetingLink != nil {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.purple.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var footerView: some View {
        Button {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.5)) {
                footerPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    footerPressed = false
                    openFullAppWindow()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "macwindow")
                    .font(.system(size: 12))
                    .rotationEffect(.degrees(isHoveringFooter ? 5 : (footerPressed ? -3 : 0)))
                    .scaleEffect(footerPressed ? 0.9 : 1.0)
                Text("Open Full App")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(isHoveringFooter ? 1 : 0)
                    .offset(x: isHoveringFooter ? 0 : -5, y: footerPressed ? -2 : 0)
            }
            .foregroundColor(isHoveringFooter ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHoveringFooter ? Color.accentColor.opacity(0.12) : Color(nsColor: NSColor.controlBackgroundColor))
                    .shadow(
                        color: isHoveringFooter ? Color.accentColor.opacity(0.2) : .clear,
                        radius: isHoveringFooter ? 6 : 0,
                        y: isHoveringFooter ? 2 : 0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isHoveringFooter ? Color.accentColor.opacity(0.4) : Color(nsColor: NSColor.separatorColor).opacity(0.5),
                        lineWidth: isHoveringFooter ? 1.5 : 0.5
                    )
            )
            .scaleEffect(footerPressed ? 0.96 : (isHoveringFooter ? 1.02 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHoveringFooter = hovering
            }
        }
        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: footerPressed)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
    
    private func openFullAppWindow() {
        // Create the full app window programmatically
        let contentView = FullAppWindowView()
            .environmentObject(TaskManager.shared)
            .environmentObject(AuthManager.shared)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Focus"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 1400, height: 900))
        window.minSize = NSSize(width: 1200, height: 800)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func getProgress() -> (completed: Int, total: Int) {
        let tasks = todayTasks
        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count
        return (completed, total)
    }
}

// MARK: - Swipeable Task Row with Delete Animation
struct TaskRowWithSwipe: View {
    let taskItem: TaskItem
    @ObservedObject var taskManager: TaskManager
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var showDeleteButton = false
    
    private let deleteThreshold: CGFloat = -80
    private let deleteButtonWidth: CGFloat = 70
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            HStack {
                Spacer()
                Button {
                    performDelete()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                        Text("Delete")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: deleteButtonWidth, height: 50)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .opacity(showDeleteButton ? 1 : 0)
                .scaleEffect(showDeleteButton ? 1 : 0.8)
                .animation(.spring(response: 0.3), value: showDeleteButton)
            }
            
            // Main content
            HStack(spacing: 10) {
                AnimatedCheckbox(isCompleted: taskItem.isCompleted) {
                    Task {
                        await taskManager.toggleComplete(task: taskItem)
                    }
                }
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(taskItem.title)
                        .font(.system(size: 13, weight: .medium))
                        .strikethrough(taskItem.isCompleted)
                        .foregroundColor(taskItem.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.2), value: taskItem.isCompleted)
                    
                    HStack(spacing: 4) {
                        Text(taskItem.type.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(taskItem.type.color.opacity(0.2))
                            .foregroundColor(taskItem.type.color)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        if !taskItem.timeText.isEmpty {
                            Text(taskItem.timeText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(10)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            withAnimation(.interactiveSpring()) {
                                offset = value.translation.width
                            }
                            showDeleteButton = offset < deleteThreshold
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            if offset < deleteThreshold {
                                offset = -deleteButtonWidth - 10
                                showDeleteButton = true
                            } else {
                                offset = 0
                                showDeleteButton = false
                            }
                        }
                    }
            )
        }
        .opacity(isDeleting ? 0 : 1)
        .scaleEffect(isDeleting ? 0.8 : 1)
        .offset(x: isDeleting ? -300 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isDeleting)
    }
    
    private func performDelete() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isDeleting = true
        }
        
        // Delete from database after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Task {
                await taskManager.deleteTask(taskItem)
            }
        }
    }
}

// MARK: - Menu Bar Add Todo Sheet
struct MenuBarAddTodoSheet: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var priority = "medium"
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let priorities = ["low", "medium", "high"]
    
    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Todo")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    closeWindow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: NSColor.windowBackgroundColor))
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Name *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("What do you need to do?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(12)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .font(.system(size: 13))
                            .frame(height: 60)
                            .padding(8)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                    }
                    
                    // Due Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Due Date")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.purple)
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Priority
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Priority")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(priorities, id: \.self) { p in
                                Button {
                                    priority = p
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(priorityColor(p))
                                            .frame(width: 8, height: 8)
                                        Text(p.capitalized)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(priority == p ? priorityColor(p).opacity(0.15) : Color(nsColor: NSColor.controlBackgroundColor))
                                    .foregroundColor(priority == p ? priorityColor(p) : .primary)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(priority == p ? priorityColor(p) : Color.gray.opacity(0.2), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasReminder) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(hasReminder ? .orange : .secondary)
                                Text("Set Reminder")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if hasReminder {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.orange)
                                DatePicker("", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(12)
                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button {
                    closeWindow()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button {
                    saveTodo()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "plus")
                        }
                        Text(isSaving ? "Adding..." : "Add Todo")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding(20)
        }
        .frame(width: 400, height: 520)
        .interactiveDismissDisabled(isSaving)
    }
    
    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }
    
    private func saveTodo() {
        print("DEBUG: saveTodo called")
        
        guard let userId = authManager.currentUser?.id else {
            print("DEBUG: No user ID")
            errorMessage = "Please log in first"
            showError = true
            return
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            print("DEBUG: Title is empty")
            errorMessage = "Please enter a task name"
            showError = true
            return
        }
        
        print("DEBUG: Saving todo with title: \(trimmedTitle), userId: \(userId)")
        
        isSaving = true
        showError = false
        
        Task {
            let success = await createTodo(userId: userId)
            print("DEBUG: createTodo returned: \(success)")
            
            await MainActor.run {
                if success {
                    print("DEBUG: Todo saved successfully, refreshing tasks")
                    Task {
                        await taskManager.fetchTasks(for: userId)
                    }
                    // Close the window
                    closeWindow()
                } else {
                    isSaving = false
                    errorMessage = "Failed to save todo. Check console for details."
                    showError = true
                }
            }
        }
    }
    
    private func createTodo(userId: Int) async -> Bool {
        let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dueDateStr = dateFormatter.string(from: dueDate)
        
        // Map priority to database values
        let dbPriority: String
        switch priority {
        case "high": dbPriority = "high"
        case "low": dbPriority = "low"
        default: dbPriority = "normal"
        }
        
        // user_id as string for Supabase
        var todoData: [String: Any] = [
            "user_id": String(userId),
            "task_name": title.trimmingCharacters(in: .whitespaces),
            "start_date": dueDateStr,
            "deadline": dueDateStr,
            "priority": dbPriority,
            "completed": false
        ]
        
        if !description.trimmingCharacters(in: .whitespaces).isEmpty {
            todoData["description"] = description.trimmingCharacters(in: .whitespaces)
        }
        
        print("DEBUG: Creating todo with data: \(todoData)")
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/personal_todos") else {
            print("DEBUG: Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: todoData)
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG: Request body: \(jsonString)")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: Todo save response status: \(httpResponse.statusCode)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("DEBUG: Response body: \(responseStr)")
                }
                
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("DEBUG: Todo created successfully!")
                    return true
                } else {
                    print("DEBUG: Failed with status \(httpResponse.statusCode)")
                    return false
                }
            }
            return false
        } catch {
            print("DEBUG: Failed to save todo: \(error.localizedDescription)")
            return false
        }
    }
}

struct NoteSection: Codable, Identifiable {
    var id: String
    var name: String
    var notes: [String]
    
    init(id: String = UUID().uuidString, name: String, notes: [String] = [""]) {
        self.id = id
        self.name = name
        self.notes = notes
    }
}

struct MeetingNoteData: Codable {
    var id: Int?
    var meeting_id: Int
    var title: String
    var date: String
    var time: String
    var attendees: [String]
    var discussion_points: [String]
    var decisions_made: [String]
    var action_items: [String]
    var next_steps: [String]
    var discussion_sections: [NoteSection]?
    var decision_sections: [NoteSection]?
    var action_sections: [NoteSection]?
    var next_step_sections: [NoteSection]?
    var follow_up_date: String?
    var created_at: String?
    var updated_at: String?
}

// MARK: - Meeting Details Inline (shows inside dropdown)
struct MeetingDetailsInline: View {
    let meeting: TaskItem
    let onClose: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            HStack {
                Button { onClose() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    Text("Meeting Details")
                        .font(.system(size: 14, weight: .bold))
                }
                
                Spacer()
                
                Color.clear.frame(width: 28, height: 28)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Meeting Title Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(meeting.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        // Status badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Scheduled")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: NSColor.controlBackgroundColor))
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Time & Date Cards
                    HStack(spacing: 8) {
                        // Time Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text("TIME")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(meeting.timeText)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                        )
                        
                        // Date Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                Text("DATE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(meeting.date, style: .date)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // Description
                    if let desc = meeting.description, !desc.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "text.alignleft")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("DESCRIPTION")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            Text(desc)
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.9))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: NSColor.controlBackgroundColor))
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                    }
                    
                    // Join Meeting Button
                    if let link = meeting.meetingLink {
                        Button {
                            if let url = URL(string: link) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 14))
                                Text("Join Meeting")
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                    }
                    
                    Spacer(minLength: 16)
                }
            }
            
            // Bottom button - Open Meeting Notes
            Button {
                openMeetingNotesWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 13))
                    Text("Open Meeting Notes")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.purple.opacity(0.3), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
    
    private func openMeetingNotesWindow() {
        let contentView = MeetingNotesView(meeting: meeting, onBack: {})
            .environmentObject(TaskManager.shared)
        
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Meeting Notes"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 900, height: 700))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Meeting Sheet (for full app usage)
struct MenuBarMeetingSheet: View {
    let meeting: TaskItem
    let onClose: () -> Void
    @EnvironmentObject var taskManager: TaskManager
    @State private var showMeetingNotes = false

    var body: some View {
        if showMeetingNotes {
            MeetingNotesView(meeting: meeting, onBack: { showMeetingNotes = false })
                .environmentObject(taskManager)
        } else {
            meetingDetailsView
        }
    }
    
    private var meetingDetailsView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Meeting Details")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Color.clear.frame(width: 20, height: 20)
            }
            .padding(16)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Meeting", systemImage: "video.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(meeting.title)
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Divider()
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Time", systemImage: "clock")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(meeting.timeText)
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Date", systemImage: "calendar")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(meeting.date, style: .date)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    
                    if let desc = meeting.description, !desc.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Description", systemImage: "text.alignleft")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(desc)
                                .font(.system(size: 13))
                        }
                    }
                    
                    if let link = meeting.meetingLink {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Meeting Link", systemImage: "link")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Button {
                                if let url = URL(string: link) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "video.fill")
                                    Text("Join Meeting")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            
            Button {
                withAnimation { showMeetingNotes = true }
            } label: {
                HStack {
                    Image(systemName: "doc.text")
                    Text("Open Meeting Notes")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.purple)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(width: 400, height: 450)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
}

// MARK: - Meeting Notes View (opened manually)
struct MeetingNotesView: View {
    let meeting: TaskItem
    let onBack: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskManager: TaskManager
    
    @State private var isEditing = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var existingNotes: MeetingNoteData?
    
    // Meeting Notes Data
    @State private var noteTitle = ""
    @State private var noteDate = ""
    @State private var noteTime = ""
    @State private var attendees: [String] = []
    @State private var newAttendee = ""
    @State private var discussionPoints: [String] = [""]
    @State private var decisionsMade: [String] = [""]
    @State private var actionItems: [String] = [""]
    @State private var nextSteps: [String] = [""]
    @State private var followUpDate = ""
    
    // Sections
    @State private var discussionSections: [NoteSection] = []
    @State private var decisionSections: [NoteSection] = []
    @State private var actionSections: [NoteSection] = []
    @State private var nextStepSections: [NoteSection] = []
    
    // Section management
    @State private var showAddSection: [String: Bool] = [:]
    @State private var newSectionName: [String: String] = [:]
    @State private var expandedSections: Set<String> = []
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            if isLoading {
                loadingView
            } else if isEditing {
                editView
            } else {
                documentView
            }
        }
        .frame(width: 900, height: 700)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .onAppear {
            initializeData()
            loadMeetingNotes()
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button { onBack() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 18))
                Text("Meeting Notes")
                    .font(.system(size: 18, weight: .bold))
            }
            
            Spacer()
            
            if meeting.meetingLink != nil {
                Button {
                    if let link = meeting.meetingLink, let url = URL(string: link) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "video.fill")
                        Text("Join")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)], startPoint: .top, endPoint: .bottom))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading meeting notes...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document View (Read-only)
    private var documentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Document Header
                VStack(alignment: .center, spacing: 12) {
                    Text("Meeting Notes")
                        .font(.system(size: 28, weight: .bold))
                    
                    HStack(spacing: 16) {
                        metaItem("Meeting", noteTitle)
                        metaItem("Date", formatDisplayDate(noteDate))
                        metaItem("Time", noteTime)
                        if !followUpDate.isEmpty {
                            metaItem("Follow-up", formatDisplayDate(followUpDate))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
                
                Divider()
                
                // Attendees
                if !attendees.isEmpty {
                    documentSection("Attendees") {
                        FlowLayout(spacing: 8) {
                            ForEach(attendees, id: \.self) { attendee in
                                Text(attendee)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // Discussion Points
                let filteredDiscussion = discussionPoints.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredDiscussion.isEmpty || !discussionSections.isEmpty {
                    documentSection("Key Discussion Points") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredDiscussion.enumerated()), id: \.offset) { idx, point in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(idx + 1).")
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(width: 24)
                                    Text(point)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(discussionSections) { section in
                                sectionDocView(section, prefix: "")
                            }
                        }
                    }
                }
                
                // Decisions Made
                let filteredDecisions = decisionsMade.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredDecisions.isEmpty || !decisionSections.isEmpty {
                    documentSection("Decisions Made") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredDecisions.enumerated()), id: \.offset) { idx, decision in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(decision)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(decisionSections) { section in
                                sectionDocView(section, prefix: "D")
                            }
                        }
                    }
                }
                
                // Action Items
                let filteredActions = actionItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredActions.isEmpty || !actionSections.isEmpty {
                    documentSection("Action Items") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredActions.enumerated()), id: \.offset) { idx, item in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("A\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Text(item)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(actionSections) { section in
                                sectionDocView(section, prefix: "A")
                            }
                        }
                    }
                }
                
                // Next Steps
                let filteredSteps = nextSteps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                if !filteredSteps.isEmpty || !nextStepSections.isEmpty {
                    documentSection("Next Steps") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(filteredSteps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("→")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(step)
                                        .font(.system(size: 14))
                                }
                            }
                            
                            ForEach(nextStepSections) { section in
                                sectionDocView(section, prefix: "→")
                            }
                        }
                    }
                }
                
                Divider()
                
                // Edit Button
                HStack {
                    Spacer()
                    Button {
                        isEditing = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit Notes")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(32)
        }
    }
    
    private func sectionDocView(_ section: NoteSection, prefix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .foregroundColor(.secondary)
                Text(section.name)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.top, 8)
            
            ForEach(Array(section.notes.filter { !$0.isEmpty }.enumerated()), id: \.offset) { idx, note in
                HStack(alignment: .top, spacing: 12) {
                    if prefix.isEmpty {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Text(prefix)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 20)
            }
        }
        .padding(12)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func documentSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .padding(.bottom, 4)
            
            content()
        }
    }
    
    private func metaItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    // MARK: - Edit View
    private var editView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Meeting Information Section
                    formSection("Meeting Information", icon: "info.circle.fill") {
                        VStack(spacing: 12) {
                            formField("Meeting Title") {
                                TextField("Enter meeting title", text: $noteTitle)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            HStack(spacing: 12) {
                                formField("Date") {
                                    TextField("YYYY-MM-DD", text: $noteDate)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                formField("Time") {
                                    TextField("HH:MM", text: $noteTime)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                formField("Follow-up Date") {
                                    TextField("YYYY-MM-DD", text: $followUpDate)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    // Attendees Section
                    formSection("Attendees", icon: "person.2.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            // Current attendees
                            FlowLayout(spacing: 8) {
                                ForEach(Array(attendees.enumerated()), id: \.offset) { idx, attendee in
                                    HStack(spacing: 4) {
                                        Text(attendee)
                                            .font(.system(size: 12, weight: .medium))
                                        Button {
                                            attendees.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                                    .clipShape(Capsule())
                                }
                            }
                            
                            // Add attendee
                            HStack(spacing: 8) {
                                TextField("Add attendee...", text: $newAttendee)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(Color(nsColor: NSColor.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onSubmit { addAttendee() }
                                
                                Button { addAttendee() } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Add")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Discussion Points Section
                    notesSection(
                        title: "Key Discussion Points",
                        icon: "list.bullet",
                        items: $discussionPoints,
                        sections: $discussionSections,
                        sectionKey: "discussion"
                    )
                    
                    // Decisions Made Section
                    notesSection(
                        title: "Decisions Made",
                        icon: "checkmark.circle.fill",
                        items: $decisionsMade,
                        sections: $decisionSections,
                        sectionKey: "decisions",
                        itemPrefix: "D"
                    )
                    
                    // Action Items Section
                    notesSection(
                        title: "Action Items",
                        icon: "doc.text.fill",
                        items: $actionItems,
                        sections: $actionSections,
                        sectionKey: "actions",
                        itemPrefix: "A"
                    )
                    
                    // Next Steps Section
                    notesSection(
                        title: "Next Steps",
                        icon: "arrow.right.circle.fill",
                        items: $nextSteps,
                        sections: $nextStepSections,
                        sectionKey: "nextsteps",
                        itemPrefix: "N"
                    )
                }
                .padding(24)
            }
            
            // Save/Cancel buttons
            HStack(spacing: 16) {
                Button {
                    if existingNotes != nil {
                        isEditing = false
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                }
                .buttonStyle(.plain)
                
                Button {
                    saveMeetingNotes()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Saving..." : "Save Meeting Notes")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(20)
            .background(Color(nsColor: NSColor.controlBackgroundColor))
        }
    }
    
    // MARK: - Form Components
    private func formSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            
            content()
        }
        .padding(16)
        .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
    }
    
    private func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            content()
        }
    }
    
    private func notesSection(
        title: String,
        icon: String,
        items: Binding<[String]>,
        sections: Binding<[NoteSection]>,
        sectionKey: String,
        itemPrefix: String = ""
    ) -> some View {
        formSection(title, icon: icon) {
            VStack(alignment: .leading, spacing: 12) {
                // Add Section button
                HStack {
                    Spacer()
                    Button {
                        showAddSection[sectionKey] = !(showAddSection[sectionKey] ?? false)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text("Add Section")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                // Add section input
                if showAddSection[sectionKey] == true {
                    HStack(spacing: 8) {
                        TextField("Section name (e.g., Person name)", text: Binding(
                            get: { newSectionName[sectionKey] ?? "" },
                            set: { newSectionName[sectionKey] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            if let name = newSectionName[sectionKey], !name.isEmpty {
                                let newSection = NoteSection(name: name)
                                sections.wrappedValue.append(newSection)
                                expandedSections.insert(newSection.id)
                                newSectionName[sectionKey] = ""
                                showAddSection[sectionKey] = false
                            }
                        } label: {
                            Text("Create")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showAddSection[sectionKey] = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // General notes label
                Text("General Notes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                // General items
                ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, item in
                    noteItemRow(
                        index: idx,
                        item: item,
                        prefix: itemPrefix.isEmpty ? "\(idx + 1)" : "\(itemPrefix)\(idx + 1)",
                        onUpdate: { items.wrappedValue[idx] = $0 },
                        onAdd: {
                            items.wrappedValue.insert("", at: idx + 1)
                        },
                        onRemove: {
                            if items.wrappedValue.count > 1 {
                                items.wrappedValue.remove(at: idx)
                            }
                        },
                        canRemove: items.wrappedValue.count > 1
                    )
                }
                
                // Sections
                ForEach(Array(sections.wrappedValue.enumerated()), id: \.element.id) { sectionIdx, section in
                    sectionEditView(
                        section: section,
                        sectionIdx: sectionIdx,
                        sections: sections,
                        prefix: itemPrefix
                    )
                }
            }
        }
    }
    
    private func noteItemRow(
        index: Int,
        item: String,
        prefix: String,
        onUpdate: @escaping (String) -> Void,
        onAdd: @escaping () -> Void,
        onRemove: @escaping () -> Void,
        canRemove: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Number badge
            Text(prefix)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.black)
                .clipShape(Circle())
            
            // Text input
            TextEditor(text: Binding(get: { item }, set: onUpdate))
                .font(.system(size: 13))
                .frame(minHeight: 60)
                .padding(8)
                .background(Color(nsColor: NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Controls
            VStack(spacing: 6) {
                Button { onAdd() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                if canRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func sectionEditView(
        section: NoteSection,
        sectionIdx: Int,
        sections: Binding<[NoteSection]>,
        prefix: String
    ) -> some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                if expandedSections.contains(section.id) {
                    expandedSections.remove(section.id)
                } else {
                    expandedSections.insert(section.id)
                }
            } label: {
                HStack {
                    Image(systemName: expandedSections.contains(section.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                    
                    Image(systemName: "person.circle")
                        .font(.system(size: 16))
                    
                    Text(section.name)
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("(\(section.notes.filter { !$0.isEmpty }.count) notes)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        sections.wrappedValue.remove(at: sectionIdx)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(LinearGradient(colors: [Color(nsColor: NSColor.controlBackgroundColor), Color(nsColor: NSColor.controlBackgroundColor).opacity(0.8)], startPoint: .leading, endPoint: .trailing))
            }
            .buttonStyle(.plain)
            
            // Section notes
            if expandedSections.contains(section.id) {
                VStack(spacing: 8) {
                    ForEach(Array(section.notes.enumerated()), id: \.offset) { noteIdx, note in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(prefix.isEmpty ? "" : prefix)\(noteIdx + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.gray)
                                .clipShape(Circle())
                            
                            TextEditor(text: Binding(
                                get: { section.notes[noteIdx] },
                                set: { sections.wrappedValue[sectionIdx].notes[noteIdx] = $0 }
                            ))
                            .font(.system(size: 13))
                            .frame(minHeight: 50)
                            .padding(8)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(spacing: 4) {
                                Button {
                                    sections.wrappedValue[sectionIdx].notes.insert("", at: noteIdx + 1)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.black)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                
                                if section.notes.count > 1 {
                                    Button {
                                        sections.wrappedValue[sectionIdx].notes.remove(at: noteIdx)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .frame(width: 22, height: 22)
                                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
    }
    
    // MARK: - Helper Functions
    private func initializeData() {
        noteTitle = meeting.title
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        noteDate = dateFormatter.string(from: meeting.date)
        noteTime = meeting.timeText
    }
    
    private func formatDisplayDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return dateStr }
        
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return date.map { formatter.string(from: $0) } ?? dateStr
    }
    
    private func addAttendee() {
        let trimmed = newAttendee.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !attendees.contains(trimmed) {
            attendees.append(trimmed)
            newAttendee = ""
        }
    }
    
    // MARK: - API Functions
    private func loadMeetingNotes() {
        guard let meetingId = Int(meeting.originalId) else {
            isLoading = false
            isEditing = true
            return
        }
        
        Task {
            guard let url = URL(string: "\(supabaseURL)/rest/v1/meeting_notes?meeting_id=eq.\(meetingId)&limit=1") else {
                await MainActor.run {
                    isLoading = false
                    isEditing = true
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                let notes = try JSONDecoder().decode([MeetingNoteData].self, from: data)
                
                await MainActor.run {
                    if let note = notes.first {
                        existingNotes = note
                        noteTitle = note.title
                        noteDate = note.date
                        noteTime = note.time
                        attendees = note.attendees
                        discussionPoints = note.discussion_points.isEmpty ? [""] : note.discussion_points
                        decisionsMade = note.decisions_made.isEmpty ? [""] : note.decisions_made
                        actionItems = note.action_items.isEmpty ? [""] : note.action_items
                        nextSteps = note.next_steps.isEmpty ? [""] : note.next_steps
                        discussionSections = note.discussion_sections ?? []
                        decisionSections = note.decision_sections ?? []
                        actionSections = note.action_sections ?? []
                        nextStepSections = note.next_step_sections ?? []
                        followUpDate = note.follow_up_date ?? ""
                        isEditing = false
                    } else {
                        isEditing = true
                    }
                    isLoading = false
                }
            } catch {
                print("Failed to load notes: \(error)")
                await MainActor.run {
                    isLoading = false
                    isEditing = true
                }
            }
        }
    }
    
    private func saveMeetingNotes() {
        guard let meetingId = Int(meeting.originalId) else { return }
        isSaving = true
        
        Task {
            // Clean up data
            let cleanedDiscussion = discussionPoints.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let cleanedDecisions = decisionsMade.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let cleanedActions = actionItems.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let cleanedSteps = nextSteps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            
            func cleanSections(_ sections: [NoteSection]) -> [NoteSection] {
                sections.compactMap { section in
                    let cleaned = section.notes.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    return cleaned.isEmpty ? nil : NoteSection(id: section.id, name: section.name, notes: cleaned)
                }
            }
            
            let noteData = MeetingNoteData(
                id: existingNotes?.id,
                meeting_id: meetingId,
                title: noteTitle,
                date: noteDate,
                time: noteTime,
                attendees: attendees,
                discussion_points: cleanedDiscussion,
                decisions_made: cleanedDecisions,
                action_items: cleanedActions,
                next_steps: cleanedSteps,
                discussion_sections: cleanSections(discussionSections),
                decision_sections: cleanSections(decisionSections),
                action_sections: cleanSections(actionSections),
                next_step_sections: cleanSections(nextStepSections),
                follow_up_date: followUpDate.isEmpty ? nil : followUpDate
            )
            
            let isUpdate = existingNotes?.id != nil
            let urlString: String
            let httpMethod: String
            
            if isUpdate, let id = existingNotes?.id {
                urlString = "\(supabaseURL)/rest/v1/meeting_notes?id=eq.\(id)"
                httpMethod = "PATCH"
            } else {
                urlString = "\(supabaseURL)/rest/v1/meeting_notes"
                httpMethod = "POST"
            }
            
            guard let url = URL(string: urlString) else {
                await MainActor.run { isSaving = false }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = httpMethod
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            do {
                let encoder = JSONEncoder()
                request.httpBody = try encoder.encode(noteData)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    if let savedNotes = try? JSONDecoder().decode([MeetingNoteData].self, from: data).first {
                        await MainActor.run {
                            existingNotes = savedNotes
                            isEditing = false
                            isSaving = false
                        }
                    } else {
                        await MainActor.run {
                            isEditing = false
                            isSaving = false
                        }
                    }
                } else {
                    print("Save failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                    await MainActor.run { isSaving = false }
                }
            } catch {
                print("Failed to save notes: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func calculateLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        let containerWidth = proposal.width ?? .infinity
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > containerWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Full App Window View
struct FullAppWindowView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedTab = 0
    @State private var tabDirection: Int = 0
    @State private var isAppearing = false

    var body: some View {
        ZStack {
            Color(nsColor: NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            if authManager.isAuthenticated {
                mainContent
                    .opacity(isAppearing ? 1 : 0)
                    .scaleEffect(isAppearing ? 1 : 0.95)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isAppearing)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            withAnimation {
                isAppearing = true
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerBar
            
            // Main content area with smooth transitions
            ZStack {
                Color(nsColor: NSColor.windowBackgroundColor)
                
                // Use id to force view recreation for smooth transition
                Group {
                switch selectedTab {
                case 0:
                    FullCalendarView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                case 1:
                    FullMeetingsView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                case 2:
                    FullRuleBookView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                case 3:
                    FullJournalView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                default:
                    FullCalendarView()
                        .environmentObject(taskManager)
                        .environmentObject(authManager)
                }
            }
                .id(selectedTab)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
        .frame(minWidth: 1200, minHeight: 800)
        .onAppear {
            if let userId = authManager.currentUser?.id {
                Task {
                    await taskManager.fetchTasks(for: userId)
                }
            }
        }
    }
    
    private var headerBar: some View {
        HStack(spacing: 0) {
            // Left section - Logo and progress
            HStack(spacing: 16) {
            // Logo
                HStack(spacing: 8) {
                    if let nsImage = loadAppLogo() {
                        Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
                
                Text("Focus")
                        .font(.system(size: 16, weight: .semibold))
            }
            
                // Progress pill
            let progress = getProgress()
                HStack(spacing: 8) {
                ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                    .progressViewStyle(.linear)
                        .frame(width: 80)
                    .tint(progress.completed == progress.total ? .green : .accentColor)
                
                Text("\(progress.completed)/\(progress.total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: NSColor.controlBackgroundColor))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Center section - Tab Selector (prominent)
            HStack(spacing: 4) {
                tabButton("Personal", icon: "calendar", index: 0)
                tabButton("Meetings", icon: "video", index: 1)
                tabButton("Rule Book", icon: "book.closed", index: 2)
                tabButton("Journal", icon: "book.pages", index: 3)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: NSColor.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color(nsColor: NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            )
            
            Spacer()
            
            // Right section - Actions
            HStack(spacing: 12) {
                Button {
                    // Open Journaling
                    withAnimation { selectedTab = 3 }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 11))
                        Text("Journal")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button {
                    // Add Task
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Add Task")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            ZStack {
                Color(nsColor: NSColor.controlBackgroundColor)
                
                // Subtle gradient for depth
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(nsColor: NSColor.separatorColor), Color(nsColor: NSColor.separatorColor).opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .bottom
        )
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    @State private var hoveredTab: Int? = nil
    
    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            let oldTab = selectedTab
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                tabDirection = index > oldTab ? 1 : -1
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: selectedTab == index ? .semibold : .regular))
                    .symbolEffect(.bounce, value: selectedTab == index)
                Text(title)
                    .font(.system(size: 13, weight: selectedTab == index ? .semibold : .medium))
            }
            .foregroundColor(selectedTab == index ? .white : (hoveredTab == index ? .primary : .secondary))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    if selectedTab == index {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    } else if hoveredTab == index {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(selectedTab == index ? 1.02 : (hoveredTab == index ? 1.01 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredTab = isHovering ? index : nil
            }
        }
    }
    
    private func getProgress() -> (completed: Int, total: Int) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayTasks = taskManager.todayTasks.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let total = todayTasks.count
        let completed = todayTasks.filter { $0.isCompleted }.count
        return (completed, total)
    }
}

// MARK: - Custom Floating Window (stays visible above all apps including full screen)
class FloatingAppWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        // Set to floating level that appears above full-screen apps
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
#endif

// MARK: - macOS App Delegate
#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var notifiedTaskIds: Set<String> = []
    private var monitorTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set dock icon from bundle using global loader
        if let iconImage = loadAppLogo() {
            NSApp.applicationIconImage = iconImage
        }

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permission with completion handler
        requestNotificationPermission()
        
        // Set up notification categories for action buttons
        setupNotificationCategories()
        
        // Start task monitoring (local)
        startTaskMonitoring()
        
        // Schedule notifications after a delay to let tasks load
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.scheduleAllTaskNotifications()
        }
        
        // Run as regular app (show in dock with icon)
        NSApp.setActivationPolicy(.regular)
        
        // Start floating notification task monitoring after tasks load
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            FloatingNotificationManager.shared.startTaskMonitoring()
        }
        
        print("Focus app launched")
    }
    
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        
        // Set delegate to receive notifications while app is in foreground
        center.delegate = self
        
        // Always request permission (will prompt user if not determined)
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission GRANTED")
                    // Send immediate test notification
                    self.sendImmediateNotification()
                } else {
                    print("Notification permission DENIED: \(error?.localizedDescription ?? "unknown")")
                    // Open System Settings for notifications
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    func sendImmediateNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Focus App"
        content.subtitle = "Notifications Enabled!"
        content.body = "You will receive reminders 5 minutes before your tasks."
        content.sound = .default
        content.categoryIdentifier = "FOCUS_TASK"
        
        // Trigger immediately (1 second)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-welcome-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            } else {
                print("Welcome notification scheduled!")
            }
        }
    }
    
    func setupNotificationCategories() {
        // Rize-style minimal actions
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE",
            title: "Done",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "checkmark")
        )
        
        let snooze5Action = UNNotificationAction(
            identifier: "SNOOZE_5",
            title: "+5 min",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock")
        )
        
        let snooze15Action = UNNotificationAction(
            identifier: "SNOOZE_15",
            title: "+15 min",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath")
        )
        
        let skipAction = UNNotificationAction(
            identifier: "SKIP",
            title: "Skip",
            options: [.destructive],
            icon: UNNotificationActionIcon(systemImageName: "xmark")
        )
        
        // Task category
        let taskCategory = UNNotificationCategory(
            identifier: "FOCUS_TASK",
            actions: [completeAction, snooze5Action, snooze15Action, skipAction],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle, .hiddenPreviewsShowSubtitle]
        )
        
        // Meeting category
        let joinAction = UNNotificationAction(
            identifier: "JOIN",
            title: "Join",
            options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "video")
        )
        
        let meetingCategory = UNNotificationCategory(
            identifier: "FOCUS_MEETING",
            actions: [joinAction, snooze5Action, snooze15Action],
            intentIdentifiers: [],
            options: [.customDismissAction, .hiddenPreviewsShowTitle]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([taskCategory, meetingCategory])
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let taskId = response.notification.request.content.userInfo["taskId"] as? String ?? ""
        
        switch response.actionIdentifier {
        case "COMPLETE":
            print("User marked task complete: \(taskId)")
            Task { @MainActor in
                // Find and complete the task
                if let task = TaskManager.shared.todayTasks.first(where: { $0.id == taskId }) {
                    await TaskManager.shared.toggleComplete(task: task)
                }
            }
            
        case "SNOOZE_5":
            print("User snoozed task 5 min: \(taskId)")
            rescheduleNotification(taskId: taskId, minutes: 5)
            
        case "SNOOZE_15":
            print("User snoozed task 15 min: \(taskId)")
            rescheduleNotification(taskId: taskId, minutes: 15)
            
        case "SKIP":
            print("User skipped task: \(taskId)")
            Task { @MainActor in
                if let task = TaskManager.shared.todayTasks.first(where: { $0.id == taskId }) {
                    TaskManager.shared.skipTask(task, reason: "Skipped from notification")
                }
            }
            
        default:
            break
        }
        
        completionHandler()
    }
    
    // Show notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner, play sound even when app is open
        completionHandler([.banner, .sound, .badge])
    }
    
    private func rescheduleNotification(taskId: String, minutes: Int) {
        Task { @MainActor in
            guard let task = TaskManager.shared.todayTasks.first(where: { $0.id == taskId }) else { return }
            
            let newTime = Date().addingTimeInterval(Double(minutes * 60))
            
            let content = UNMutableNotificationContent()
            content.title = "Reminder: \(task.title)"
            content.subtitle = "Snoozed task"
            content.body = "Your task is waiting"
            content.sound = .default
            content.categoryIdentifier = "TASK_REMINDER"
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["taskId": taskId]
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
            let request = UNNotificationRequest(identifier: "snooze-\(taskId)-\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
            print("Rescheduled notification for \(minutes) minutes")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running when windows are closed
        return false
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Prevent Command+Q from quitting - keep menu bar icon visible
        // User can force quit via Activity Monitor or Option+Command+Q if needed
        print("App termination cancelled - app stays in menu bar")
        
        // Hide all windows instead of quitting
        for window in NSApp.windows {
            window.orderOut(nil)
        }
        
        return .terminateCancel  // Prevent quitting, keep menu bar icon
    }
    
    func startTaskMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingTasks()
            }
        }
        Task { @MainActor in
            checkUpcomingTasks()
        }
    }
    
    @MainActor
    func checkUpcomingTasks() {
        let tasks = TaskManager.shared.todayTasks
        let now = Date()
        let calendar = Calendar.current
        
        for task in tasks {
            guard let startTime = task.startTime,
                  !task.isCompleted,
                  !task.isSkipped,
                  !notifiedTaskIds.contains(task.id) else { continue }
            
            let diff = calendar.dateComponents([.minute], from: now, to: startTime).minute ?? 0
            
            if diff >= 4 && diff <= 6 {
                sendNotification(for: task, minutesUntil: diff)
                notifiedTaskIds.insert(task.id)
            }
        }
    }
    
    @MainActor
    func scheduleAllTaskNotifications() {
        let tasks = TaskManager.shared.todayTasks
        let now = Date()
        
        print("Scheduling notifications for \(tasks.count) tasks")
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        var scheduledCount = 0
        for task in tasks {
            guard let startTime = task.startTime,
                  !task.isCompleted,
                  !task.isSkipped else { continue }
            
            let notifyTime = startTime.addingTimeInterval(-5 * 60)
            
            if notifyTime > now {
                scheduleNotification(for: task, at: notifyTime)
                scheduledCount += 1
                print("Scheduled notification for '\(task.title)' at \(notifyTime)")
            }
        }
        
        print("Total notifications scheduled: \(scheduledCount)")
        
        // Send a test notification after 5 seconds to verify notifications work
        sendTestNotification()
    }
    
    func sendTestNotification() {
        print("Attempting to send test notification...")
        
        let content = UNMutableNotificationContent()
        content.title = "Focus App"
        content.subtitle = "Test Notification"
        content.body = "If you see this, notifications are working!"
        content.sound = .default
        content.categoryIdentifier = "FOCUS_TASK"

        // Send after 2 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-test-\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Test notification FAILED: \(error.localizedDescription)")
            } else {
                print("Test notification SCHEDULED - should appear in 2 seconds")
            }
        }
    }
    
    func scheduleNotification(for task: TaskItem, at date: Date) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = task.startTime != nil ? timeFormatter.string(from: task.startTime!) : ""
        
        // Rize-style notification
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.subtitle = task.title
        content.body = "Starting in 5 min \u{2022} \(timeString)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        content.categoryIdentifier = "FOCUS_TASK"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "focus-reminders"
        content.userInfo = ["taskId": task.id, "taskType": task.type.displayName]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "focus-scheduled-\(task.id)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendNotification(for task: TaskItem, minutesUntil: Int) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeString = task.startTime != nil ? timeFormatter.string(from: task.startTime!) : ""
        
        // Rize-style notification
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.subtitle = task.title
        content.body = "\(minutesUntil) min remaining \u{2022} \(timeString)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Tri-tone"))
        content.categoryIdentifier = "FOCUS_TASK"
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "focus-reminders"
        content.userInfo = ["taskId": task.id]

        let request = UNNotificationRequest(
            identifier: "focus-immediate-\(task.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
}

// MARK: - Floating Notification Manager
class FloatingNotificationManager {
    static let shared = FloatingNotificationManager()
    
    private var notificationPanel: NSPanel?
    private var keepOnTopTimer: Timer?
    private var taskMonitorTimer: Timer?
    private var notifiedTaskIds: Set<String> = []
    private var autoDismissWorkItem: DispatchWorkItem?
    private var clickMonitor: Any?
    
    func startTaskMonitoring() {
        // Check every 30 seconds for upcoming tasks
        taskMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkUpcomingTasks()
        }
        // Also check immediately
        checkUpcomingTasks()
    }
    
    func stopTaskMonitoring() {
        taskMonitorTimer?.invalidate()
        taskMonitorTimer = nil
    }
    
    private func checkUpcomingTasks() {
        Task { @MainActor in
            let tasks = TaskManager.shared.todayTasks
            let calendar = Calendar.current
            let now = Date()
            let currentHour = calendar.component(.hour, from: now)
            let currentMinute = calendar.component(.minute, from: now)
            let currentTotalMinutes = currentHour * 60 + currentMinute
            
            for task in tasks {
                // Skip completed tasks
                if task.isCompleted { continue }
                
                // Skip already notified tasks
                let notificationId = "\(task.id)-\(task.startHour)-\(task.startMinute)"
                if self.notifiedTaskIds.contains(notificationId) { continue }
                
                let taskTotalMinutes = task.startHour * 60 + task.startMinute
                let minutesUntilTask = taskTotalMinutes - currentTotalMinutes
                
                // Notify if task is 5 minutes away or less (but not past)
                if minutesUntilTask >= 0 && minutesUntilTask <= 5 {
                    self.notifiedTaskIds.insert(notificationId)
                    self.showTaskReminder(task: task, minutesBefore: minutesUntilTask)
                }
            }
            
            // Clean up old notification IDs at midnight
            if currentHour == 0 && currentMinute == 0 {
                self.notifiedTaskIds.removeAll()
            }
        }
    }
    
    func show(title: String, subtitle: String = "", body: String, duration: TimeInterval = 8.0) {
        DispatchQueue.main.async {
            self.dismiss()
            NSSound(named: "Glass")?.play()
            
            let notificationView = FloatingNotificationView(
                title: title,
                subtitle: subtitle,
                message: body,
                task: nil,
                onDone: nil,
                onSnooze: nil,
                onSkip: nil,
                onDismiss: { self.dismiss() },
                showCloseButton: true  // Always show X button
            )
            
            self.showWindow(with: notificationView, height: 90, duration: duration, hasActions: false)
        }
    }
    
    func showTaskReminder(task: TaskItem, minutesBefore: Int = 5) {
        DispatchQueue.main.async {
            self.dismiss()
            NSSound(named: "Glass")?.play()
            
            let timeStr = self.formatTime12Hour(hour: task.startHour, minute: task.startMinute)
            let isNow = minutesBefore == 0
            let message = isNow ? "Starting now!" : "Starting in \(minutesBefore) min • \(timeStr)"
            
            let notificationView = FloatingNotificationView(
                title: "Task Reminder",
                subtitle: task.title,
                message: message,
                task: task,
                onDone: {
                    // markTaskDone shows its own notification, don't call dismiss after
                    self.markTaskDone(task)
                },
                onSnooze: {
                    // snoozeTask shows its own notification, don't call dismiss after
                    self.snoozeTask(task)
                },
                onSkip: {
                    // skipTask shows its own notification, don't call dismiss after
                    self.skipTask(task)
                },
                onDismiss: { self.dismiss() },
                showCloseButton: true
            )
            
            self.showWindow(with: notificationView, height: 140, duration: 30.0, hasActions: true)
        }
    }
    
    private func showWindow(with view: FloatingNotificationView, height: CGFloat, duration: TimeInterval, hasActions: Bool = false) {
        let windowWidth: CGFloat = 350  // Match notification width
        let windowHeight: CGFloat = height
        
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        // Start position: off-screen to the right
        let startX = screenFrame.maxX + 20
        // End position: top-right corner
        let endX = screenFrame.maxX - windowWidth - 16
        let windowY = screenFrame.maxY - windowHeight - 8
        
        // Create a floating panel (like system notifications)
        let panel = NSPanel(
            contentRect: NSRect(x: startX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu // High level that appears above most windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false  // Disable so clicks work
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0
        panel.isFloatingPanel = true
        panel.acceptsMouseMovedEvents = true
        
        // Store reference
        self.notificationPanel = panel
        
        // Show panel (starts off-screen)
        panel.orderFrontRegardless()
        
        // Smooth slide-in animation from right
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(NSPoint(x: endX, y: windowY))
            panel.animator().alphaValue = 1
        }
        
        // Cancel any existing monitors/timers
        if let monitor = self.clickMonitor {
            NSEvent.removeMonitor(monitor)
            self.clickMonitor = nil
        }
        self.autoDismissWorkItem?.cancel()
        self.keepOnTopTimer?.invalidate()
        self.keepOnTopTimer = nil
        
        // Only add click-to-dismiss for notifications WITHOUT action buttons
        // Task reminders have buttons (Done, Snooze, Skip) so don't auto-dismiss on click
        if !hasActions {
            self.clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                guard let self = self, let panel = self.notificationPanel else { return event }
                
                // Check if click is within the panel
                let clickLocation = NSEvent.mouseLocation
                if panel.frame.contains(clickLocation) {
                    print("DEBUG: Click detected on notification panel - dismissing")
                    self.dismiss()
                    return nil // Consume the event
                }
                return event
            }
        }
        
        // Auto-dismiss after duration
        let manager = self
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + duration) {
            DispatchQueue.main.async {
                print("DEBUG: Auto-dismiss triggered after \(duration)s")
                manager.dismiss()
            }
        }
    }
    
    func dismiss() {
        print("DEBUG: dismiss() called")
        
        // Remove click monitor
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
        keepOnTopTimer?.invalidate()
        keepOnTopTimer = nil
        
        guard let panel = notificationPanel else { 
            print("DEBUG: No panel to dismiss")
            return 
        }
        
        guard let screen = NSScreen.main else {
            panel.orderOut(nil)
            self.notificationPanel = nil
            return
        }
        
        // Slide out animation to right
        let endX = screen.visibleFrame.maxX + 20
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrameOrigin(NSPoint(x: endX, y: panel.frame.origin.y))
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            self.notificationPanel = nil
        })
    }
    
    private func markTaskDone(_ task: TaskItem) {
        // Toggle completion - no notification needed
        Task {
            await TaskManager.shared.toggleComplete(task: task)
        }
        // Just dismiss the current notification, don't show completion notification
        self.dismiss()
    }
    
    private func snoozeTask(_ task: TaskItem) {
        // Remove from notified so it can notify again
        let notificationId = "\(task.id)-\(task.startHour)-\(task.startMinute)"
        notifiedTaskIds.remove(notificationId)
        
        // Just dismiss - no confirmation notification needed
        self.dismiss()
        
        // Re-notify in 5 minutes (300 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
            self?.showTaskReminder(task: task, minutesBefore: 0)
        }
    }
    
    private func skipTask(_ task: TaskItem) {
        // Just dismiss - no confirmation notification needed
        self.dismiss()
    }
    
    private func formatTime12Hour(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Floating Notification View with Actions
// Close button that works in non-activating panels
struct CloseButton: NSViewRepresentable {
    let onDismiss: () -> Void
    
    func makeNSView(context: Context) -> ClickableCloseButton {
        let button = ClickableCloseButton(onDismiss: onDismiss)
        return button
    }
    
    func updateNSView(_ nsView: ClickableCloseButton, context: Context) {}
}

class ClickableCloseButton: NSView {
    private let onDismiss: () -> Void
    private var isHovering = false
    private var button: NSButton!
    
    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Use NSButton which handles clicks better
        button = NSButton(frame: bounds)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.title = ""
        button.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
        button.contentTintColor = NSColor.secondaryLabelColor
        button.target = self
        button.action = #selector(buttonClicked)
        button.focusRingType = .none
        addSubview(button)
        
        // Add tracking area for hover
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    @objc private func buttonClicked() {
        print("DEBUG: Close button clicked!")
        onDismiss()
    }
    
    override func mouseDown(with event: NSEvent) {
        print("DEBUG: mouseDown on close button view")
        onDismiss()
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        button.contentTintColor = NSColor.labelColor
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovering = false
        button.contentTintColor = NSColor.secondaryLabelColor
    }
    
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct FloatingNotificationView: View {
    let title: String
    let subtitle: String
    let message: String
    let task: TaskItem?
    let onDone: (() -> Void)?
    let onSnooze: (() -> Void)?
    let onSkip: (() -> Void)?
    let onDismiss: () -> Void
    var iconName: String = "bell.fill"
    var showCloseButton: Bool = true
    
    @State private var isAppearing = false
    @State private var iconPulse = false
    @State private var buttonHover: String? = nil
    @State private var isHovered = false
    
    var hasActions: Bool {
        onDone != nil || onSnooze != nil || onSkip != nil
    }
    
    // Get task color based on type
    private var accentColor: Color {
        if let task = task {
            switch task.type {
            case .timeBlock(let blockType):
                return blockType.color
            case .meeting: return .purple
            case .todo: return .blue
            case .social: return .pink
            }
        }
        return .orange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main notification card
            HStack(spacing: 16) {
                // Left accent bar + icon
                HStack(spacing: 0) {
                    // Colored accent bar
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 48, height: 48)
                        
                        Circle()
                            .fill(accentColor.opacity(iconPulse ? 0.3 : 0))
                            .frame(width: 48, height: 48)
                            .scaleEffect(iconPulse ? 1.4 : 1)
                        
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(accentColor)
                    }
                    .padding(.leading, 12)
                }
                .scaleEffect(isAppearing ? 1 : 0.5)
                .opacity(isAppearing ? 1 : 0)
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                    // Header: Title + Time
                HStack(alignment: .top) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("now")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accentColor.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    
                    // Task name - prominent
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    // Time info
                    if !message.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .medium))
                            Text(message)
                                .font(.system(size: 12, weight: .medium))
                        }
                            .foregroundColor(.secondary)
                    }
                }
                .offset(x: isAppearing ? 0 : 20)
                .opacity(isAppearing ? 1 : 0)
                
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .padding(.trailing, 36) // Space for close button
            
            // Action buttons - Below content, full width
            if hasActions {
                Divider()
                    .opacity(0.5)
                
                HStack(spacing: 0) {
                    if let onDone = onDone {
                        NotificationActionButton(
                            label: "Done",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            isHovered: buttonHover == "done",
                            action: onDone
                        )
                        .onHover { h in buttonHover = h ? "done" : nil }
                        
                        if onSnooze != nil || onSkip != nil {
                            Divider()
                                .frame(height: 32)
                                .opacity(0.3)
                        }
                    }
                    
                    if let onSnooze = onSnooze {
                        NotificationActionButton(
                            label: "5 min",
                            icon: "clock.arrow.circlepath",
                            color: .purple,
                            isHovered: buttonHover == "snooze",
                            action: onSnooze
                        )
                        .onHover { h in buttonHover = h ? "snooze" : nil }
                        
                        if onSkip != nil {
                            Divider()
                                .frame(height: 32)
                                .opacity(0.3)
                        }
                    }
                    
                    if let onSkip = onSkip {
                        NotificationActionButton(
                            label: "Skip",
                            icon: "forward.fill",
                            color: .gray,
                            isHovered: buttonHover == "skip",
                            action: onSkip
                        )
                        .onHover { h in buttonHover = h ? "skip" : nil }
                    }
                }
                .frame(height: 44)
                .offset(y: isAppearing ? 0 : 10)
                .opacity(isAppearing ? 1 : 0)
            }
        }
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if showCloseButton {
                        Button {
                            onDismiss()
                        } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(
                            Circle()
                                .fill(Color.secondary.opacity(isHovered ? 0.2 : 0.1))
                        )
                        }
                        .buttonStyle(.plain)
                .padding(10)
                .onHover { h in isHovered = h }
            }
        }
        .scaleEffect(isAppearing ? 1 : 0.9)
        .offset(y: isAppearing ? 0 : -20)
        .opacity(isAppearing ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAppearing = true
            }
            // Pulse animation for icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    iconPulse = true
                }
            }
        }
    }
}

// Helper view for notification action buttons
struct NotificationActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isHovered ? color : .primary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(isHovered ? color.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Rule Row View
struct RuleRowView: View {
    let rule: Rule
    @ObservedObject var ruleManager: RuleManager
    
    @State private var isHovered = false
    @State private var isAnimating = false
    @State private var showCheckAnimation = false
    @State private var progressAnimation: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress circle / Check button - tap to toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showCheckAnimation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if rule.isCompletedForPeriod {
                        // Uncheck - decrement
                        ruleManager.decrementRule(rule)
                    } else {
                        // Check - increment
                        ruleManager.incrementRule(rule)
                    }
                    showCheckAnimation = false
                }
            } label: {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(rule.color.opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: CGFloat(rule.currentCount) / CGFloat(rule.targetCount))
                        .stroke(rule.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    
                    // Center content
                    if rule.isCompletedForPeriod {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(rule.color)
                            .scaleEffect(showCheckAnimation ? 1.3 : 1.0)
                    } else {
                        Text("\(rule.currentCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(rule.color)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Rule info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let iconName = rule.emoji {
                        Image(systemName: iconName)
                            .font(.system(size: 12))
                            .foregroundColor(rule.color)
                    }
                    Text(rule.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(rule.isCompletedForPeriod ? .secondary : .primary)
                        .strikethrough(rule.isCompletedForPeriod)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Target
                    HStack(spacing: 3) {
                        Image(systemName: "target")
                            .font(.system(size: 9))
                        Text("\(rule.currentCount)/\(rule.targetCount)")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    
                    // Streak
                    if rule.streakCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text("\(rule.streakCount)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Points
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                        Text("\(rule.totalPoints)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Period badge
            Text(rule.period.displayName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(rule.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rule.color.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color(nsColor: NSColor.controlBackgroundColor) : Color(nsColor: NSColor.controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? rule.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .shadow(color: isHovered ? .black.opacity(0.08) : .clear, radius: 4, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Add Rule Sheet
struct AddRuleSheet: View {
    @ObservedObject var ruleManager: RuleManager
    let userId: Int
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPeriod: RulePeriod = .daily
    @State private var targetCount = 1
    @State private var selectedIcon = "checkmark.circle"
    @State private var selectedColor: Color = .blue
    
    // SF Symbol icons instead of emojis
    let icons = ["checkmark.circle", "dumbbell", "figure.run", "book", "drop", "leaf", "moon.zzz", "figure.mind.and.body", "dollarsign.circle", "target", "clock", "xmark.circle"]
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .mint, .cyan, .indigo]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Rule")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Icon picker (SF Symbols instead of emojis)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? selectedColor : .secondary)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? selectedColor.opacity(0.2) : Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(selectedIcon == icon ? selectedColor : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rule Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., No soda, Go to gym", text: $title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Period selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Frequency")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(RulePeriod.allCases, id: \.self) { period in
                                Button {
                                    selectedPeriod = period
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: period.icon)
                                            .font(.system(size: 16))
                                        Text(period.displayName)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(selectedPeriod == period ? .white : period.color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedPeriod == period ? period.color : period.color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Target count
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target (times per \(selectedPeriod.displayName.lowercased()))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Button {
                                if targetCount > 1 { targetCount -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(targetCount)")
                                .font(.system(size: 32, weight: .bold))
                                .frame(width: 60)
                            
                            Button {
                                targetCount += 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(selectedColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                        )
                                        .shadow(color: selectedColor == color ? color.opacity(0.5) : .clear, radius: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Points preview
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Earn \(10 * selectedPeriod.pointsMultiplier) pts per check, +\(selectedPeriod.pointsMultiplier * 10) bonus on completion")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
            }
            
            // Add button
            Button {
                guard !title.isEmpty else { return }
                ruleManager.addRule(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    period: selectedPeriod,
                    targetCount: targetCount,
                    emoji: selectedIcon,  // Now stores SF Symbol name instead of emoji
                    colorHex: selectedColor.toHex(),
                    userId: userId
                )
                isPresented = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Rule")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        .background(
                    LinearGradient(
                        colors: title.isEmpty ? [Color.gray] : [selectedColor, selectedColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(title.isEmpty)
            .padding(20)
        }
        .frame(width: 400, height: 600)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
}

// MARK: - Add Rule Window Content (for floating window)
struct AddRuleWindowContent: View {
    @ObservedObject var ruleManager: RuleManager
    let userId: Int
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPeriod: RulePeriod = .daily
    @State private var targetCount = 1
    @State private var selectedIcon = "checkmark.circle"
    @State private var selectedColor: Color = .blue
    
    // SF Symbol icons
    let icons = ["checkmark.circle", "dumbbell", "figure.run", "book", "drop", "leaf", "moon.zzz", "figure.mind.and.body", "dollarsign.circle", "target", "clock", "xmark.circle"]
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .mint, .cyan, .indigo]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Rule")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    closeWindow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Icon picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? selectedColor : .secondary)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? selectedColor.opacity(0.2) : Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .strokeBorder(selectedIcon == icon ? selectedColor : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rule Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("e.g., No soda, Go to gym", text: $title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // Period selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Frequency")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(RulePeriod.allCases, id: \.self) { period in
                                Button {
                                    selectedPeriod = period
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: period.icon)
                                            .font(.system(size: 16))
                                        Text(period.displayName)
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .foregroundColor(selectedPeriod == period ? .white : period.color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(selectedPeriod == period ? period.color : period.color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Target count
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target (times per \(selectedPeriod.displayName.lowercased()))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Button {
                                if targetCount > 1 { targetCount -= 1 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text("\(targetCount)")
                                .font(.system(size: 32, weight: .bold))
                                .frame(width: 60)
                            
                            Button {
                                targetCount += 1
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(selectedColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                        )
                                        .shadow(color: selectedColor == color ? color.opacity(0.5) : .clear, radius: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Points preview
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Earn \(10 * selectedPeriod.pointsMultiplier) pts per check, +\(selectedPeriod.pointsMultiplier * 10) bonus on completion")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
            }
            
            // Add button
            Button {
                guard !title.isEmpty else { return }
                ruleManager.addRule(
                    title: title,
                    description: description.isEmpty ? nil : description,
                    period: selectedPeriod,
                    targetCount: targetCount,
                    emoji: selectedIcon,
                    colorHex: selectedColor.toHex(),
                    userId: userId
                )
                closeWindow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Rule")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: title.isEmpty ? [Color.gray] : [selectedColor, selectedColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(title.isEmpty)
            .padding(20)
        }
        .frame(width: 400, height: 600)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
    }
    
    private func closeWindow() {
        // Close the hosting window
        NSApp.keyWindow?.close()
    }
}

// Color to hex extension
extension Color {
    func toHex() -> String? {
        #if os(macOS)
        let nsColor = NSColor(self)
        guard let converted = nsColor.usingColorSpace(.deviceRGB) else { return nil }
        let r = Int(converted.redComponent * 255)
        let g = Int(converted.greenComponent * 255)
        let b = Int(converted.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
        #endif
    }
}


#endif
