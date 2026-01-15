# Focus - Native Swift App

A beautiful native iOS and macOS productivity app with Apple + Rize inspired design. Syncs with Focus web app via Supabase.

## Features

- 📱 **Native iOS App** - Beautiful SwiftUI interface
- 💻 **Native macOS App** - Menu bar integration
- 🔔 **Notifications** - Task reminders before start time
- ⏭️ **Skip Tasks** - Skip with reasons
- 📅 **Schedule View** - Day, Week, Month views
- 🔄 **Real-time Sync** - Syncs with Focus web app
- 🎨 **Customizable** - Themes and accent colors
- 🌙 **Dark Mode** - Full dark mode support

## Requirements

- Xcode 15.0+
- iOS 17.0+
- macOS 14.0+
- Swift 5.9+

## Setup Instructions

### 1. Open in Xcode

```bash
cd FocusApp-Swift
open Focus.xcodeproj
```

Or create a new Xcode project:

1. Open Xcode
2. File → New → Project
3. Select "App" (Multiplatform)
4. Product Name: "Focus"
5. Organization Identifier: "com.focusproject"
6. Interface: SwiftUI
7. Language: Swift

### 2. Add Source Files

Drag and drop the `Focus/Sources` folder into your Xcode project.

### 3. Configure Targets

**iOS Target:**
- Deployment Target: iOS 17.0
- Bundle Identifier: com.focusproject.focus

**macOS Target:**
- Deployment Target: macOS 14.0
- Bundle Identifier: com.focusproject.focus
- Capabilities: App Sandbox, Network (Outgoing connections)

### 4. Configure Capabilities

Enable in Signing & Capabilities:
- Push Notifications (for notifications)
- App Sandbox (macOS)
- Network: Outgoing Connections

### 5. Build & Run

1. Select your target device (iPhone/Mac)
2. Press Cmd+R to build and run

## Project Structure

```
Focus/
├── Sources/
│   ├── App/
│   │   ├── FocusApp.swift        # App entry point
│   │   └── ContentView.swift     # Main content view
│   ├── Models/
│   │   └── Models.swift          # Data models
│   ├── Services/
│   │   ├── AuthManager.swift     # Authentication
│   │   ├── TaskManager.swift     # Task management
│   │   ├── NotificationManager.swift
│   │   └── ThemeManager.swift
│   └── Views/
│       ├── Home/
│       │   ├── TodayView.swift
│       │   └── LoginView.swift
│       ├── Schedule/
│       │   └── ScheduleView.swift
│       ├── Tasks/
│       │   └── TasksView.swift
│       ├── Settings/
│       │   └── SettingsView.swift
│       └── Components/
│           ├── AddTaskView.swift
│           ├── TaskDetailView.swift
│           ├── SkipTaskSheet.swift
│           └── MenuBarView.swift
```

## Database

The app connects to the same Supabase database as the Focus web app:
- Time blocks
- Meetings
- Personal todos
- Skipped tasks

## Building for Release

### iOS
1. Select "Any iOS Device" as target
2. Product → Archive
3. Distribute App → App Store Connect

### macOS
1. Select "My Mac" as target
2. Product → Archive
3. Distribute App → Direct Distribution / App Store

## License

MIT License - Focus Project
