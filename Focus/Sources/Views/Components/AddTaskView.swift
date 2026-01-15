//
//  AddTaskView.swift
//  Focus
//
//  Add new task sheet
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: BlockType = .personal
    @State private var selectedDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var enableNotification = true
    @State private var notificationMinutes = 5
    
    var body: some View {
        NavigationStack {
            Form {
                // Title
                Section {
                    TextField("Task title", text: $title)
                        .font(.headline)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Type
                Section("Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(BlockType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Date & Time
                Section("Date & Time") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Toggle("All Day", isOn: $isAllDay)
                    
                    if !isAllDay {
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                // Notification
                Section("Notification") {
                    Toggle("Remind Me", isOn: $enableNotification)
                    
                    if enableNotification {
                        Picker("Before", selection: $notificationMinutes) {
                            Text("5 minutes").tag(5)
                            Text("10 minutes").tag(10)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("1 hour").tag(60)
                        }
                    }
                }
            }
            .navigationTitle("New Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(title.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func addTask() {
        guard let userId = authManager.currentUser?.id else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        
        let newBlock = TimeBlock(
            id: UUID().uuidString,
            userId: userId,
            date: dateFormatter.string(from: selectedDate),
            startTime: isAllDay ? "09:00:00" : timeFormatter.string(from: startTime),
            endTime: isAllDay ? "17:00:00" : timeFormatter.string(from: endTime),
            title: title,
            description: description.isEmpty ? nil : description,
            type: selectedType,
            category: nil,
            isCompleted: false,
            isRecurring: false,
            recurringDays: nil,
            checklist: nil,
            meetingLink: nil,
            notificationTime: enableNotification ? notificationMinutes : nil,
            color: nil
        )
        
        // Save to database
        Task {
            await saveTimeBlock(newBlock)
            await taskManager.fetchTasks(for: userId)
        }
        
        dismiss()
    }
    
    private func saveTimeBlock(_ block: TimeBlock) async {
        let supabaseURL = "https://ixefjqquwanxoobkfhtv.supabase.co"
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml4ZWZqcXF1d2FueG9vYmtmaHR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjcwOTY1OTIsImV4cCI6MjA0MjY3MjU5Mn0.hs8OxdihJ_sDZIbY4Z2cMHB3KB0e9LyEPJHV_5NNSAA"
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let blockData: [String: Any] = [
            "id": block.id,
            "user_id": block.userId,
            "date": block.date,
            "start_time": block.startTime,
            "end_time": block.endTime,
            "title": block.title,
            "description": block.description ?? NSNull(),
            "type": block.type.rawValue,
            "completed": false,
            "is_recurring": false,
            "notification_time": block.notificationTime ?? NSNull()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: blockData)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to save task: \(error)")
        }
    }
}

#Preview {
    AddTaskView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
