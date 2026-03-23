import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case fr
    case en

    static let storageKey = "selectedLanguage"
    static let fallback: AppLanguage = .fr

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .fr:
            return "Français"
        case .en:
            return "English"
        }
    }

    static var current: AppLanguage {
        let storedValue = UserDefaults.standard.string(forKey: storageKey) ?? fallback.rawValue
        return AppLanguage(rawValue: storedValue) ?? fallback
    }
}

enum L10n {
    static func text(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            table: "Localizable",
            bundle: .module,
            locale: AppLanguage.current.locale
        )
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: AppLanguage.current.locale, arguments: arguments)
    }
}
