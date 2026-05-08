import AppCore
import AppKit
import AppUI
import SwiftUI

struct RootPopoverView: View {
    @ObservedObject var router: PopoverRouter
    @ObservedObject var generalSettings: SettingsModel<GeneralSettings>
    @ObservedObject var launchAtLoginModel: LaunchAtLoginModel
    let features: [any AppFeature]

    var body: some View {
        ZStack(alignment: .top) {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: PopoverLayout.titleSpacing) {
                header
                content
            }
            .padding(PopoverLayout.contentPadding)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
        }
        .frame(
            width: PopoverLayout.contentSize.width,
            height: PopoverLayout.contentSize.height
        )
    }

    @ViewBuilder
    private var header: some View {
        switch router.route {
        case .feature(let id):
            featureHeader(activeId: id)
        case .settings:
            settingsHeader
        }
    }

    private func featureHeader(activeId: String) -> some View {
        HStack {
            if features.count > 1 {
                featureTabs(activeId: activeId)
            } else {
                Color.clear.frame(width: 28, height: PopoverLayout.titleHeight)
            }

            Spacer()

            if let feature = features.first(where: { $0.id == activeId }) {
                Text(feature.displayName)
                    .font(.system(size: 14, weight: .semibold))
            }

            Spacer()

            Button {
                router.showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: PopoverLayout.titleHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .frame(height: PopoverLayout.titleHeight)
    }

    private var settingsHeader: some View {
        HStack {
            Button {
                router.dismissSettings()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 28, height: PopoverLayout.titleHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back")
            .accessibilityLabel("Back")

            Spacer()

            Text("Preferences")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 28, height: PopoverLayout.titleHeight)
        }
        .frame(height: PopoverLayout.titleHeight)
    }

    private func featureTabs(activeId: String) -> some View {
        HStack(spacing: 4) {
            ForEach(features, id: \.id) { feature in
                Button {
                    router.showFeature(feature.id)
                } label: {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(activeId == feature.id ? Color.accentColor : .secondary)
                        .frame(width: 28, height: PopoverLayout.titleHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(feature.displayName)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch router.route {
        case .feature(let id):
            if let feature = features.first(where: { $0.id == id }) as? PopoverFeature {
                feature.makeRootView()
            }
        case .settings:
            SettingsView(
                generalSettings: generalSettings,
                launchAtLoginModel: launchAtLoginModel,
                features: features
            )
        }
    }
}
