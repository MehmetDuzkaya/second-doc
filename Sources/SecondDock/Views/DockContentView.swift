import AppKit

protocol DockContentViewDelegate: AnyObject {
    func dockContentViewItemsChanged(_ items: [DockItem])
    func dockContentViewSizeChanged(_ size: CGFloat)
    func dockContentViewRequestsRemoveItem(_ item: DockItem)
    func dockContentViewRequestsAddApp()
}

class DockContentView: NSView, DockItemViewDelegate {
    var config: DockConfiguration
    weak var delegate: DockContentViewDelegate?

    private var itemViews: [DockItemView] = []
    private var emptyPlaceholderView: NSButton?
    private var backgroundView: NSVisualEffectView!
    private var runningCheckTimer: Timer?

    let spacing: CGFloat = 8
    let padding: CGFloat = 10
    let indicatorHeight: CGFloat = 8

    init(config: DockConfiguration) {
        self.config = config
        super.init(frame: .zero)

        wantsLayer = true

        // Set up visual effect background (authentic macOS frosted glass / vibrancy)
        backgroundView = NSVisualEffectView()
        backgroundView.material = .popover
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 18
        backgroundView.layer?.borderWidth = 0.5
        backgroundView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        backgroundView.layer?.masksToBounds = true
        addSubview(backgroundView)

        // Register for drag & drop
        registerForDraggedTypes([.fileURL])

        // Build initial item views
        rebuildItems()

        // Start running-app timer
        runningCheckTimer = Timer.scheduledTimer(
            timeInterval: 3.0,
            target: self,
            selector: #selector(checkRunningApps),
            userInfo: nil,
            repeats: true
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        runningCheckTimer?.invalidate()
    }

    // MARK: - Rebuild & Layout

    func rebuildItems() {
        // Remove existing item views
        for view in itemViews {
            view.removeFromSuperview()
        }
        itemViews.removeAll()
        emptyPlaceholderView?.removeFromSuperview()
        emptyPlaceholderView = nil

        // If dock has no items yet, show a friendly "+" add button
        if config.items.isEmpty {
            let button = NSButton(frame: NSRect(x: padding, y: padding, width: config.iconSize, height: config.iconSize))
            button.bezelStyle = .regularSquare
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 10
            button.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
            if let plusImg = NSImage(systemSymbolName: "plus", accessibilityDescription: "Uygulama Ekle") {
                button.image = plusImg
                button.imageScaling = .scaleProportionallyDown
                button.contentTintColor = NSColor(white: 1.0, alpha: 0.75)
            } else {
                button.title = "+"
            }
            button.toolTip = "Uygulama sürükleyin veya tıklayarak ekleyin"
            button.target = self
            button.action = #selector(addAppClicked)
            addSubview(button)
            emptyPlaceholderView = button
        } else {
            // Create item view for each dock item
            for item in config.items {
                let itemView = DockItemView(item: item, size: config.iconSize)
                itemView.showRunningIndicator = config.showRunningIndicator
                itemView.delegate = self
                addSubview(itemView)
                itemViews.append(itemView)
            }
        }

        layoutItems()
    }

    func layoutItems() {
        let iconSize = config.iconSize
        let isHorizontal = config.position.isHorizontal
        let count = CGFloat(itemViews.count)

        let totalItemsLength: CGFloat
        if itemViews.isEmpty {
            totalItemsLength = 0
        } else {
            totalItemsLength = count * iconSize + spacing * max(count - 1, 0)
        }

        let totalLength = totalItemsLength + padding * 2
        let thickness = iconSize + padding * 2 + (config.showRunningIndicator ? indicatorHeight : 0)

        let frameWidth: CGFloat
        let frameHeight: CGFloat
        if isHorizontal {
            frameWidth = max(totalLength, padding * 2 + iconSize)
            frameHeight = thickness
        } else {
            frameWidth = thickness
            frameHeight = max(totalLength, padding * 2 + iconSize)
        }

        // Resize self frame
        let oldFrame = frame
        frame = NSRect(x: oldFrame.origin.x, y: oldFrame.origin.y, width: frameWidth, height: frameHeight)

        // Resize and style background (smooth, non-glitching rounded corners)
        backgroundView.frame = bounds
        backgroundView.layer?.cornerRadius = min(22, min(frameWidth, frameHeight) / 2.6)

        if let placeholder = emptyPlaceholderView {
            let s = config.iconSize
            let centeredX = (frameWidth - s) / 2
            let centeredY = (frameHeight - s) / 2
            placeholder.frame = NSRect(x: centeredX, y: centeredY, width: s, height: s)
        }

        // Position each item cleanly without magnification distortion
        var offset: CGFloat = padding
        for itemView in itemViews {
            let size = iconSize
            itemView.baseSize = size
            itemView.currentSize = size

            if isHorizontal {
                let y = padding + (config.showRunningIndicator ? indicatorHeight : 0)
                let centeredY = y + ((thickness - padding * 2 - (config.showRunningIndicator ? indicatorHeight : 0)) - size) / 2
                itemView.frame = NSRect(x: offset, y: centeredY, width: size, height: size + (config.showRunningIndicator ? indicatorHeight : 0))
                offset += size + spacing
            } else {
                let x = padding
                let centeredX = x + ((thickness - padding * 2 - (config.showRunningIndicator ? indicatorHeight : 0)) - size) / 2
                let y = frameHeight - offset - size - (config.showRunningIndicator ? indicatorHeight : 0)
                itemView.frame = NSRect(x: centeredX, y: y, width: size + (config.showRunningIndicator ? indicatorHeight : 0), height: size)
                offset += size + spacing
            }
            itemView.needsDisplay = true
        }
    }

    // MARK: - Scroll Wheel Resizing (Doc Boyutu Ayarlama)

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard abs(delta) > 0.3 else { return }

        // Up: enlarge icons, Down: shrink icons
        let step: CGFloat = delta > 0 ? 2.0 : -2.0
        let newSize = min(max(config.iconSize + step, 28), 120)

        guard newSize != config.iconSize else { return }
        config.iconSize = newSize

        for itemView in itemViews {
            itemView.updateSize(newSize)
        }

        layoutItems()
        delegate?.dockContentViewSizeChanged(newSize)
    }

