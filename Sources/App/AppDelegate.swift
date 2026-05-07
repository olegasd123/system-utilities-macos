import AppCore
import AppKit
import AppUI
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let composer = AppComposer()
    private var statusItem: NSStatusItem?
    private let menuBarStatusView = MenuBarStatusView()
    private let popoverWindow = ArrowlessPopoverPanel()
    private lazy var router = PopoverRouter(initialFeatureId: composer.features.first?.id ?? "")
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
        updatePopoverContentSize()
        popoverWindow.delegate = self
        popoverWindow.contentViewController = NSHostingController(
            rootView: RootPopoverView(
                router: router,
                generalSettings: composer.generalSettings,
                launchAtLoginModel: composer.launchAtLoginModel,
                features: composer.features
            )
        )
    }

    private func updatePopoverContentSize() {
        let size = PopoverLayout.contentSize
        let contentSize = NSSize(width: size.width, height: size.height)
        guard popoverWindow.frame.size != contentSize else {
            return
        }

        let oldSize = popoverWindow.frame.size
        popoverWindow.setContentSize(contentSize)
        popoverWindow.contentViewController?.preferredContentSize = contentSize

        guard
            popoverWindow.isVisible
        else {
            return
        }

        var frame = popoverWindow.frame
        let widthDelta = contentSize.width - oldSize.width
        let heightDelta = contentSize.height - oldSize.height
        frame.origin.y -= heightDelta
        frame.size.width += widthDelta
        frame.size.height += heightDelta
        popoverWindow.setFrame(frame, display: true)
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
        if popoverWindow.isVisible {
            hidePopover()
            return
        }

        showPopover(from: button)
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

        router.showSettings()
        showPopover(from: button)
    }

    private func showPopover(from button: NSStatusBarButton) {
        updatePopoverContentSize()

        NSApp.activate(ignoringOtherApps: true)

        if !popoverWindow.isVisible {
            positionPopoverWindow(relativeTo: button)
            popoverWindow.makeKeyAndOrderFront(nil)
        }

        focusPopoverWindow()
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.focusPopoverWindow()
        }
    }

    private func positionPopoverWindow(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else {
            return
        }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = PopoverLayout.contentSize
        let screenFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let margin: CGFloat = 8
        var x = buttonFrame.midX - size.width / 2
        x = min(max(x, screenFrame.minX + margin), screenFrame.maxX - size.width - margin)

        let y = max(screenFrame.minY + margin, buttonFrame.minY - size.height - margin)
        popoverWindow.setFrame(
            NSRect(x: x, y: y, width: size.width, height: size.height),
            display: true
        )
    }

    private func focusPopoverWindow() {
        NSApp.activate(ignoringOtherApps: true)
        popoverWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func hidePopover() {
        guard popoverWindow.isVisible else {
            return
        }

        popoverWindow.orderOut(nil)
        updateFeatureVisibility()
    }

    private func bindStatusItem() {
        let menuBarFeatures = composer.features.compactMap { $0 as? any MenuBarFeature }

        if menuBarFeatures.isEmpty {
            updateStatusItem()
        } else {
            let publishers = menuBarFeatures.map(\.menuBarLinesPublisher)
            Publishers.MergeMany(publishers)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateStatusItem()
                    self?.updatePopoverContentSize()
                }
                .store(in: &cancellables)
        }

        router.$route
            .sink { [weak self] _ in
                self?.updatePopoverContentSize()
                self?.updateFeatureVisibility()
            }
            .store(in: &cancellables)
    }

    private func updateFeatureVisibility() {
        let isShown = popoverWindow.isVisible
        let activeId: String? = {
            if case .feature(let id) = router.route {
                return id
            }
            return nil
        }()
        for feature in composer.features {
            feature.setActive(isShown && activeId == feature.id)
        }
    }

    private func updateStatusItem() {
        let lines = composer.features
            .compactMap { $0 as? any MenuBarFeature }
            .flatMap(\.currentMenuBarLines)
        menuBarStatusView.update(lines: lines)
        guard let statusItem else {
            return
        }

        guard
            popoverWindow.isVisible
        else {
            statusItem.length = menuBarStatusView.preferredWidth
            return
        }

        let frame = popoverWindow.frame
        statusItem.length = menuBarStatusView.preferredWidth
        popoverWindow.setFrame(frame, display: true)
        Task { @MainActor [weak self] in
            await Task.yield()
            guard self?.popoverWindow.isVisible == true else {
                return
            }
            self?.popoverWindow.setFrame(frame, display: true)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        updateFeatureVisibility()
    }

    func windowDidResignKey(_ notification: Notification) {
        hidePopover()
    }

    func windowWillClose(_ notification: Notification) {
        for feature in composer.features {
            feature.setActive(false)
        }
    }
}

private final class ArrowlessPopoverPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
