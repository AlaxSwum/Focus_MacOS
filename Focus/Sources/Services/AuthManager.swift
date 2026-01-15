//
//  AuthManager.swift
//  Focus
//
//  Handles authentication with Supabase
//

import Foundation
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    private let userDefaults = UserDefaults.standard
    private let tokenKey = "focus_auth_token"
    private let userIdKey = "focus_user_id"
    
    init() {
        // Check for stored credentials
        checkStoredAuth()
    }
    
    // MARK: - Public Methods
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Query auth_user table for login
            let url = URL(string: "\(supabaseURL)/rest/v1/auth_user?email=eq.\(email)&password=eq.\(password)&select=*")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let users = try JSONDecoder().decode([User].self, from: data)
                
                if let user = users.first {
                    // Success
                    self.currentUser = user
                    self.isAuthenticated = true
                    
                    // Store credentials
                    userDefaults.set(user.id, forKey: userIdKey)
                    userDefaults.set(true, forKey: tokenKey)
                    
                    // Fetch tasks
                    await TaskManager.shared.fetchTasks(for: user.id)
                } else {
                    errorMessage = "Invalid email or password"
                }
            } else {
                errorMessage = "Login failed. Please try again."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
        userDefaults.removeObject(forKey: tokenKey)
        userDefaults.removeObject(forKey: userIdKey)
        TaskManager.shared.clearTasks()
    }
    
    // MARK: - Private Methods
    
    private func checkStoredAuth() {
        if userDefaults.bool(forKey: tokenKey),
           let userId = userDefaults.object(forKey: userIdKey) as? Int {
            Task {
                await fetchUser(id: userId)
            }
        }
    }
    
    private func fetchUser(id: Int) async {
        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/auth_user?id=eq.\(id)&select=*")!
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let users = try JSONDecoder().decode([User].self, from: data)
                if let user = users.first {
                    self.currentUser = user
                    self.isAuthenticated = true
                    await TaskManager.shared.fetchTasks(for: user.id)
                }
            }
        } catch {
            print("Failed to fetch user: \(error)")
            logout()
        }
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidResponse
    case invalidCredentials
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .invalidCredentials: return "Invalid email or password"
        case .networkError: return "Network error. Please check your connection."
        }
    }
}
