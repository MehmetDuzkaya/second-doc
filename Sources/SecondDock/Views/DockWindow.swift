import AppKit

protocol DockWindowDelegate: AnyObject {
    func dockWindowItemsDidChange(_ window: DockWindow, items: [DockItem])
    func dockWindowSizeDidChange(_ window: DockWindow, size: CGFloat)
    func dockWindowRequestsRemoveItem(_ window: DockWindow, item: DockItem)
    func dockWindowRequestsAddApp(_ window: DockWindow)
    func dockWindowRequestsSettings(_ window: DockWindow)
    func dockWindowRequestsToggleVisibility(_ window: DockWindow)
}

class DockWindow: NSPanel, DockContentViewDelegate {
    var config: DockConfiguration
    var contentDockView: DockContentView!
    weak var dockDelegate: DockWindowDelegate?

    private var hideTimer: Timer?
    private var edgeTrackingArea: NSTrackingArea?
    private var isAutoHidden: Bool = false
    private var isFullScreenHidden: Bool = false

    init(config: DockConfiguration) {
        self.config = config

        let initialFrame = ScreenManager.shared.dockFrame(for: config, itemCount: max(config.items.filter { $0.kind == .app }.count, 1))

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        updateCollectionBehavior()
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Create dock content view
        contentDockView = DockContentView(config: config)
        contentDockView.delegate = self
        contentDockView.frame = NSRect(origin: .zero, size: initialFrame.size)
        contentView = contentDockView

        positionOnScreen()
        setupAutoHide()

        // Observe active space / full screen changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceOrScreenChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpaceOrScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        hideTimer?.invalidate()
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ newConfig: DockConfiguration) {
        config = newConfig
        contentDockView.config = newConfig
        contentDockView.rebuildItems()
        updateCollectionBehavior()
        positionOnScreen()
        setupAutoHide()
        handleSpaceOrScreenChange()
    }

    private func updateCollectionBehavior() {
        if config.hideInFullScreen {
            // Excludes fullScreenAuxiliary so macOS automatically hides the window on full-screen spaces
            collectionBehavior = [.canJoinAllSpaces, .stationary]
        } else {
            collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        }
    }

    func positionOnScreen() {
        let frame = ScreenManager.shared.dockFrame(for: config, itemCount: max(config.items.filter { $0.kind == .app }.count, 1))
        setFrame(frame, display: true, animate: true)
        contentDockView.frame = NSRect(origin: .zero, size: frame.size)
    }

    // MARK: - Full Screen Detection

    @objc private func handleSpaceOrScreenChange() {
        guard config.hideInFullScreen else {
            if isFullScreenHidden {
                isFullScreenHidden = false
                animator().alphaValue = isAutoHidden ? 0.3 : 1.0
            }
            return
        }

        let targetScreen = ScreenManager.shared.screen(at: config.screenIndex)
        // When a screen is in native full-screen mode, the menu bar is hidden,
        // so visibleFrame matches screen.frame.
        let isFullScreen = (targetScreen.visibleFrame.size == targetScreen.frame.size)

        if isFullScreen {
            isFullScreenHidden = true
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self.animator().alphaValue = 0.0
            }
        } else if isFullScreenHidden {
            isFullScreenHidden = false
            positionOnScreen()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self.animator().alphaValue = self.isAutoHidden ? 0.3 : 1.0
            }
        }
    }

    // MARK: - Auto-hide

    func setupAutoHide() {
        hideTimer?.invalidate()
        hideTimer = nil

        if let existing = edgeTrackingArea, let cv = contentView {
            cv.removeTrackingArea(existing)
            edgeTrackingArea = nil
        }

        guard config.autoHide else {
            if isAutoHidden {
                animateShow()
            }
            return
        }

        if let cv = contentView {
            let area = NSTrackingArea(
                rect: cv.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: ["autoHide": true]
            )
            cv.addTrackingArea(area)
            edgeTrackingArea = area
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard let info = event.trackingArea?.userInfo as? [String: Any],
              info["autoHide"] != nil else {
            super.mouseEntered(with: event)
            return
        }

        hideTimer?.invalidate()
        hideTimer = nil

        if isAutoHidden && !isFullScreenHidden {
            animateShow()
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard let info = event.trackingArea?.userInfo as? [String: Any],
              info["autoHide"] != nil else {
            super.mouseExited(with: event)
            return
        }

        guard config.autoHide && !isFullScreenHidden else { return }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.animateHide()
        }
    }

    private func animateHide() {
        guard !isFullScreenHidden else { return }
        isAutoHidden = true
        let currentFrame = frame
        var hiddenFrame = currentFrame
        let visibleStrip: CGFloat = 4

        switch config.position {
        case .bottom:
            hiddenFrame.origin.y = currentFrame.origin.y - currentFrame.height + visibleStrip
        case .top:
            hiddenFrame.origin.y = currentFrame.origin.y + currentFrame.height - visibleStrip
        case .left:
            hiddenFrame.origin.x = currentFrame.origin.x - currentFrame.width + visibleStrip
        case .right:
            hiddenFrame.origin.x = currentFrame.origin.x + currentFrame.width - visibleStrip
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(hiddenFrame, display: true)
            self.animator().alphaValue = 0.3
        }
    }

    private func animateShow() {
        isAutoHidden = false
        let targetFrame = ScreenManager.shared.dockFrame(for: config, itemCount: max(config.items.filter { $0.kind == .app }.count, 1))

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 1.0
        }
    }

    // MARK: - Window Behavior

    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }

    // MARK: - DockContentViewDelegate

    func dockContentViewItemsChanged(_ items: [DockItem]) {
        config.items = items
        contentDockView.config = config
        positionOnScreen()
        dockDelegate?.dockWindowItemsDidChange(self, items: items)
    }

    func dockContentViewSizeChanged(_ size: CGFloat) {
        config.iconSize = size
        positionOnScreen()
        dockDelegate?.dockWindowSizeDidChange(self, size: size)
    }

    func dockContentViewRequestsRemoveItem(_ item: DockItem) {
        dockDelegate?.dockWindowRequestsRemoveItem(self, item: item)
    }

    func dockContentViewRequestsAddApp() {
        dockDelegate?.dockWindowRequestsAddApp(self)
    }

    func dockContentViewRequestsToggleVisibility() {
        dockDelegate?.dockWindowRequestsToggleVisibility(self)
    }
}
