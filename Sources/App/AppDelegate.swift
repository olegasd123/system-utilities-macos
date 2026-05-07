import AppCore
import AppKit
import AppUI
import Combine
import SwiftUI
import SystemMonitor

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let menuBarStatusView = MenuBarStatusView()
    private let popover = NSPopover()
    private let settingsStore = AppSettingsStore.standard
    private lazy var initialLoad = settingsStore.loadResult()
    private lazy var settingsModel = SettingsModel<AppSettings>(
        initial: initialLoad.settings,
        onChange: { [settingsStore] settings in
            try? settingsStore.save(settings)
        }
    )
    private lazy var launchAtLoginModel = LaunchAtLoginModel(
        initiallyLoadedFromDisk: initialLoad.loadedFromDisk,
        initialLaunchAtLogin: initialLoad.settings.general.launchAtLogin,
        persist: { [unowned self] isRegistered in
            settingsModel.settings.general.launchAtLogin = isRegistered
        }
    )
    private lazy var monitorModel = SystemMonitorModel(
        currentSettings: { [unowned self] in settingsModel.settings.systemMonitor }
    )
    private lazy var systemMonitorFeature = makeSystemMonitorFeature()
    private lazy var features: [any AppFeature] = [systemMonitorFeature]
    private lazy var router = PopoverRouter(initialFeatureId: features.first?.id ?? "")
    private lazy var statusMenu = makeStatusMenu()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = launchAtLoginModel
        _ = monitorModel
        _ = features
        configureStatusItem()
        configurePopover()
        configureDismissalObservers()
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
        popover.delegate = self
        updatePopoverContentSize()
        popover.contentViewController = NSHostingController(
            rootView: RootPopoverView(
                router: router,
                settingsModel: settingsModel,
                launchAtLoginModel: launchAtLoginModel,
                features: features
            )
        )
    }

    private func configureDismissalObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopoverAfterAppResignedActive),
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
    }

    private func updatePopoverContentSize() {
        let size = PopoverLayout.contentSize
        let contentSize = NSSize(width: size.width, height: size.height)
        guard popover.contentSize != contentSize else {
            return
        }

        let oldSize = popover.contentSize
        popover.contentSize = contentSize
        popover.contentViewController?.preferredContentSize = contentSize

        guard
            popover.isShown,
            let window = popover.contentViewController?.view.window
        else {
            return
        }

        var frame = window.frame
        let widthDelta = contentSize.width - oldSize.width
        let heightDelta = contentSize.height - oldSize.height
        frame.origin.y -= heightDelta
        frame.size.width += widthDelta
        frame.size.height += heightDelta
        window.setFrame(frame, display: true)
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

        NSApp.activate()

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }

        focusPopoverWindow()
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.focusPopoverWindow()
        }
    }

    private func focusPopoverWindow() {
        guard let window = popover.contentViewController?.view.window else {
            return
        }

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func closePopoverAfterAppResignedActive() {
        guard popover.isShown else {
            return
        }

        popover.performClose(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeSystemMonitorFeature() -> SystemMonitorFeature {
        let monitorChanges = settingsModel.$settings
            .map(\.systemMonitor)
            .removeDuplicates()
            .eraseToAnyPublisher()
        let temperatureUnitChanges = settingsModel.$settings
            .map(\.general.temperatureUnit)
            .removeDuplicates()
            .eraseToAnyPublisher()
        let monitorBinding = Binding<SystemMonitorSettings>(
            get: { [unowned self] in settingsModel.settings.systemMonitor },
            set: { [unowned self] in settingsModel.settings.systemMonitor = $0 }
        )
        let temperatureUnitBinding = Binding<TemperatureUnit>(
            get: { [unowned self] in settingsModel.settings.general.temperatureUnit },
            set: { [unowned self] in settingsModel.settings.general.temperatureUnit = $0 }
        )
        return SystemMonitorFeature(
            model: monitorModel,
            currentSettings: { [unowned self] in settingsModel.settings.systemMonitor },
            currentTemperatureUnit: { [unowned self] in settingsModel.settings.general.temperatureUnit },
            settingsBinding: monitorBinding,
            temperatureUnitBinding: temperatureUnitBinding,
            settingsChanges: monitorChanges,
            temperatureUnitChanges: temperatureUnitChanges
        )
    }

    private func bindStatusItem() {
        let menuBarFeatures = features.compactMap { $0 as? any MenuBarFeature }

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
        let isShown = popover.isShown
        let activeId: String? = {
            if case .feature(let id) = router.route {
                return id
            }
            return nil
        }()
        for feature in features {
            feature.setActive(isShown && activeId == feature.id)
        }
    }

    private func updateStatusItem() {
        let lines = features
            .compactMap { $0 as? any MenuBarFeature }
            .flatMap(\.currentMenuBarLines)
        menuBarStatusView.update(lines: lines)
        statusItem?.length = menuBarStatusView.preferredWidth
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        updateFeatureVisibility()
    }

    func popoverDidClose(_ notification: Notification) {
        updateFeatureVisibility()
    }
}