    // MARK: - Drag & Drop Support

    private func extractAppURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            results.append(contentsOf: urls)
        }

        if results.isEmpty, let paths = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            for path in paths {
                results.append(URL(fileURLWithPath: path))
            }
        }

        return results.compactMap { url -> URL? in
            let standardURL = url.resolvingSymlinksInPath()
            if standardURL.pathExtension.lowercased() == "app" || standardURL.path.hasSuffix(".app") {
                return standardURL
            }
            return nil
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let apps = extractAppURLs(from: sender.draggingPasteboard)
        if !apps.isEmpty {
            backgroundView.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.8).cgColor
            backgroundView.layer?.borderWidth = 1.5
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        backgroundView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        backgroundView.layer?.borderWidth = 0.5
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        backgroundView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        backgroundView.layer?.borderWidth = 0.5

        let appURLs = extractAppURLs(from: sender.draggingPasteboard)
        guard !appURLs.isEmpty else { return false }

        var didAdd = false
        for appURL in appURLs {
            let normalizedPath = appURL.path
            let newItem = DockItem(appPath: normalizedPath)
            if !config.items.contains(where: { $0.appPath == normalizedPath }) {
                config.items.append(newItem)
                didAdd = true
            }
        }

        guard didAdd else { return true }

        rebuildItems()
        delegate?.dockContentViewItemsChanged(config.items)
        return true
    }

    // MARK: - DockItemViewDelegate

    func dockItemClicked(_ item: DockItem) {
        // App launch handled in DockItemView
    }

    func dockItemRemoveRequested(_ item: DockItem) {
        delegate?.dockContentViewRequestsRemoveItem(item)
    }

    // MARK: - Running App Check

    @objc func checkRunningApps() {
        itemViews.forEach { $0.updateRunningState() }
    }

    // MARK: - Right-click on empty area

    override func rightMouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        for itemView in itemViews {
            if itemView.frame.contains(location) {
                itemView.rightMouseDown(with: event)
                return
            }
        }

        let menu = NSMenu()
        let addItem = NSMenuItem(title: "Uygulama Ekle...", action: #selector(addAppClicked), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func addAppClicked() {
        delegate?.dockContentViewRequestsAddApp()
    }
}
