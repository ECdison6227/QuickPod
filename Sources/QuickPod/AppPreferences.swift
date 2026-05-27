import AppKit
import Foundation

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var appearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system
    case zhHans
    case en
}

enum AppPreferences {
    static let themeKey = "QuickPod.appTheme"
    static let languageKey = "QuickPod.appLanguage"
}

enum QuickPodText {
    static func text(zh: String, en: String) -> String {
        switch currentLanguage {
        case .zhHans:
            return zh
        case .en:
            return en
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("zh") ? zh : en
        }
    }

    static var currentLanguage: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.languageKey) ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    static var currentTheme: AppTheme {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.themeKey) ?? AppTheme.system.rawValue
        return AppTheme(rawValue: rawValue) ?? .system
    }
}
