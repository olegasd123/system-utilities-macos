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
    private lazy var fallbackStatusImage = makeFallbackStatusImage()
    private lazy var router = PopoverRouter(initialFeatureId: composer.features.first?.id ?? "")
    private lazy var statusMenu = makeStatusMenu()
    private var cancellables = Set<AnyCancellable>()

    private var localization: AppLocalization {
        AppLocalization(selection: composer.generalSettings.settings.language)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        bindStatusItem()
        composer.cleanDriveReminderService.start()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.toolTip = localization("System Monitor")
            button.setAccessibilityLabel(localization("System Monitor"))
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

    private func makeStatusMenu(localization: AppLocalization? = nil) -> NSMenu {
        let localization = localization ?? self.localization
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: localization("Preferences..."),
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: localization("Quit System Monitor"),
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func makeFallbackStatusImage() -> NSImage {
        let image = Bundle.main.image(forResource: "AppIcon")
            ?? NSApp.applicationIconImage
            ?? NSImage(
                systemSymbolName: "gauge.with.dots.needle.67percent",
                accessibilityDescription: localization("System Monitor")
            )
            ?? NSImage(size: NSSize(width: 18, height: 18))
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: 18, height: 18)
        copy.isTemplate = true
        return copy
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
                }
                .store(in: &cancellables)
        }

        router.$route
            .sink { [weak self] _ in
                self?.updatePopoverContentSize()
                self?.updateFeatureVisibility()
            }
            .store(in: &cancellables)

        composer.generalSettings.publisher
            .map(\.language)
            .removeDuplicates()
            .sink { [weak self] language in
                self?.updateAppLanguage(selection: language)
            }
            .store(in: &cancellables)
    }

    private func updateAppLanguage(selection: AppLanguage? = nil) {
        let localization = AppLocalization(
            selection: selection ?? composer.generalSettings.settings.language
        )
        if let button = statusItem?.button {
            button.toolTip = localization("System Monitor")
            button.setAccessibilityLabel(localization("System Monitor"))
        }
        statusMenu = makeStatusMenu(localization: localization)
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

        if let button = statusItem.button {
            let showsFallbackIcon = lines.isEmpty
            button.image = showsFallbackIcon ? fallbackStatusImage : nil
            menuBarStatusView.isHidden = showsFallbackIcon
        }

        let preferredLength = lines.isEmpty
            ? NSStatusItem.squareLength
            : menuBarStatusView.preferredWidth

        if statusItem.length != preferredLength {
            statusItem.length = preferredLength
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
