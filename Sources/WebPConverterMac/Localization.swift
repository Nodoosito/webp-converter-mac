import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case fr
    case en

    public static let storageKey = "selectedLanguage"
    public static let fallback: AppLanguage = .fr

    public var id: String { rawValue }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public static var current: AppLanguage {
        let storedValue = UserDefaults.standard.string(forKey: storageKey) ?? fallback.rawValue
        return AppLanguage(rawValue: storedValue) ?? fallback
    }
}

enum L10n {
    static func text(_ key: String, language: AppLanguage = .current) -> String {
        NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: localizedBundle(for: language),
            value: key,
            comment: ""
        )
    }

    static func format(_ key: String, language: AppLanguage = .current, _ arguments: CVarArg...) -> String {
        let format = text(key, language: language)
        return String(format: format, locale: language.locale, arguments: arguments)
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle {
        guard
            let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .module
        }

        return bundle
    }
}
