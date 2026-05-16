import Foundation
import SwiftUI

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case french = "fr"
    case russian = "ru"
    case ukrainian = "uk"

    public var id: String { rawValue }

    public var displayNameKey: String {
        switch self {
        case .system:
            return "Automatic (OS)"
        case .english:
            return "English"
        case .french:
            return "French"
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
        case .french:
            return "Français"
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
        case .french:
            return "fr"
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
            case "fr":
                return .french
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
        resolved.rawValue
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
