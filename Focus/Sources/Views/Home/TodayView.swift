//
//  TodayView.swift
//  Focus
//
//  Redirects to TodayScheduleView for macOS
//

import SwiftUI

struct TodayView: View {
    var body: some View {
        #if os(macOS)
        TodayScheduleView()
        #else
        Text("Today View")
        #endif
    }
}

#Preview {
    TodayView()
        .environmentObject(TaskManager.shared)
        .environmentObject(AuthManager.shared)
}
