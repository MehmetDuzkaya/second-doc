import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "SecondDock") {
                image.isTemplate = true
                button.image = image
            } else if let fallback = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "SecondDock") {
                fallback.isTemplate = true
                button.image = fallback
            } else {
                button.title = "⚓️"
            }
        }

        // Initialize DockManager
        DockManager.shared.initialize()

        // Build menu
        statusItem.menu = buildMenu()

        // Observe changes to rebuild menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configsChanged),
            name: Notification.Name("SecondDockConfigsChanged"),
            object: nil
        )

        print("[SecondDock] Başarıyla başlatıldı.")
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Title item (disabled)
        let titleItem = NSMenuItem(title: "SecondDock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        // "➕ Yeni Dock Oluştur..."
        let createItem = NSMenuItem(title: "➕ Yeni Dock Oluştur...", action: #selector(createNewDock), keyEquivalent: "n")
        createItem.target = self
        menu.addItem(createItem)
        menu.addItem(.separator())

        // List existing docks with submenus
        let docks = DockManager.shared.allDocks
        if docks.isEmpty {
            let noDocksItem = NSMenuItem(title: "Henüz dock yok", action: nil, keyEquivalent: "")
            noDocksItem.isEnabled = false
            menu.addItem(noDocksItem)
        } else {
            let headerItem = NSMenuItem(title: "Mevcut Dock'lar:", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            for dock in docks {
                let dockItem = NSMenuItem(title: "  🖥️ \(dock.name)", action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                // Show screen and position info
                let infoItem = NSMenuItem(title: "Monitör \(dock.screenIndex + 1) • \(dock.position.displayName) (\(dock.items.count) öğe)", action: nil, keyEquivalent: "")
                infoItem.isEnabled = false
                submenu.addItem(infoItem)
                submenu.addItem(.separator())

                // "Uygulama veya Dosya Ekle..." action
                let addItem = NSMenuItem(title: "Uygulama veya Dosya Ekle...", action: #selector(addAppToDock(_:)), keyEquivalent: "")
                addItem.target = self
                addItem.representedObject = dock.id
                submenu.addItem(addItem)

                // "Ayarlar..." action
                let settingsItem = NSMenuItem(title: "Ayarlar...", action: #selector(editDock(_:)), keyEquivalent: "")
                settingsItem.target = self
                settingsItem.representedObject = dock.id
                submenu.addItem(settingsItem)

                // "Sil" action
                submenu.addItem(.separator())
                let deleteItem = NSMenuItem(title: "Dock'u Sil", action: #selector(deleteDock(_:)), keyEquivalent: "")
                deleteItem.target = self
                deleteItem.representedObject = dock.id
                submenu.addItem(deleteItem)

                dockItem.submenu = submenu
                menu.addItem(dockItem)
            }
        }

        menu.addItem(.separator())

        // "Tümünü Göster/Gizle"
        let toggleItem = NSMenuItem(title: "Tümünü Göster/Gizle", action: #selector(toggleAllDocks), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // "Hakkında SecondDock"
        let aboutItem = NSMenuItem(title: "Hakkında SecondDock", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // "Çıkış"
        let quitItem = NSMenuItem(title: "Çıkış", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc func createNewDock() {
        DockManager.shared.createNewDock()
    }

    @objc func addAppToDock(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID {
            DockManager.shared.addAppToDock(withId: id)
        }
    }

    @objc func toggleDockVisibility(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
             let window = DockManager.shared.dockWindow(for: id) else { return }
        if window.isVisible {
           window.orderOut(nil)
        } else {
           window.orderFront(nil)
        }
    }

    @objc func editDock(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID,
           let config = DockManager.shared.allDocks.first(where: { $0.id == id }) {
           DockManager.shared.editDock(config)
        }
    }

    @objc func deleteDock(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID,
           let config = DockManager.shared.allDocks.first(where: { $0.id == id }) {
            let alert = NSAlert()
            alert.messageText = "Dock'u Sil"
            alert.informativeText = "'\(config.name)' dock'unu silmek istediğinize emin misiniz?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Sil")
            alert.addButton(withTitle: "İptal")
            if alert.runModal() == .alertFirstButtonReturn {
                DockManager.shared.deleteDock(config)
                configsChanged()
            }
        }
    }

    @objc func toggleAllDocks() {
        DockManager.shared.toggleAllDocks()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "SecondDock"
        alert.informativeText = "Çoklu Monitör Dock Yöneticisi\n\nHer monitörünüze özel, bağımsız dock'lar oluşturun.\nSürükle-bırak ile uygulama ekleyin veya silin.\n\nSürüm 1.0.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func configsChanged() {
        statusItem.menu = buildMenu()
    }
}
