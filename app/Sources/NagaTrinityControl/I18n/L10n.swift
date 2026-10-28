import Foundation
import os

@MainActor
final class L10n: ObservableObject {
    static let shared = L10n()

    @Published private(set) var language: String = "en"

    private var tables: [String: [String: String]] = [:]
    private let logger = Logger(subsystem: "local.naga-trinity-control", category: "L10n")

    private init() {
        loadTables()
        language = Self.detectSystemLanguage()
    }

    func resolveLanguage(from settingsLanguage: String?) {
        if let settingsLanguage, Constants.supportedLanguages.contains(settingsLanguage) {
            language = settingsLanguage
            return
        }
        language = Self.detectSystemLanguage()
    }

    func setLanguage(_ code: String) {
        guard Constants.supportedLanguages.contains(code) else { return }
        language = code
    }

    func t(_ key: String, params: [String: String] = [:]) -> String {
        let raw = lookup(key) ?? key
        return interpolate(raw, params: params)
    }

    func exists(_ key: String) -> Bool {
        lookup(key) != nil
    }

    private func lookup(_ key: String) -> String? {
        if let value = tables[language]?[key] {
            return value
        }
        if language != "en", let value = tables["en"]?[key] {
            return value
        }
        return nil
    }

    private func interpolate(_ template: String, params: [String: String]) -> String {
        var result = template
        for (name, value) in params {
            result = result.replacingOccurrences(of: "{{\(name)}}", with: value)
        }
        return result
    }

    private func loadTables() {
        for code in Constants.supportedLanguages {
            guard let url = Bundle.module.url(forResource: code, withExtension: "json", subdirectory: "i18n")
                ?? Bundle.module.url(forResource: code, withExtension: "json")
            else {
                logger.error("Missing i18n file for \(code, privacy: .public)")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data)
                tables[code] = Self.flatten(json)
            } catch {
                logger.error("Failed to load i18n \(code, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func flatten(_ json: Any, prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]
        guard let object = json as? [String: Any] else { return result }
        for (key, value) in object {
            let path = prefix.isEmpty ? key : "\(prefix).\(key)"
            if let nested = value as? [String: Any] {
                result.merge(flatten(nested, prefix: path)) { _, new in new }
            } else if let string = value as? String {
                result[path] = string
            } else if let number = value as? NSNumber {
                result[path] = number.stringValue
            }
        }
        return result
    }

    private static func detectSystemLanguage() -> String {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("de") ? "de" : "en"
    }
}
