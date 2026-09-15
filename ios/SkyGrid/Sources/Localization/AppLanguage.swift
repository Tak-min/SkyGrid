import Foundation
import Observation
import ObjectiveC.runtime

/// The two in-app languages Sky Grid currently supports. A missing persisted code
/// means the user has never made an explicit choice, so device-language inference
/// remains authoritative for existing installs.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .english: L10n.string("language.english", language: self)
        case .japanese: L10n.string("language.japanese", language: self)
        }
    }

    static func inferred(from preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let first = preferredLanguages.first else { return .english }
        return Locale(identifier: first).language.languageCode?.identifier == "ja" ? .japanese : .english
    }

    static func onboardingInitialSelection(
        from preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage? {
        guard let first = preferredLanguages.first,
              let code = Locale(identifier: first).language.languageCode?.identifier
        else { return .english }
        switch code {
        case "ja": return .japanese
        case "en": return .english
        default: return nil
        }
    }
}

@MainActor
@Observable
final class LocalizationController {
    private(set) var language: AppLanguage

    init() {
        language = LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.inferred()
    }

    var hasExplicitSelection: Bool { LocalDefaults.selectedLanguageCode != nil }

    func select(_ language: AppLanguage, resyncNotifications: Bool = true) {
        guard self.language != language || LocalDefaults.selectedLanguageCode == nil else { return }
        self.language = language
        LocalDefaults.selectedLanguageCode = language.rawValue
        NotificationCenter.default.post(name: .skyGridLanguageDidChange, object: nil)
        guard resyncNotifications else { return }
        Task { await MorningAlarmScheduler.resyncLocalizedContent() }
    }
}

enum L10n {
    static func resource(_ key: String, language: AppLanguage? = nil) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: string(key, language: language))
    }

    static func string(_ key: String, language: AppLanguage? = nil) -> String {
        let resolved = language
            ?? LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.inferred()
        guard let path = Bundle.main.path(forResource: resolved.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(key, bundle: .main, value: key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, value: key, comment: "")
    }
}


/// Redirects Bundle.main localization lookup to the language selected inside the app.
/// The observable controller still invalidates SwiftUI when the selection changes;
/// this override is the piece that makes existing `Text("…")` lookups consult the
/// selected `.lproj` instead of the process-start language.
enum LocalizationBundleOverride {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        guard
            let original = class_getInstanceMethod(Bundle.self, #selector(Bundle.localizedString(forKey:value:table:))),
            let replacement = class_getInstanceMethod(Bundle.self, #selector(Bundle.sg_localizedString(forKey:value:table:)))
        else { return }
        method_exchangeImplementations(original, replacement)
    }
}

private extension Bundle {
    @objc func sg_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard self === Bundle.main else {
            return sg_localizedString(forKey: key, value: value, table: tableName)
        }
        let language = LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.inferred()
        guard let path = path(forResource: language.rawValue, ofType: "lproj"),
              let languageBundle = Bundle(path: path)
        else {
            return sg_localizedString(forKey: key, value: value, table: tableName)
        }
        return languageBundle.sg_localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Notification.Name {
    /// Posted whenever `LocalizationController.select(_:)` changes the in-app
    /// language, so other services (e.g. `FirebaseDeviceRegistrar`) can react without
    /// `LocalizationController` needing a direct reference to them.
    static let skyGridLanguageDidChange = Notification.Name("SkyGrid.LanguageDidChange")
}
