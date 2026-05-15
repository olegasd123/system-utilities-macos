import AppCore

enum AppUninstallerFormatter {
    static func bytes(
        _ bytes: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        if bytes == 0 {
            return AppFormatters.bytes(0, localization: localization)
        }
        return AppFormatters.bytes(bytes, localization: localization)
    }
}
