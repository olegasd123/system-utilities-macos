import AppCore
import SwiftUI

public struct SettingsSection<Content: View>: View {
    @Environment(\.appLocalization) private var localization
    private let title: String
    @ViewBuilder private let content: () -> Content

    public init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localization(title).uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }
}
