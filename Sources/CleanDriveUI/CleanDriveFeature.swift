import AppCore
import AppUI
import CleanDriveCore
import Foundation
import SwiftUI

@MainActor
public final class CleanDriveFeature: ObservableObject, PopoverFeature {
    public let id = CleanDriveSettings.featureId
    public let displayName = "Clean Drive"
    public let symbolName = "internaldrive"

    public let model: CleanDriveModel

    private let settings: SettingsModel<CleanDriveSettings>

    public init(
        settings: SettingsModel<CleanDriveSettings>,
        model: CleanDriveModel
    ) {
        self.settings = settings
        self.model = model
    }

    public func makeRootView() -> AnyView {
        AnyView(CleanDrivePlaceholderView())
    }

    public func makeSettingsSection() -> AnyView? {
        nil
    }
}

private struct CleanDrivePlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "internaldrive")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Coming soon")
                .font(.system(size: 18, weight: .semibold))

            Text("Clean Drive will find safe space to reclaim on this Mac.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
