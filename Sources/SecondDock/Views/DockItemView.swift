import AppKit

protocol DockItemViewDelegate: AnyObject {
    func dockItemClicked(_ item: DockItem)
    func dockItemRemoveRequested(_ item: DockItem)
}

class DockItemView: NSView {
    let item: DockItem
    weak var delegate: DockItemViewDelegate?

    var baseSize: CGFloat = 48
    var currentSize: CGFloat = 48
    var isRunning: Bool = false
    var showRunningIndicator: Bool = true

    private var iconImage: NSImage?
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false

    init(item: DockItem, size: CGFloat) {
        self.item = item
        self.baseSize = size
        self.currentSize = size
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))

        toolTip = item.name
        iconImage = NSWorkspace.shared.icon(forFile: item.appPath)
        iconImage?.size = NSSize(width: size, height: size)

        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let icon = iconImage else { return }

        let iconRect: NSRect
        if showRunningIndicator {
            // Leave space for indicator dot at the bottom
            let availableHeight = bounds.height - 6
            let drawSize = min(currentSize, availableHeight)
            let x = (bounds.width - drawSize) / 2
            let y = (availableHeight - drawSize) / 2 + 6
            iconRect = NSRect(x: x, y: y, width: drawSize, height: drawSize)
        } else {
            let drawSize = currentSize
            let x = (bounds.width - drawSize) / 2
            let y = (bounds.height - drawSize) / 2
            iconRect = NSRect(x: x, y: y, width: drawSize, height: drawSize)
        }

        // Draw icon with hover brightness
        if isHovered {
            let highlightRect = iconRect.insetBy(dx: -2, dy: -2)
            let highlightPath = NSBezierPath(roundedRect: highlightRect, xRadius: 6, yRadius: 6)
            NSColor.white.withAlphaComponent(0.1).setFill()
            highlightPath.fill()
        }

        icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: isHovered ? 1.0 : 0.9)

        // Draw running indicator dot
        if isRunning && showRunningIndicator {
            let dotSize: CGFloat = 4
            let dotX = (bounds.width - dotSize) / 2
            let dotY: CGFloat = 1
            let dotRect = NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            NSColor.white.setFill()
            dotPath.fill()
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        // Bounce animation
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            ctx.allowsImplicitAnimation = true
            self.frame = self.frame.insetBy(dx: 3, dy: 3)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.08
                ctx.allowsImplicitAnimation = true
                self.frame = self.frame.insetBy(dx: -3, dy: -3)
            }, completionHandler: nil)
        })

        // Launch the application
        let appURL = URL(fileURLWithPath: item.appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }

        delegate?.dockItemClicked(item)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        // App name as header
        let headerItem = NSMenuItem(title: item.name, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Uygulamayı Aç", action: #selector(openApp), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let finderItem = NSMenuItem(title: "Finder'da Göster", action: #selector(showInFinder), keyEquivalent: "")
        finderItem.target = self
        menu.addItem(finderItem)

        menu.addItem(NSMenuItem.separator())

        let removeItem = NSMenuItem(title: "Dock'tan Kaldır", action: #selector(removeFromDock), keyEquivalent: "")
        removeItem.target = self
        menu.addItem(removeItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openApp() {
        let appURL = URL(fileURLWithPath: item.appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
    }

    @objc private func showInFinder() {
        let appURL = URL(fileURLWithPath: item.appPath)
        NSWorkspace.shared.activateFileViewerSelecting([appURL])
    }

    @objc private func removeFromDock() {
        delegate?.dockItemRemoveRequested(item)
    }

    // MARK: - Tracking Areas

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    // MARK: - Running State

    func updateRunningState() {
        if let bid = item.bundleIdentifier {
            isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bid }
        } else {
            isRunning = false
        }
        needsDisplay = true
    }
}
