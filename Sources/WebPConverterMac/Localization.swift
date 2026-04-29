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

    static var current: AppLanguage {
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
        if let bundle = Bundle.main.path(forResource: language.rawValue, ofType: "lproj") {
            return Bundle(path: bundle) ?? .main
        }
        
        if let resourcesURL = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
           let resourceBundle = Bundle(url: resourcesURL) {
            return resourceBundle
        }
        
        return .main
    }
}
