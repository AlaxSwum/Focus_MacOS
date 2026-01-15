//
//  ThemeManager.swift
//  Focus
//
//  Manages app theme and colors
//

import Foundation
import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var accentColor: Color = .blue
    @Published var colorScheme: ColorScheme? = nil // nil = system
    @Published var useGlassEffect = true
    
    @AppStorage("theme_accent") private var accentColorName: String = "blue"
    @AppStorage("theme_mode") private var themeModeRaw: Int = 0
    
    init() {
        loadSavedTheme()
    }
    
    // MARK: - Theme Colors
    
    static let accentColors: [String: Color] = [
        "blue": .blue,
        "purple": .purple,
        "pink": .pink,
        "red": .red,
        "orange": .orange,
        "yellow": .yellow,
        "green": .green,
        "teal": .teal,
        "indigo": .indigo
    ]
    
    enum ThemeMode: Int, CaseIterable {
        case system = 0
        case light = 1
        case dark = 2
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
        
        var icon: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }
    }
    
    var currentThemeMode: ThemeMode {
        get { ThemeMode(rawValue: themeModeRaw) ?? .system }
        set {
            themeModeRaw = newValue.rawValue
            updateColorScheme()
        }
    }
    
    // MARK: - Methods
    
    func setAccentColor(_ name: String) {
        accentColorName = name
        accentColor = Self.accentColors[name] ?? .blue
    }
    
    private func loadSavedTheme() {
        accentColor = Self.accentColors[accentColorName] ?? .blue
        updateColorScheme()
    }
    
    private func updateColorScheme() {
        switch currentThemeMode {
        case .system:
            colorScheme = nil
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        }
    }
}

// MARK: - Design System
struct DesignSystem {
    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // Corner Radius
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    
    // Shadows
    static let shadowSM = Color.black.opacity(0.05)
    static let shadowMD = Color.black.opacity(0.1)
    static let shadowLG = Color.black.opacity(0.15)
    
    // Glass Effect
    static func glassBackground(scheme: ColorScheme?) -> some ShapeStyle {
        if scheme == .dark {
            return Color.white.opacity(0.1).blendMode(.overlay)
        } else {
            return Color.white.opacity(0.8).blendMode(.overlay)
        }
    }
}

// MARK: - View Modifiers
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = DesignSystem.radiusMD
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: DesignSystem.shadowSM, radius: 10, x: 0, y: 4)
    }
}

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = DesignSystem.radiusMD
    
    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color.systemGray6 : .white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: DesignSystem.shadowSM, radius: 8, x: 0, y: 2)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = DesignSystem.radiusMD) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
    
    func cardStyle(cornerRadius: CGFloat = DesignSystem.radiusMD) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }
}
