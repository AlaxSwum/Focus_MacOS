# Focus macOS App - Documentation

## Overview

Focus is a native macOS task management and productivity application built with SwiftUI. It provides a menu bar interface for quick access and a full-screen app for comprehensive task management.

**Version:** 1.3.4  
**Platform:** macOS 13.0+  
**Framework:** SwiftUI + AppKit  
**Backend:** Supabase

---

## Features

### 1. Menu Bar Interface
- **Quick Access:** Click the menu bar icon to see today's tasks
- **Tab Navigation:** Personal, Meetings, Schedule, Skipped
- **Quick Actions:** Mark tasks complete, snooze reminders, skip tasks
- **Add Todo:** Quick add tasks without opening full app
- **Swipe to Delete:** Swipe left on tasks to delete

### 2. Full Application Window
- **Personal Calendar:** Day/Week/Month view with drag-to-create tasks
- **Meeting Schedule:** Calendar view of all meetings with stats
- **Timeline:** 15/30 minute intervals for precise scheduling
- **Task Blocks:** Resizable, draggable time blocks

### 3. Notifications
- **Task Reminders:** Customizable reminder notifications
- **Floating Notifications:** Beautiful in-app notification popups
- **Actions:** Done, Snooze (5 min), Skip directly from notification

### 4. Task Types
- **Time Blocks:** Focus, Meeting, Personal, Goal, Project, Routine, Work, Social, Todo
- **Meetings:** Team meetings synced from projects
- **Todos:** Personal checklist items

---

## Installation

### Method 1: DMG Installation
1. Download `Focus-macOS-v1.3.4.dmg`
2. Double-click to mount the DMG
3. Drag `Focus-macOS.app` to **Applications** folder
4. Open Terminal and run:
   ```bash
   sudo xattr -cr /Applications/Focus-macOS.app
   ```
5. Double-click the app to launch

### Method 2: ZIP Installation
1. Download `Focus-macOS-v1.3.4.zip`
2. Extract the ZIP file
3. Move `Focus-macOS.app` to **Applications** or **Desktop**
4. Run the xattr command (see above)
5. Launch the app

### Gatekeeper Bypass Commands

**If app is in Applications:**
```bash
sudo xattr -cr /Applications/Focus-macOS.app
```

**If app is on Desktop:**
```bash
sudo xattr -cr ~/Desktop/Focus-macOS.app
```

**If opened Terminal from inside app (right-click):**
```bash
cd .. && sudo xattr -cr Focus-macOS.app && open Focus-macOS.app
```

---

## Enabling Notifications

Open System Settings for notifications:
```bash
open "x-apple.systempreferences:com.apple.Notifications-Settings"
```

Find **Focus-macOS** in the list and enable:
- Allow Notifications
- Banners or Alerts
- Sound

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + Q` | Hide windows (keeps menu bar icon) |
| `Cmd + W` | Close current window |
| `Cmd + ,` | Open settings |
| `Cmd + N` | Add new task |

---

## Architecture

### File Structure
```
FocusApp-Swift/
├── Focus/
│   ├── Sources/
│   │   ├── App/
│   │   │   ├── FocusApp.swift      # Main app entry, menu bar
│   │   │   └── ContentView.swift   # Full app views
│   │   ├── Models/
│   │   │   └── Models.swift        # Data models
│   │   ├── Services/
│   │   │   ├── AuthManager.swift   # Authentication
│   │   │   ├── TaskManager.swift   # Task CRUD operations
│   │   │   ├── NotificationManager.swift
│   │   │   └── ThemeManager.swift
│   │   └── Views/
│   │       ├── Calendar/           # Calendar views
│   │       ├── Components/         # Reusable components
│   │       ├── Home/               # Home views
│   │       ├── Settings/           # Settings view
│   │       └── Tasks/              # Task-related views
│   └── Resources/
│       ├── AppIcon.icns
│       └── Assets.xcassets/
├── Focus.xcodeproj/
└── Release/
    └── Focus-macOS.app
```

### Key Components

**FocusApp.swift**
- `@main` app entry point
- `MenuBarExtra` for menu bar interface
- `MenuBarDropdownView` for dropdown content
- `FloatingNotificationView` for custom notifications
- `NotificationManager` singleton

**ContentView.swift**
- `FullAppWindowView` - Main full app container
- `FullCalendarView` - Personal calendar with timeline
- `FullMeetingsView` - Meeting schedule view
- `ResizableTaskBlock` - Draggable/resizable task blocks

**TaskManager.swift**
- Singleton for task state management
- Supabase API integration
- CRUD operations for tasks, meetings, todos

---

## Database (Supabase)

### Tables Used
- `time_blocks` - Task/time block data
- `personal_todos` - Todo list items
- `projects_meeting` - Meeting data
- `focus_skipped_tasks` - Skipped task records

### Required Columns
```sql
-- For projects_meeting
ALTER TABLE projects_meeting 
ADD COLUMN IF NOT EXISTS completed BOOLEAN DEFAULT false;
```

---

## Customization

### Notification Timing
Edit `NotificationManager` in FocusApp.swift:
```swift
private let reminderMinutes = [10, 5, 0] // Minutes before task
```

### Theme Colors
Task type colors are defined in `Models.swift`:
```swift
enum BlockType {
    var color: Color {
        switch self {
        case .focus: return .blue
        case .meeting: return .purple
        // ...
        }
    }
}
```

---

## Troubleshooting

### App won't open / "damaged" error
Run the xattr command (see Installation section)

### Notifications not appearing
1. Open System Settings → Notifications
2. Find Focus-macOS
3. Enable notifications and set to Banners/Alerts

### Tasks not syncing
1. Check internet connection
2. Verify Supabase credentials in code
3. Check if logged in (authentication required)

### Menu bar icon not showing
1. Check if app is running (Activity Monitor)
2. Try restarting the app
3. Check System Settings → Control Center → Menu Bar Only

---

## Version History

### v1.3.4
- Fixed tab visibility in full app window
- Enhanced header bar styling with shadow
- Tab selector now has visible border and background

### v1.3.3
- Redesigned notification UI
- Modern card layout with accent colors
- Full-width action buttons

### v1.3.2
- Fixed edit task time initialization
- Times now correctly show task's actual schedule

### v1.3.1
- Removed unnecessary snooze/skip notifications
- Added 15/30 min intervals to week view
- Redesigned time picker in task creation

### v1.3.0
- Advanced animations throughout app
- Task completion slide-left animation
- Tab switching animations
- Hover effects on all buttons

---

## Support

**GitHub Repository:** https://github.com/AlaxSwum/Focus_MacOS

**Distribution Files:**
- `Focus-macOS-v1.3.4.dmg` (6.2 MB)
- `Focus-macOS-v1.3.4.zip` (5.2 MB)

---

## License

Proprietary - All rights reserved
