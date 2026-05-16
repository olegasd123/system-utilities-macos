import AppCore

enum CleanDriveFormatter {
    static func bytes(
        _ bytes: UInt64,
        localization: AppLocalization = AppLocalization(selection: .english)
    ) -> String {
        AppFormatters.bytes(bytes, localization: localization)
    }
}
