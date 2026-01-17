//
//  RuleManager.swift
//  Focus
//
//  Manages Rule Book functionality with gamification
//

import Foundation
import SwiftUI

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
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    private init() {
        // Load from UserDefaults for offline support
        loadFromLocalStorage()
    }
    
    // MARK: - Local Storage
    
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
    
    // MARK: - Computed Properties
    
    var dailyRules: [Rule] {
        rules.filter { $0.period == .daily && $0.isActive }
    }
    
    var weeklyRules: [Rule] {
        rules.filter { $0.period == .weekly && $0.isActive }
    }
    
    var monthlyRules: [Rule] {
        rules.filter { $0.period == .monthly && $0.isActive }
    }
    
    var yearlyRules: [Rule] {
        rules.filter { $0.period == .yearly && $0.isActive }
    }
    
    var todayProgress: Double {
        let daily = dailyRules
        guard !daily.isEmpty else { return 100 }
        let completed = daily.filter { $0.isCompletedForPeriod }.count
        return Double(completed) / Double(daily.count) * 100
    }
    
    var weekProgress: Double {
        let weekly = weeklyRules
        guard !weekly.isEmpty else { return 100 }
        let completed = weekly.filter { $0.isCompletedForPeriod }.count
        return Double(completed) / Double(weekly.count) * 100
    }
    
    // MARK: - CRUD Operations
    
    func addRule(title: String, description: String?, period: RulePeriod, targetCount: Int, emoji: String?, colorHex: String?, userId: Int) {
        let now = Date()
        let rule = Rule(
            id: UUID().uuidString,
            userId: userId,
            title: title,
            description: description,
            period: period,
            targetCount: max(1, targetCount),
            currentCount: 0,
            streakCount: 0,
            bestStreak: 0,
            totalCompletions: 0,
            totalPoints: 0,
            isActive: true,
            createdAt: now,
            lastResetAt: now,
            lastCompletedAt: nil,
            emoji: emoji,
            colorHex: colorHex
        )
        
        rules.append(rule)
        saveToLocalStorage()
        
        // Check for first rule badge
        if rules.count == 1 {
            awardBadge("first_rule")
        }
        
        // Sync to server
        Task {
            await syncRuleToServer(rule)
        }
    }
    
    func updateRule(_ rule: Rule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveToLocalStorage()
            Task {
                await syncRuleToServer(rule)
            }
        }
    }
    
    func deleteRule(_ rule: Rule) {
        rules.removeAll { $0.id == rule.id }
        saveToLocalStorage()
        Task {
            await deleteRuleFromServer(rule.id)
        }
    }
    
    // MARK: - Check/Uncheck Rules
    
    func toggleRuleCheck(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        
        var updatedRule = rules[index]
        
        if updatedRule.currentCount < updatedRule.targetCount {
            // Increment
            updatedRule.currentCount += 1
            updatedRule.lastCompletedAt = Date()
            
            // Award points for each check
            let points = 10 * updatedRule.period.pointsMultiplier
            updatedRule.totalPoints += points
            userStats.totalPoints += points
            
            // Check if completed for period
            if updatedRule.currentCount >= updatedRule.targetCount {
                updatedRule.streakCount += 1
                updatedRule.totalCompletions += 1
                userStats.totalRulesCompleted += 1
                
                // Update best streak
                if updatedRule.streakCount > updatedRule.bestStreak {
                    updatedRule.bestStreak = updatedRule.streakCount
                }
                
                // Bonus points for completion
                let bonusPoints = updatedRule.pointsForCompletion
                updatedRule.totalPoints += bonusPoints
                userStats.totalPoints += bonusPoints
            }
            
            // Update level
            let oldLevel = userStats.currentLevel
            userStats.currentLevel = userStats.totalPoints / 100
            if userStats.currentLevel > oldLevel {
                showLevelUpAnimation = true
            }
            
            // Check for badges
            checkForBadges()
            
        } else {
            // Decrement (undo)
            if updatedRule.currentCount > 0 {
                updatedRule.currentCount -= 1
            }
        }
        
        rules[index] = updatedRule
        saveToLocalStorage()
        
        Task {
            await syncRuleToServer(updatedRule)
        }
    }
    
    func incrementRule(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        
        var updatedRule = rules[index]
        if updatedRule.currentCount < updatedRule.targetCount {
            updatedRule.currentCount += 1
            updatedRule.lastCompletedAt = Date()
            
            // Award points
            let points = 10 * updatedRule.period.pointsMultiplier
            updatedRule.totalPoints += points
            userStats.totalPoints += points
            
            // Check completion
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
            
            // Update level
            let oldLevel = userStats.currentLevel
            userStats.currentLevel = userStats.totalPoints / 100
            if userStats.currentLevel > oldLevel {
                showLevelUpAnimation = true
            }
            
            rules[index] = updatedRule
            saveToLocalStorage()
            checkForBadges()
        }
    }
    
    // MARK: - Auto Reset
    
    func checkAndResetPeriods() {
        let now = Date()
        let calendar = Calendar.current
        
        for index in rules.indices {
            var rule = rules[index]
            var needsReset = false
            
            switch rule.period {
            case .daily:
                // Reset if last reset was not today
                if !calendar.isDateInToday(rule.lastResetAt) {
                    needsReset = true
                }
                
            case .weekly:
                // Reset if we're in a new week (week starts Sunday)
                let lastResetWeek = calendar.component(.weekOfYear, from: rule.lastResetAt)
                let currentWeek = calendar.component(.weekOfYear, from: now)
                let lastResetYear = calendar.component(.year, from: rule.lastResetAt)
                let currentYear = calendar.component(.year, from: now)
                if currentWeek != lastResetWeek || currentYear != lastResetYear {
                    needsReset = true
                }
                
            case .monthly:
                // Reset if we're in a new month
                let lastResetMonth = calendar.component(.month, from: rule.lastResetAt)
                let currentMonth = calendar.component(.month, from: now)
                let lastResetYear = calendar.component(.year, from: rule.lastResetAt)
                let currentYear = calendar.component(.year, from: now)
                if currentMonth != lastResetMonth || currentYear != lastResetYear {
                    needsReset = true
                }
                
            case .yearly:
                // Reset if we're in a new year
                let lastResetYear = calendar.component(.year, from: rule.lastResetAt)
                let currentYear = calendar.component(.year, from: now)
                if currentYear != lastResetYear {
                    needsReset = true
                }
            }
            
            if needsReset {
                // If rule wasn't completed, break streak
                if rule.currentCount < rule.targetCount {
                    rule.streakCount = 0
                }
                rule.currentCount = 0
                rule.lastResetAt = now
                rules[index] = rule
            }
        }
        
        saveToLocalStorage()
        
        // Update day streak
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
    
    // MARK: - Badges
    
    private func checkForBadges() {
        // Check point badges
        if userStats.totalPoints >= 100 && !userStats.badges.contains("century") {
            awardBadge("century")
        }
        if userStats.totalPoints >= 1000 && !userStats.badges.contains("thousand") {
            awardBadge("thousand")
        }
        
        // Check streak badges
        if userStats.currentDayStreak >= 7 && !userStats.badges.contains("week_warrior") {
            awardBadge("week_warrior")
        }
        if userStats.currentDayStreak >= 14 && !userStats.badges.contains("consistent") {
            awardBadge("consistent")
        }
        if userStats.currentDayStreak >= 30 && !userStats.badges.contains("month_master") {
            awardBadge("month_master")
        }
    }
    
    private func awardBadge(_ badgeId: String) {
        if !userStats.badges.contains(badgeId) {
            userStats.badges.append(badgeId)
            if let badge = Badge.allBadges.first(where: { $0.id == badgeId }) {
                newBadge = badge
            }
            saveToLocalStorage()
        }
    }
    
    // MARK: - Statistics
    
    func getStatistics() -> (daily: Int, weekly: Int, monthly: Int, yearly: Int, totalPoints: Int) {
        let dailyCompleted = dailyRules.filter { $0.isCompletedForPeriod }.count
        let weeklyCompleted = weeklyRules.filter { $0.isCompletedForPeriod }.count
        let monthlyCompleted = monthlyRules.filter { $0.isCompletedForPeriod }.count
        let yearlyCompleted = yearlyRules.filter { $0.isCompletedForPeriod }.count
        
        return (dailyCompleted, weeklyCompleted, monthlyCompleted, yearlyCompleted, userStats.totalPoints)
    }
    
    func getRuleHistory(_ rule: Rule) -> [Date] {
        // Return mock history for now - would be fetched from server
        return []
    }
    
    // MARK: - Server Sync
    
    private func syncRuleToServer(_ rule: Rule) async {
        // Implementation for Supabase sync
        // For now, we're using local storage
    }
    
    private func deleteRuleFromServer(_ ruleId: String) async {
        // Implementation for Supabase delete
    }
    
    func fetchRules(for userId: Int) async {
        isLoading = true
        defer { isLoading = false }
        
        // Check and reset periods on fetch
        checkAndResetPeriods()
        
        // For now, rules are stored locally
        // Server sync would go here
    }
}
