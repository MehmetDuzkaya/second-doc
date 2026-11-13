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
    private var previewWindowController: NSWindowController?

    init(item: DockItem, size: CGFloat) {
        self.item = item
        self.baseSize = size
        self.currentSize = size
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))

        toolTip = item.name
        iconImage = makeIconImage()
        iconImage?.size = NSSize(width: size, height: size)

        wantsLayer = true
    }

    private func makeIconImage() -> NSImage? {
        if item.kind == .file, let fileURL = item.filePath.flatMap(URL.init(fileURLWithPath:)) {
            return NSWorkspace.shared.icon(forFile: fileURL.path)
        }
        return NSWorkspace.shared.icon(forFile: item.appPath)
    }

    func updateSize(_ newSize: CGFloat) {
        baseSize = newSize
        currentSize = newSize
        iconImage = makeIconImage()
        iconImage?.size = NSSize(width: newSize, height: newSize)
        needsDisplay = true
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
            let drawSize = min(currentSize, bounds.height)
            let x = (bounds.width - drawSize) / 2
            let y = (bounds.height - drawSize) / 2
            iconRect = NSRect(x: x, y: y, width: drawSize, height: drawSize)
        } else {
            let drawSize = currentSize
            let x = (bounds.width - drawSize) / 2
            let y = (bounds.height - drawSize) / 2
            iconRect = NSRect(x: x, y: y, width: drawSize, height: drawSize)
        }

        icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        if isRunning && showRunningIndicator {
            let dotSize: CGFloat = 4.5
            let dotX = (bounds.width - dotSize) / 2
            let dotY: CGFloat = 1.5
            let dotRect = NSRect(x: dotX, y: dotY, width: dotSize, height: dotSize)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            NSColor(white: 0.95, alpha: 0.9).setFill()
            dotPath.fill()
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        if item.kind == .file, let fileURL = item.filePath.flatMap(URL.init(fileURLWithPath:)) {
            if event.clickCount >= 2 {
                NSWorkspace.shared.open(fileURL)
                delegate?.dockItemClicked(item)
                return
            }

            openPreview(for: fileURL)
            delegate?.dockItemClicked(item)
            return
        }

        let appURL = URL(fileURLWithPath: item.appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }

        delegate?.dockItemClicked(item)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: item.name, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: item.kind == .file ? "Dosyayı Aç" : "Uygulamayı Aç", action: #selector(openItem), keyEquivalent: "")
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

    @objc private func openItem() {
        if item.kind == .file, let fileURL = item.filePath.flatMap(URL.init(fileURLWithPath:)) {
            openPreview(for: fileURL)
            return
        }
        let appURL = URL(fileURLWithPath: item.appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
    }

    @objc private func showInFinder() {
        let targetURL: URL
        if let filePath = item.filePath {
            targetURL = URL(fileURLWithPath: filePath)
        } else {
            targetURL = URL(fileURLWithPath: item.appPath)
        }
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }

    @objc private func removeFromDock() {
        delegate?.dockItemRemoveRequested(item)
    }

    private func openPreview(for url: URL) {
        if let existing = previewWindowController?.window, existing.isVisible {
            existing.close()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = url.lastPathComponent
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        let contentView = NSView(frame: window.contentLayoutRect)
        contentView.wantsLayer = true

        let imageView = NSImageView(frame: contentView.bounds)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]

        if let image = NSImage(contentsOf: url) {
            imageView.image = image
        } else {
            let fallback = NSWorkspace.shared.icon(forFile: url.path)
            fallback.size = NSSize(width: 128, height: 128)
            imageView.image = fallback
        }

        let labels = NSTextField(wrappingLabelWithString: "\(url.lastPathComponent)\n\(url.path)")
        labels.isEditable = false
        labels.isBordered = false
        labels.isBezeled = false
        labels.drawsBackground = false
        labels.font = NSFont.systemFont(ofSize: 13)
        labels.textColor = .labelColor

        let stack = NSStackView(frame: NSRect(x: 16, y: 16, width: contentView.bounds.width - 32, height: contentView.bounds.height - 32))
        stack.orientation = .vertical
        stack.spacing = 16
        stack.addView(imageView, in: .center)
        stack.addView(labels, in: .center)
        stack.setVisibilityPriority(.mustHold, for: imageView)
        stack.setVisibilityPriority(.mustHold, for: labels)
        contentView.addSubview(stack)
        window.contentView = contentView

        previewWindowController = NSWindowController(window: window)
        previewWindowController?.showWindow(nil)
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

    // MARK: - Running State

    func updateRunningState() {
        if item.kind == .file {
            isRunning = false
        } else if let bid = item.bundleIdentifier {
            isRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bid }
        } else {
            isRunning = false
        }
        needsDisplay = true
    }
}
