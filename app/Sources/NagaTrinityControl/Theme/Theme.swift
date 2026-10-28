import AppKit
import SwiftUI

/// Precision design system — restrained dark hardware-utility palette with
/// adaptive light counterparts so AppearancePreference continues to work.
enum Theme {
    // MARK: - Accent & status

    /// Primary accent — used sparingly for active nav, selected values, CTAs.
    static let accent = Color(hex: 0x20D866)
    static let accentSoft = Color(hex: 0x20D866).opacity(0.12)
    static let accentMuted = Color(hex: 0x20D866).opacity(0.22)
    static let accentOnAccent = Color.white

    static let danger = Color(light: 0xD70015, dark: 0xFF453A)
    static let warn = Color(light: 0xC93400, dark: 0xFF9F0A)
    static let info = Color(light: 0x0071A4, dark: 0x64D2FF)

    // MARK: - Text

    static let text0 = Color(light: 0x1C1C1E, dark: 0xF0F0F2)
    static let text1 = Color(light: 0x3A3A3C, dark: 0xD2D3D6)
    static let text2 = Color(light: 0x6C6C70, dark: 0x92949A)
    static let text3 = Color(light: 0x8E8E93, dark: 0x6E7076)

    // MARK: - Surfaces

    /// Main content background `#18191B`.
    static let bg0 = Color(light: 0xF2F2F4, dark: 0x18191B)
    /// Sidebar / quieter chrome `#151618`.
    static let bg1 = Color(light: 0xE8E8EA, dark: 0x151618)
    /// Elevated card surface `#202124`.
    static let surface = Color(light: 0xFFFFFF, dark: 0x202124)
    /// Slightly stronger fill for nested / selected quiescent areas.
    static let surfaceStrong = Color(light: 0xF7F7F8, dark: 0x252629)

    static let fillSubtle = Color(lightHex: 0x000000, lightOpacity: 0.04, darkHex: 0xFFFFFF, darkOpacity: 0.05)
    static let fillQuiet = Color(lightHex: 0x000000, lightOpacity: 0.025, darkHex: 0xFFFFFF, darkOpacity: 0.03)
    static let fillHover = Color(lightHex: 0x000000, lightOpacity: 0.055, darkHex: 0xFFFFFF, darkOpacity: 0.06)

    /// Borders / dividers `#303135`.
    static let border = Color(lightHex: 0x000000, lightOpacity: 0.10, darkHex: 0x303135, darkOpacity: 1)
    static let borderStrong = Color(lightHex: 0x000000, lightOpacity: 0.16, darkHex: 0x3A3B40, darkOpacity: 1)

    // MARK: - Radii

    static let radiusXs: CGFloat = 5
    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 10
    static let radiusLg: CGFloat = 14

    // MARK: - Layout

    static let sidebarWidth: CGFloat = 232
    static let windowDefault = CGSize(width: 1280, height: 860)
    static let windowMin = CGSize(width: 960, height: 640)

    static let pagePadding: CGFloat = 28
    static let stackSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 18
    static let rowSpacing: CGFloat = 10

    /// Shared control metrics — keep primary / secondary / icon heights aligned.
    enum Control {
        static let height: CGFloat = 28
        static let heightCompact: CGFloat = 24
        static let heightIcon: CGFloat = 28
        static let horizontalPadding: CGFloat = 12
        static let horizontalPaddingCompact: CGFloat = 10
    }

    // MARK: - Motion

    static let animFast: Animation = .easeOut(duration: 0.12)
    static let animNormal: Animation = .easeInOut(duration: 0.18)

    // MARK: - Typography

    enum TypeScale {
        /// Page / topbar titles ~26 pt.
        static let pageTitle = Font.system(size: 26, weight: .semibold)
        /// Device hero title ~32 pt.
        static let deviceTitle = Font.system(size: 32, weight: .semibold)
        /// Card section headings ~15–16 pt.
        static let cardHeading = Font.system(size: 15, weight: .semibold)
        static let cardHeadingLarge = Font.system(size: 16, weight: .semibold)
        /// Settings labels / values ~14 pt.
        static let body = Font.system(size: 14, weight: .regular)
        static let bodyMedium = Font.system(size: 14, weight: .medium)
        static let bodySemibold = Font.system(size: 14, weight: .semibold)
        /// Secondary / metadata ~12–13 pt.
        static let meta = Font.system(size: 13, weight: .regular)
        static let metaMedium = Font.system(size: 12, weight: .medium)
        static let caption = Font.system(size: 12, weight: .regular)
        static let micro = Font.system(size: 11, weight: .medium)
        static let eyebrow = Font.system(size: 11, weight: .semibold)
        /// Technical values (DPI, Hz) — pair with `.monospacedDigit()`.
        static let valueLarge = Font.system(size: 22, weight: .semibold)
        static let valueHero = Font.system(size: 36, weight: .semibold)
        static let valueStage = Font.system(size: 16, weight: .semibold)
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` follows the system appearance via `NSApp.appearance`.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppearancePreference: ObservableObject {
    private static let key = "naga.appearance"

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.key)
            applyToApp()
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: raw) ?? .system
        // `didSet` does not run during init.
        applyToApp()
    }

    private func applyToApp() {
        NSApp.appearance = appearance.nsAppearance
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    init?(hexString: String) {
        var raw = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else {
            return nil
        }
        self.init(hex: value)
    }

    /// Adaptive sRGB color that tracks light / dark appearance.
    init(light: UInt32, dark: UInt32, opacity: Double = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            let r = CGFloat((hex >> 16) & 0xff) / 255
            let g = CGFloat((hex >> 8) & 0xff) / 255
            let b = CGFloat(hex & 0xff) / 255
            return NSColor(srgbRed: r, green: g, blue: b, alpha: opacity)
        })
    }

    init(
        lightHex: UInt32,
        lightOpacity: Double,
        darkHex: UInt32,
        darkOpacity: Double
    ) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? darkHex : lightHex
            let opacity = isDark ? darkOpacity : lightOpacity
            let r = CGFloat((hex >> 16) & 0xff) / 255
            let g = CGFloat((hex >> 8) & 0xff) / 255
            let b = CGFloat(hex & 0xff) / 255
            return NSColor(srgbRed: r, green: g, blue: b, alpha: opacity)
        })
    }
}
