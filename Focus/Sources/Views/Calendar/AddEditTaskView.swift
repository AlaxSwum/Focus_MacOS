//
//  AddEditTaskView.swift
//  Focus
//
//  Add or Edit task view - Website-style clean design
//

import SwiftUI
import UserNotifications

// Categories
struct TaskCategory: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    var isCustom: Bool = false
}

let defaultCategories: [TaskCategory] = [
    TaskCategory(id: "work", name: "Work", color: .blue),
    TaskCategory(id: "study", name: "Study", color: .purple),
    TaskCategory(id: "workout", name: "Workout", color: .red),
    TaskCategory(id: "health", name: "Health", color: .green),
    TaskCategory(id: "creative", name: "Creative", color: .orange),
    TaskCategory(id: "social", name: "Social", color: .pink),
    TaskCategory(id: "errands", name: "Errands", color: .indigo),
    TaskCategory(id: "rest", name: "Rest", color: .gray),
]

struct AddEditTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var authManager: AuthManager
    
    let date: Date
    let task: TaskItem?
    
    // Form state
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedType: BlockType = .focus
    @State private var selectedCategories: [TaskCategory] = []
    @State private var selectedDate: Date = Date()
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(1800)
    @State private var meetingLink: String = ""
    @State private var notificationMinutes: Int = 10
    @State private var isRecurring: Bool = false
    @State private var recurringDays: Set<Int> = []
    @State private var checklist: [ChecklistItem] = []
    @State private var newChecklistItem: String = ""
    @State private var showAddCategory: Bool = false
    @State private var newCategoryName: String = ""
    @State private var customCategories: [TaskCategory] = []
    
    @State private var isSaving: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    private var isEditing: Bool { task != nil }
    
    private let supabaseURL = "https://bayyefskgflbyyuwrlgm.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJheXllZnNrZ2ZsYnl5dXdybGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAyNTg0MzAsImV4cCI6MjA2NTgzNDQzMH0.eTr2bOWOO7N7hzRR45qapeQ6V-u2bgV5BbQygZZgGGM"
    
    private var allCategories: [TaskCategory] {
        defaultCategories + customCategories
    }
    
    init(date: Date, task: TaskItem?) {
        self.date = date
        self.task = task
        
        if let task = task {
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.description ?? "")
            _selectedDate = State(initialValue: task.date)
            _startTime = State(initialValue: task.startTime ?? date)
            _endTime = State(initialValue: task.endTime ?? date.addingTimeInterval(1800))
            _meetingLink = State(initialValue: task.meetingLink ?? "")
            if case .timeBlock(let blockType) = task.type {
                _selectedType = State(initialValue: blockType)
            }
        } else {
            _selectedDate = State(initialValue: date)
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            let minute = calendar.component(.minute, from: Date())
            let roundedMinute = (minute / 15) * 15
            if let start = calendar.date(bySettingHour: hour, minute: roundedMinute, second: 0, of: date) {
                _startTime = State(initialValue: start)
                _endTime = State(initialValue: start.addingTimeInterval(1800))
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Time Block" : "New Time Block")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: NSColor.controlBackgroundColor))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Title")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("What are you working on?", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2)))
                    }
                    
                    // Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Row 1
                        HStack(spacing: 8) {
                            typeButton(.focus)
                            typeButton(.meeting)
                            typeButton(.personal)
                        }
                        // Row 2
                        HStack(spacing: 8) {
                            typeButton(.goal)
                            typeButton(.project)
                        }
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category (optional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Selected categories + all categories
                        let columns = [GridItem(.adaptive(minimum: 80), spacing: 8)]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(allCategories) { cat in
                                categoryChip(cat)
                            }
                            
                            // Add button
                            Button { showAddCategory = true } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("Add")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(nsColor: NSColor.controlBackgroundColor))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4])))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Time Selection - Better Layout
                    VStack(alignment: .leading, spacing: 12) {
                        // Label row
                        HStack {
                            Text("Time")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Duration badge
                            let duration = Int(endTime.timeIntervalSince(startTime) / 60)
                            if duration > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.system(size: 10))
                                    Text("\(duration) min")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        
                        // Time pickers in a card
                        HStack(spacing: 16) {
                            // Start Time
                            VStack(alignment: .leading, spacing: 6) {
                                Text("START")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.field)
                                    .frame(minWidth: 100)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.2)))
                            
                            // Arrow
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                            
                            // End Time
                            VStack(alignment: .leading, spacing: 6) {
                                Text("END")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.field)
                                    .frame(minWidth: 100)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.2)))
                        }
                        
                        // Quick duration buttons
                        HStack(spacing: 8) {
                            Text("Quick:")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            ForEach([15, 30, 45, 60, 90], id: \.self) { mins in
                                Button {
                                    endTime = startTime.addingTimeInterval(Double(mins * 60))
                                } label: {
                                    Text("\(mins)m")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Int(endTime.timeIntervalSince(startTime) / 60) == mins ? .white : .secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Int(endTime.timeIntervalSince(startTime) / 60) == mins ? Color.blue : Color(nsColor: NSColor.controlBackgroundColor))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (optional)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextEditor(text: $description)
                            .font(.system(size: 14))
                            .frame(height: 70)
                            .padding(8)
                            .background(Color(nsColor: NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2)))
                    }
                    
                    // Reminder
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reminder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $notificationMinutes) {
                            Text("No reminder").tag(0)
                            Text("5 minutes before").tag(5)
                            Text("10 minutes before").tag(10)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Recurring
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $isRecurring) {
                            HStack(spacing: 8) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 14))
                                Text("Repeat on specific days")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if isRecurring {
                            HStack(spacing: 6) {
                                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { index, day in
                                    Button {
                                        if recurringDays.contains(index) {
                                            recurringDays.remove(index)
                                        } else {
                                            recurringDays.insert(index)
                                        }
                                    } label: {
                                        Text(day)
                                            .font(.system(size: 11, weight: .semibold))
                                            .frame(width: 32, height: 32)
                                            .background(recurringDays.contains(index) ? Color.blue : Color(nsColor: NSColor.controlBackgroundColor))
                                            .foregroundColor(recurringDays.contains(index) ? .white : .primary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Checklist
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Checklist / Mini-tasks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Add a task or goal...", text: $newChecklistItem)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color(nsColor: NSColor.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.2)))
                                .onSubmit { addChecklistItem() }
                            
                            Button { addChecklistItem() } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .disabled(newChecklistItem.isEmpty)
                        }
                        
                        ForEach(checklist) { item in
                            HStack(spacing: 10) {
                                Button { toggleChecklistItem(item) } label: {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(item.isCompleted ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                
                                Text(item.text)
                                    .font(.system(size: 14))
                                    .strikethrough(item.isCompleted)
                                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                                
                                Spacer()
                                
                                Button { removeChecklistItem(item) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                
                Button {
                    saveTask()
                } label: {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text(isEditing ? "Save Changes" : "Create Block")
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(title.isEmpty || isSaving)
            }
            .padding(16)
        }
        .frame(width: 420, height: 680)
        .background(Color(nsColor: NSColor.windowBackgroundColor))
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showAddCategory) {
            addCategorySheet
        }
    }
    
    // MARK: - Type Button
    private func typeButton(_ type: BlockType) -> some View {
        Button {
            selectedType = type
        } label: {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 18))
                Text(type.displayName)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selectedType == type ? type.color.opacity(0.1) : Color(nsColor: NSColor.controlBackgroundColor))
            .foregroundColor(selectedType == type ? type.color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selectedType == type ? type.color : Color.gray.opacity(0.2), lineWidth: selectedType == type ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Category Chip
    private func categoryChip(_ cat: TaskCategory) -> some View {
        let isSelected = selectedCategories.contains(where: { $0.id == cat.id })
        
        return Button {
            if isSelected {
                selectedCategories.removeAll { $0.id == cat.id }
            } else {
                selectedCategories.append(cat)
            }
        } label: {
            HStack(spacing: 4) {
                Circle().fill(cat.color).frame(width: 8, height: 8)
                Text(cat.name)
                    .font(.system(size: 12))
                if isSelected && cat.isCustom {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? cat.color.opacity(0.15) : Color(nsColor: NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? cat.color : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Add Category Sheet
    private var addCategorySheet: some View {
        VStack(spacing: 16) {
            Text("Add Category")
                .font(.headline)
            
            TextField("Category name", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") { showAddCategory = false }
                    .buttonStyle(.bordered)
                
                Button("Add") {
                    if !newCategoryName.isEmpty {
                        let newCat = TaskCategory(id: UUID().uuidString, name: newCategoryName, color: .blue, isCustom: true)
                        customCategories.append(newCat)
                        selectedCategories.append(newCat)
                        newCategoryName = ""
                        showAddCategory = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newCategoryName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
    
    // MARK: - Checklist Functions
    private func addChecklistItem() {
        guard !newChecklistItem.isEmpty else { return }
        checklist.append(ChecklistItem(id: UUID().uuidString, text: newChecklistItem, isCompleted: false))
        newChecklistItem = ""
    }
    
    private func toggleChecklistItem(_ item: ChecklistItem) {
        if let index = checklist.firstIndex(where: { $0.id == item.id }) {
            checklist[index].isCompleted.toggle()
        }
    }
    
    private func removeChecklistItem(_ item: ChecklistItem) {
        checklist.removeAll { $0.id == item.id }
    }
    
    // MARK: - Save
    private func saveTask() {
        guard let userId = authManager.currentUser?.id else {
            errorMessage = "Please log in"
            showError = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                if isEditing, let existingTask = task {
                    try await updateTask(existingTask, userId: userId)
                } else {
                    try await createTask(userId: userId)
                }
                await taskManager.fetchTasks(for: userId)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func createTask(userId: Int) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        var blockData: [String: Any] = [
            "id": UUID().uuidString,
            "user_id": userId,
            "date": dateFormatter.string(from: selectedDate),
            "start_time": String(format: "%02d:%02d:00", startHour, startMinute),
            "end_time": String(format: "%02d:%02d:00", endHour, endMinute),
            "title": title,
            "type": selectedType.rawValue,
            "completed": false
        ]
        
        if !description.isEmpty { blockData["description"] = description }
        if !meetingLink.isEmpty { blockData["meeting_link"] = meetingLink }
        if !selectedCategories.isEmpty { blockData["category"] = selectedCategories.first?.id }
        if notificationMinutes > 0 { blockData["notification_time"] = notificationMinutes }
        if isRecurring {
            blockData["is_recurring"] = true
            blockData["recurring_days"] = Array(recurringDays)
        }
        if !checklist.isEmpty {
            let checklistData = try? JSONEncoder().encode(checklist)
            if let data = checklistData, let json = try? JSONSerialization.jsonObject(with: data) {
                blockData["checklist"] = json
            }
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks") else { 
            print("DEBUG: Invalid URL for time_blocks")
            return 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: blockData)
        
        print("DEBUG: Creating task with data: \(blockData)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("DEBUG: Create task response status: \(httpResponse.statusCode)")
            if let responseStr = String(data: data, encoding: .utf8) {
                print("DEBUG: Response: \(responseStr.prefix(500))")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create task: HTTP \(httpResponse.statusCode)"])
            }
        }
    }
    
    private func updateTask(_ task: TaskItem, userId: Int) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)
        
        var blockData: [String: Any] = [
            "date": dateFormatter.string(from: selectedDate),
            "start_time": String(format: "%02d:%02d:00", startHour, startMinute),
            "end_time": String(format: "%02d:%02d:00", endHour, endMinute),
            "title": title,
            "type": selectedType.rawValue
        ]
        
        blockData["description"] = description.isEmpty ? NSNull() : description
        blockData["category"] = selectedCategories.isEmpty ? NSNull() : selectedCategories.first?.id
        blockData["notification_time"] = notificationMinutes > 0 ? notificationMinutes : NSNull()
        blockData["is_recurring"] = isRecurring
        blockData["recurring_days"] = isRecurring ? Array(recurringDays) : NSNull()
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/time_blocks?id=eq.\(task.originalId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: blockData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to update task"])
        }
    }
}

#Preview {
    AddEditTaskView(date: Date(), task: nil)
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
