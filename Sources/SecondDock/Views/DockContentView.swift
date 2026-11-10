import AppKit

protocol DockContentViewDelegate: AnyObject {
    func dockContentViewItemsChanged(_ items: [DockItem])
    func dockContentViewRequestsRemoveItem(_ item: DockItem)
    func dockContentViewRequestsAddApp()
}

class DockContentView: NSView, DockItemViewDelegate {
    var config: DockConfiguration
    weak var delegate: DockContentViewDelegate?

    private var itemViews: [DockItemView] = []
    private var backgroundView: NSVisualEffectView!
    private var trackingArea: NSTrackingArea?
    private var runningCheckTimer: Timer?

    let spacing: CGFloat = 8
    let padding: CGFloat = 12
    let indicatorHeight: CGFloat = 8

    init(config: DockConfiguration) {
        self.config = config
        super.init(frame: .zero)

        wantsLayer = true

        // Set up visual effect background
        backgroundView = NSVisualEffectView()
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 12
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

        // Create new item views
        for item in config.items {
            let itemView = DockItemView(item: item, size: config.iconSize)
            itemView.showRunningIndicator = config.showRunningIndicator
            itemView.delegate = self
            addSubview(itemView)
            itemViews.append(itemView)
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
            totalItemsLength = itemViews.reduce(CGFloat(0)) { $0 + $1.currentSize } + spacing * max(count - 1, 0)
        }

        let totalLength = totalItemsLength + padding * 2
        let thickness = (itemViews.map { $0.currentSize }.max() ?? iconSize) + padding * 2 + (config.showRunningIndicator ? indicatorHeight : 0)

        let frameWidth: CGFloat
        let frameHeight: CGFloat
        if isHorizontal {
            frameWidth = max(totalLength, padding * 2 + iconSize)
            frameHeight = thickness
        } else {
            frameWidth = thickness
            frameHeight = max(totalLength, padding * 2 + iconSize)
        }

        // Resize self
        let oldFrame = frame
        frame = NSRect(x: oldFrame.origin.x, y: oldFrame.origin.y, width: frameWidth, height: frameHeight)

        // Resize background
        backgroundView.frame = bounds

        // Position each item
        var offset: CGFloat = padding
        for itemView in itemViews {
            let size = itemView.currentSize
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

    // MARK: - Magnification

    override func mouseMoved(with event: NSEvent) {
        guard config.magnification else { return }
        let mouseLocation = convert(event.locationInWindow, from: nil)
        applyMagnification(at: mouseLocation)
    }

    override func mouseExited(with event: NSEvent) {
        resetMagnification()
    }

    private func applyMagnification(at point: NSPoint) {
        let isHorizontal = config.position.isHorizontal

        for itemView in itemViews {
            let itemCenter: CGFloat
            let mousePos: CGFloat

            if isHorizontal {
                itemCenter = itemView.frame.midX
                mousePos = point.x
            } else {
                itemCenter = itemView.frame.midY
                mousePos = point.y
            }

            let distance = abs(itemCenter - mousePos)
            let range = config.iconSize * 3
            let factor = max(0, 1 - distance / range)
            // Smooth parabolic curve
            let smoothFactor = factor * factor * (3 - 2 * factor)
            let newSize = config.iconSize + (config.magnificationSize - config.iconSize) * smoothFactor

            itemView.currentSize = newSize
        }

        layoutItems()
    }

    private func resetMagnification() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true

            for itemView in self.itemViews {
                itemView.currentSize = itemView.baseSize
            }
            self.layoutItems()
        }
    }

    // MARK: - Tracking Areas

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        if let area = trackingArea {
            addTrackingArea(area)
        }
    }

    // MARK: - Drag & Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return []
        }

        let hasApps = items.contains { $0.pathExtension == "app" }
        if hasApps {
            backgroundView.material = .selection
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        backgroundView.material = .hudWindow
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        backgroundView.material = .hudWindow

        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return false
        }

        let appURLs = urls.filter { $0.pathExtension == "app" }
        guard !appURLs.isEmpty else { return false }

        var updatedItems = config.items
        for appURL in appURLs {
            let newItem = DockItem(appPath: appURL.path)
            // Avoid duplicates
            if !updatedItems.contains(where: { $0.appPath == appURL.path }) {
                updatedItems.append(newItem)
            }
        }

        delegate?.dockContentViewItemsChanged(updatedItems)
        return true
    }

    // MARK: - DockItemViewDelegate

    func dockItemClicked(_ item: DockItem) {
        // Already handled in item view
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
        // Check if click is on an item view
        let location = convert(event.locationInWindow, from: nil)
        for itemView in itemViews {
            if itemView.frame.contains(location) {
                // Let the item view handle it
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
