import AppKit
import UniformTypeIdentifiers

class DockManager: DockWindowDelegate, DockSettingsDelegate {
    static let shared = DockManager()

    private var dockConfigs: [DockConfiguration] = []
    private var dockWindows: [UUID: DockWindow] = [:]
    private var settingsWindow: DockSettingsWindow?

    private init() {}

    // MARK: - Initialization

    func initialize() {
        dockConfigs = PersistenceManager.shared.loadDocks()

        if dockConfigs.isEmpty {
            let defaultConfig = DockConfiguration(
                name: "Dock 1",
                screenIndex: 0,
                position: .bottom,
                items: []
            )
            dockConfigs.append(defaultConfig)
            saveAll()
        }

        for config in dockConfigs {
            createDockWindow(for: config)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    // MARK: - Window Management

    private func createDockWindow(for config: DockConfiguration) {
        let window = DockWindow(config: config)
        window.dockDelegate = self
        window.positionOnScreen()
        window.orderFront(nil)
        dockWindows[config.id] = window
    }

    // MARK: - Dock CRUD

    var allDocks: [DockConfiguration] {
        return dockConfigs
    }

    func createNewDock() {
        let newConfig = DockConfiguration(
            name: "Dock \(dockConfigs.count + 1)",
            screenIndex: 0,
            position: .bottom,
            items: []
        )
        let window = DockSettingsWindow(config: newConfig, isNew: true)
        window.settingsDelegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func editDock(_ config: DockConfiguration) {
        let window = DockSettingsWindow(config: config, isNew: false)
        window.settingsDelegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func deleteDock(_ config: DockConfiguration) {
        dockConfigs.removeAll { $0.id == config.id }
        if let window = dockWindows.removeValue(forKey: config.id) {
            window.close()
        }
        saveAll()
        settingsWindow?.close()
        settingsWindow = nil
    }

    func addAppToDock(withId dockId: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Uygulama Seç"
        panel.message = "Dock'a eklemek istediğiniz uygulamayı seçin"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        NSApp.activate(ignoringOtherApps: true)

        let response = panel.runModal()
        guard response == .OK else { return }

        guard let configIndex = dockConfigs.firstIndex(where: { $0.id == dockId }) else { return }

        for url in panel.urls {
            let normalizedPath = url.resolvingSymlinksInPath().path
            let item = DockItem(appPath: normalizedPath)
            if !dockConfigs[configIndex].items.contains(where: { $0.appPath == normalizedPath }) {
                dockConfigs[configIndex].items.append(item)
            }
        }

        if let window = dockWindows[dockId] {
            window.updateConfiguration(dockConfigs[configIndex])
        }

        saveAll()
        NotificationCenter.default.post(name: Notification.Name("SecondDockConfigsChanged"), object: nil)
    }

    func removeItem(_ item: DockItem, fromDockWithId dockId: UUID) {
        guard let configIndex = dockConfigs.firstIndex(where: { $0.id == dockId }) else { return }

        dockConfigs[configIndex].items.removeAll { $0.id == item.id }

        if let window = dockWindows[dockId] {
            window.updateConfiguration(dockConfigs[configIndex])
        }

        saveAll()
        NotificationCenter.default.post(name: Notification.Name("SecondDockConfigsChanged"), object: nil)
    }

    // MARK: - Monitor Change

    @objc func screenParametersDidChange(_ notification: Notification) {
        for (_, window) in dockWindows {
            window.positionOnScreen()
        }
    }

    // MARK: - Show/Hide All

    func toggleAllDocks() {
        let anyVisible = dockWindows.values.contains { $0.isVisible }
        if anyVisible {
            for (_, window) in dockWindows {
                window.orderOut(nil)
            }
        } else {
            for (_, window) in dockWindows {
                window.orderFront(nil)
            }
        }
    }

    // MARK: - Persistence

    private func saveAll() {
        PersistenceManager.shared.saveDocks(dockConfigs)
    }

    // MARK: - DockWindowDelegate

    func dockWindowItemsDidChange(_ window: DockWindow, items: [DockItem]) {
        let configId = window.config.id
        guard let configIndex = dockConfigs.firstIndex(where: { $0.id == configId }) else { return }
        dockConfigs[configIndex].items = items
        saveAll()
        NotificationCenter.default.post(name: Notification.Name("SecondDockConfigsChanged"), object: nil)
    }

    func dockWindowSizeDidChange(_ window: DockWindow, size: CGFloat) {
        let configId = window.config.id
        guard let configIndex = dockConfigs.firstIndex(where: { $0.id == configId }) else { return }
        dockConfigs[configIndex].iconSize = size
        saveAll()
    }

    func dockWindowRequestsRemoveItem(_ window: DockWindow, item: DockItem) {
        removeItem(item, fromDockWithId: window.config.id)
    }

    func dockWindowRequestsAddApp(_ window: DockWindow) {
        addAppToDock(withId: window.config.id)
    }

    func dockWindowRequestsSettings(_ window: DockWindow) {
        editDock(window.config)
    }

    // MARK: - DockSettingsDelegate

    func dockSettingsDidSave(_ config: DockConfiguration, isNew: Bool) {
        if isNew {
            dockConfigs.append(config)
            createDockWindow(for: config)
        } else {
            if let idx = dockConfigs.firstIndex(where: { $0.id == config.id }) {
                dockConfigs[idx] = config
                dockWindows[config.id]?.updateConfiguration(config)
            }
        }
        saveAll()
        settingsWindow?.close()
        settingsWindow = nil
        NotificationCenter.default.post(name: Notification.Name("SecondDockConfigsChanged"), object: nil)
    }

    func dockSettingsDidCancel() {
        settingsWindow?.close()
        settingsWindow = nil
    }

    func dockSettingsDidDelete(_ config: DockConfiguration) {
        deleteDock(config)
        NotificationCenter.default.post(name: Notification.Name("SecondDockConfigsChanged"), object: nil)
    }
}
