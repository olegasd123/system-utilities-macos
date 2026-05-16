import AppCore
import AppUninstallerCore
import SwiftUI

struct AppUninstallerConfirmationOverlay: View {
    @Environment(\.appLocalization) private var localization
    @ObservedObject var model: AppUninstallerModel
    @ObservedObject var settingsModel: SettingsModel<AppUninstallerSettings>
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text(confirmationTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(confirmationMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    Button(role: settingsModel.settings.defaultReclaimMode == .hardDelete ? .destructive : nil) {
                        confirmUninstall()
                    } label: {
                        Text(confirmationButtonTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(confirmButtonBackground, in: RoundedRectangle(cornerRadius: 8))

                    Button(localization("Cancel")) {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(20)
            .frame(width: 286)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.45), lineWidth: 1)
            }
            .shadow(radius: 18)
        }
        .transition(.opacity)
    }

    private var confirmationTitle: String {
        settingsModel.settings.defaultReclaimMode == .hardDelete
            ? localization("Permanently delete app?")
            : localization("Uninstall app?")
    }

    private var confirmationMessage: String {
        let count = 1 + model.selectedLeftovers.count
        let mode = settingsModel.settings.defaultReclaimMode == .hardDelete
            ? localization("deleted right away")
            : localization("moved to Trash")
        return localization(
            "%d items will be %@. Running app will be asked to quit.",
            count,
            mode
        )
    }

    private var confirmationButtonTitle: String {
        settingsModel.settings.defaultReclaimMode == .hardDelete
            ? localization("Delete Permanently")
            : localization("Move to Trash")
    }

    private var confirmButtonBackground: some ShapeStyle {
        settingsModel.settings.defaultReclaimMode == .hardDelete
            ? AnyShapeStyle(Color.red.opacity(0.22))
            : AnyShapeStyle(Color.accentColor.opacity(0.2))
    }

    private func confirmUninstall() {
        onConfirm()
        isPresented = false
        Task {
            await model.uninstallSelected()
        }
    }
}
