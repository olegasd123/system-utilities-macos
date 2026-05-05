import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let menuBarStatusView = MenuBarStatusView()
    private let popover = NSPopover()
    private let popoverRouter = PopoverRouter()
    private let appState = AppState()
    private lazy var statusMenu = makeStatusMenu()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        bindStatusItem()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = ""
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.addSubview(menuBarStatusView)
            menuBarStatusView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                menuBarStatusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                menuBarStatusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                menuBarStatusView.topAnchor.constraint(equalTo: button.topAnchor),
                menuBarStatusView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }
        statusItem = item
        updateStatusItem()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 450, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: RootPopoverView(
                router: popoverRouter,
                appState: appState,
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem?.button else {
            return
        }

        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu(from: button)
            return
        }

        togglePopover(from: button)
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        popoverRouter.route = .dashboard
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showStatusMenu(from button: NSStatusBarButton) {
        statusItem?.menu = statusMenu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Preferences...",
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit System Monitor",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func openPreferences() {
        guard let button = statusItem?.button else {
            return
        }

        popoverRouter.route = .settings
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func bindStatusItem() {
        appState.$snapshot
            .combineLatest(appState.$settings)
            .sink { [weak self] _, _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        let lines = MenuBarFormatter.lines(
            snapshot: appState.snapshot,
            settings: appState.settings
        )
        menuBarStatusView.update(lines: lines)
        statusItem?.length = menuBarStatusView.preferredWidth
    }
}
