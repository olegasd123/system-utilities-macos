import AppKit
import Foundation
import Sparkle

@MainActor
final class AppUpdater {
    private let updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        guard Self.hasUpdateConfiguration(bundle: bundle) else {
            updaterController = nil
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func configureCheckForUpdatesMenuItem(_ item: NSMenuItem) {
        guard let updaterController else {
            item.isEnabled = false
            return
        }

        item.target = updaterController
        item.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
    }

    private static func hasUpdateConfiguration(bundle: Bundle) -> Bool {
        guard
            let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        return !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
