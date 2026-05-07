import Combine
import SwiftUI

@MainActor
public protocol AppFeature: AnyObject {
    /// Stable identifier (used for routing).
    var id: String { get }

    /// Human-readable name shown in tabs and settings sections.
    var displayName: String { get }

    /// SF Symbol name for nav UI.
    var symbolName: String { get }

    /// Optional settings section embedded in the global preferences screen.
    /// Return `nil` if the feature has no user-facing settings.
    func makeSettingsSection() -> AnyView?

    /// Called by the shell when this feature's primary UI becomes visible/hidden.
    /// Use to start or pause work that's only needed while the user is interacting
    /// with the feature. Default is a no-op.
    func setActive(_ active: Bool)
}

extension AppFeature {
    public func setActive(_ active: Bool) {}
}

@MainActor
public protocol PopoverFeature: AppFeature {
    /// Body content rendered when this feature is the active popover route.
    /// The shell renders its own chrome (title, settings gear).
    func makeRootView() -> AnyView
}

@MainActor
public protocol MenuBarFeature: AppFeature {
    /// Latest menu-bar lines this feature contributes. Empty array == nothing to show.
    var currentMenuBarLines: [MenuBarStatusLine] { get }

    /// Publisher firing when `currentMenuBarLines` changes.
    var menuBarLinesPublisher: AnyPublisher<[MenuBarStatusLine], Never> { get }
}
