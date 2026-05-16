import Foundation
import SwiftUI

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case japanese = "ja"
    case portugueseBrazil = "pt-BR"
    case russian = "ru"
    case ukrainian = "uk"

    public var id: String { rawValue }

    public var displayNameKey: String {
        switch self {
        case .system:
            return "Automatic (OS)"
        case .english:
            return "English"
        case .german:
            return "German"
        case .spanish:
            return "Spanish"
        case .french:
            return "French"
        case .japanese:
            return "Japanese"
        case .portugueseBrazil:
            return "Portuguese (Brazil)"
        case .russian:
            return "Russian"
        case .ukrainian:
            return "Ukrainian"
        }
    }

    public var nativeDisplayName: String {
        switch self {
        case .system:
            return displayNameKey
        case .english:
            return "English"
        case .german:
            return "Deutsch"
        case .spanish:
            return "Español"
        case .french:
            return "Français"
        case .japanese:
            return "日本語"
        case .portugueseBrazil:
            return "Português (Brasil)"
        case .russian:
            return "Русский"
        case .ukrainian:
            return "Українська"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .system:
            return resolved.localeIdentifier
        case .english:
            return "en"
        case .german:
            return "de"
        case .spanish:
            return "es"
        case .french:
            return "fr"
        case .japanese:
            return "ja"
        case .portugueseBrazil:
            return "pt-BR"
        case .russian:
            return "ru"
        case .ukrainian:
            return "uk"
        }
    }

    public var resolved: AppLanguage {
        guard self == .system else {
            return self
        }

        for identifier in Locale.preferredLanguages {
            let languageCode = Locale(identifier: identifier).language.languageCode?.identifier
            switch languageCode {
            case "de":
                return .german
            case "es":
                return .spanish
            case "fr":
                return .french
            case "ja":
                return .japanese
            case "pt":
                return .portugueseBrazil
            case "ru":
                return .russian
            case "uk":
                return .ukrainian
            case "en":
                return .english
            default:
                continue
            }
        }

        return .english
    }

    var resourceCode: String {
        resolved.rawValue.lowercased()
    }
}

public struct AppLocalization: Equatable, Sendable {
    public let selection: AppLanguage

    public init(selection: AppLanguage = .system) {
        self.selection = selection
    }

    public var language: AppLanguage {
        selection.resolved
    }

    public var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    public func string(_ key: String) -> String {
        Self.bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    public func format(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments: arguments)
    }

    public func format(_ key: String, arguments: [CVarArg]) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    public func callAsFunction(_ key: String) -> String {
        string(key)
    }

    public func callAsFunction(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard
            let url = Bundle.module.url(
                forResource: language.resourceCode,
                withExtension: "lproj"
            ),
            let bundle = Bundle(url: url)
        else {
            return Bundle.module
        }
        return bundle
    }
}

private struct AppLocalizationKey: EnvironmentKey {
    static let defaultValue = AppLocalization()
}

public extension EnvironmentValues {
    var appLocalization: AppLocalization {
        get { self[AppLocalizationKey.self] }
        set { self[AppLocalizationKey.self] = newValue }
    }
}
