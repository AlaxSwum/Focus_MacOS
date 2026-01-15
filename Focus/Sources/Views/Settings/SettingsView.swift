//
//  SettingsView.swift
//  Focus
//
//  App settings with Apple design
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    @State private var showingLogoutAlert = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let user = authManager.currentUser {
                    profileCard(for: user)
                }
                
                sectionCard(title: "Appearance") {
                    Picker("Theme", selection: $themeManager.currentThemeMode) {
                        ForEach(ThemeManager.ThemeMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    NavigationLink {
                        AccentColorPicker()
                    } label: {
                        HStack {
                            Text("Accent Color")
                            Spacer()
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 22, height: 22)
                        }
                    }
                }
                
                sectionCard(title: "Notifications") {
                    Toggle("Enable Notifications", isOn: .constant(notificationManager.isAuthorized))
                        .disabled(true)
                    
                    if !notificationManager.isAuthorized {
                        Button("Enable in Settings") {
                            #if os(iOS)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            #endif
                        }
                    }
                    
                    Picker("Remind before", selection: $notificationManager.reminderMinutes) {
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .pickerStyle(.menu)
                    
                    Toggle("Notification Sound", isOn: $notificationManager.soundEnabled)
                }
                
                sectionCard(title: "Sync") {
                    HStack {
                        Text("Last Synced")
                        Spacer()
                        if let lastRefresh = taskManager.lastRefresh {
                            Text(lastRefresh, style: .relative)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("Sync Now") {
                        if let userId = authManager.currentUser?.id {
                            Task {
                                await taskManager.fetchTasks(for: userId)
                            }
                        }
                    }
                }
                
                sectionCard(title: "About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://focus-project.co.uk")!) {
                        HStack {
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://focus-project.co.uk/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Button(role: .destructive) {
                    showingLogoutAlert = true
                } label: {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(16)
        }
        .navigationTitle("Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.logout()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    @EnvironmentObject var taskManager: TaskManager
    
    private func initials(from string: String) -> String {
        let components = string.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(string.prefix(2)).uppercased()
    }

    private func profileCard(for user: User) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Text(initials(from: user.fullName ?? user.email))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName ?? "User")
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                content()
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var cardBackground: some View {
        Color.secondary.opacity(0.08)
    }
}

// MARK: - Accent Color Picker
struct AccentColorPicker: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    private let columns = [GridItem(.adaptive(minimum: 60))]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Array(ThemeManager.accentColors.keys.sorted()), id: \.self) { colorName in
                    let color = ThemeManager.accentColors[colorName]!
                    
                    Button(action: {
                        themeManager.setAccentColor(colorName)
                        dismiss()
                    }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 50, height: 50)
                                
                                if themeManager.accentColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Text(colorName.capitalized)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Accent Color")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AuthManager.shared)
            .environmentObject(ThemeManager.shared)
            .environmentObject(NotificationManager.shared)
            .environmentObject(TaskManager.shared)
    }
}
