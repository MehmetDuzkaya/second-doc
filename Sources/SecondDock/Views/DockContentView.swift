import AppKit

protocol DockContentViewDelegate: AnyObject {
    func dockContentViewItemsChanged(_ items: [DockItem])
    func dockContentViewSizeChanged(_ size: CGFloat)
    func dockContentViewRequestsRemoveItem(_ item: DockItem)
    func dockContentViewRequestsAddApp()
    func dockContentViewRequestsToggleVisibility()
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
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 18
        backgroundView.layer?.borderWidth = 0.5
        backgroundView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
        backgroundView.layer?.masksToBounds = true
        backgroundView.alphaValue = CGFloat(config.backgroundOpacity)
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
        for view in itemViews {
            view.removeFromSuperview()
        }
        itemViews.removeAll()

        emptyPlaceholderView?.removeFromSuperview()
        emptyPlaceholderView = nil

        let appItems = config.items.filter { $0.kind == .app }

        if appItems.isEmpty {
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
            for item in appItems {
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
        let appCount = CGFloat(itemViews.count)

        let appLength: CGFloat
        if itemViews.isEmpty {
            appLength = 0
        } else {
            let appSpacing = CGFloat(max(Int(appCount) - 1, 0)) * spacing
            appLength = appCount * iconSize + appSpacing
        }

        let totalItemsLength = appLength
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

        let oldFrame = frame
        frame = NSRect(x: oldFrame.origin.x, y: oldFrame.origin.y, width: frameWidth, height: frameHeight)

        backgroundView.frame = bounds
        backgroundView.alphaValue = CGFloat(config.backgroundOpacity)

        let backgroundRadius: CGFloat = min(24, min(frameWidth, frameHeight) / 2.3)

        backgroundView.layer?.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
        backgroundView.layer?.cornerCurve = .continuous
        backgroundView.layer?.cornerRadius = backgroundRadius

        if let placeholder = emptyPlaceholderView {
            let s = config.iconSize
            let centeredX = (frameWidth - s) / 2
            let centeredY = (frameHeight - s) / 2
            placeholder.frame = NSRect(x: centeredX, y: centeredY, width: s, height: s)
        }

        var offset: CGFloat = padding
        for itemView in itemViews {
            let size = iconSize
            itemView.baseSize = size
            itemView.currentSize = size

            if isHorizontal {
                let itemHeight = size + (config.showRunningIndicator ? indicatorHeight : 0)
                let centeredY = padding + (thickness - padding * 2 - itemHeight) / 2
                itemView.frame = NSRect(x: offset, y: centeredY, width: size, height: size + (config.showRunningIndicator ? indicatorHeight : 0))
                offset += size + spacing
            } else {
                let itemWidth = size + (config.showRunningIndicator ? indicatorHeight : 0)
                let centeredX = padding + (thickness - padding * 2 - itemWidth) / 2
                let y = frameHeight - offset - size
                itemView.frame = NSRect(x: centeredX, y: y, width: itemWidth, height: size)
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

    private func extractDropURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            results.append(contentsOf: urls)
        }

        if results.isEmpty, let paths = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            for path in paths {
                results.append(URL(fileURLWithPath: path))
            }
        }

        return results.map { $0.resolvingSymlinksInPath() }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = extractDropURLs(from: sender.draggingPasteboard)
        if !urls.isEmpty {
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

        let urls = extractDropURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }

        var didAdd = false
        for url in urls {
            let normalizedPath = url.path
            guard normalizedPath.hasSuffix(".app") || url.pathExtension.lowercased() == "app" else {
                continue
            }
            let newItem = DockItem(appPath: normalizedPath)

            let existing = config.items.contains {
                if $0.kind == .file {
                    return ($0.filePath ?? $0.appPath) == (newItem.filePath ?? newItem.appPath)
                }
                return $0.appPath == newItem.appPath
            }

            if !existing {
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

        let visibilityTitle = self.window?.isVisible == true ? "Dock'u Gizle" : "Dock'u Göster"
        let visibilityItem = NSMenuItem(title: visibilityTitle, action: #selector(toggleVisibilityClicked), keyEquivalent: "")
        visibilityItem.target = self
        menu.addItem(visibilityItem)

        menu.addItem(.separator())

        let addItem = NSMenuItem(title: "Uygulama Ekle...", action: #selector(addAppClicked), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func addAppClicked() {
        delegate?.dockContentViewRequestsAddApp()
    }

    @objc func toggleVisibilityClicked() {
        delegate?.dockContentViewRequestsToggleVisibility()
    }
}
