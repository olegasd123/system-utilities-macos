import AppCore
import SystemMonitorCore

enum FanCardFormatter {
    static func value(
        fans: [FanSample],
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        guard !fans.isEmpty else {
            return localization("No fan data")
        }

        if fans.count == 1 {
            return localization("%d fan", fans.count)
        }

        if localization.language.usesFewFanForm, usesFewForm(fans.count) {
            return localization("%d fans few", fans.count)
        }

        return localization("%d fans", fans.count)
    }

    static func subtitle(
        fans: [FanSample],
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        guard !fans.isEmpty else {
            return localization("Unavailable")
        }

        return fans.prefix(2)
            .map {
                let label = localizedFanLabel($0.label, localization: localization)
                return "\(label):  \($0.rpm) \(localization("RPM"))"
            }
            .joined(separator: "\n")
    }

    private static func localizedFanLabel(
        _ label: String,
        localization: AppLocalization
    ) -> String {
        let fanPrefix = "Fan "
        if label.hasPrefix(fanPrefix),
           let fanNumber = Int(label.dropFirst(fanPrefix.count)) {
            return localization("Fan %d", fanNumber)
        }

        return localization(label)
    }

    private static func usesFewForm(_ count: Int) -> Bool {
        let lastTwoDigits = count % 100
        if (12...14).contains(lastTwoDigits) {
            return false
        }

        return (2...4).contains(count % 10)
    }
}

private extension AppLanguage {
    var usesFewFanForm: Bool {
        self == .russian || self == .ukrainian
    }
}
