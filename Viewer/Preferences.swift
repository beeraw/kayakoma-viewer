import AppKit
import SwiftUI

/// Keys and default values of the app's settings, stored in `UserDefaults`.
enum Preferences {
    static let themeID = "themeID"
    static let fontSize = "fontSize"
    static let maxLineCharacters = "maxLineCharacters"
    static let appearance = "appearance"
    /// New windows open filling the visible frame of their screen.
    static let opensWindowsLarge = "opensWindowsLarge"
    static let showsOutlineAutomatically = "showsOutlineAutomatically"
    static let reloadsOnChange = "reloadsOnChange"

    static let defaultFontSize: Double = 15
    static let fontSizeRange: ClosedRange<Double> = 10...28
    static let defaultMaxLineCharacters: Double = 90
    static let maxLineCharactersRange: ClosedRange<Double> = 50...140
    /// A document opens with its outline shown when it has at least this many headings.
    static let outlineHeadingThreshold = 4
}

/// The app's appearance, independent of the system's when forced.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto, light, dark

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .auto: "Auto"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .auto: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// Applies the mode stored in the user defaults to the whole app.
    @MainActor
    static func applyStored() {
        let mode = UserDefaults.standard.string(forKey: Preferences.appearance).flatMap(AppearanceMode.init) ?? .auto
        if NSApp.appearance != mode.nsAppearance {
            NSApp.appearance = mode.nsAppearance
        }
    }
}
