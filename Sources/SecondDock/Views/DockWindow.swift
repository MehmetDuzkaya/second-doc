import AppKit

protocol DockWindowDelegate: AnyObject {
    func dockWindowItemsDidChange(_ window: DockWindow, items: [DockItem])
    func dockWindowRequestsRemoveItem(_ window: DockWindow, item: DockItem)
    func dockWindowRequestsAddApp(_ window: DockWindow)
    func dockWindowRequestsSettings(_ window: DockWindow)
}

class DockWindow: NSPanel, DockContentViewDelegate {
    var config: DockConfiguration
    var contentDockView: DockContentView!
    weak var dockDelegate: DockWindowDelegate?

    private var hideTimer: Timer?
    private var edgeTrackingArea: NSTrackingArea?
    private var isAutoHidden: Bool = false

    init(config: DockConfiguration) {
        self.config = config

        let initialFrame = ScreenManager.shared.dockFrame(for: config, itemCount: max(config.items.count, 1))

        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
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
    }

    // MARK: - Configuration Update

    func updateConfiguration(_ newConfig: DockConfiguration) {
        config = newConfig
        contentDockView.config = newConfig
        contentDockView.rebuildItems()
        positionOnScreen()
        setupAutoHide()
    }

    func positionOnScreen() {
        let frame = ScreenManager.shared.dockFrame(for: config, itemCount: max(config.items.count, 1))
        setFrame(frame, display: true, animate: true)
        contentDockView.frame = NSRect(origin: .zero, size: frame.size)
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

        // Set up tracking area on the content view to detect mouse enter/exit
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

        if isAutoHidden {
            animateShow()
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard let info = event.trackingArea?.userInfo as? [String: Any],
              info["autoHide"] != nil else {
            super.mouseExited(with: event)
            return
        }

        guard config.autoHide else { return }

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.animateHide()
        }
    }

    private func animateHide() {
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
        let targetFrame = ScreenManager.shared.dockFrame(for: config, itemCount: max(config.items.count, 1))

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
        dockDelegate?.dockWindowItemsDidChange(self, items: items)
    }

    func dockContentViewRequestsRemoveItem(_ item: DockItem) {
        dockDelegate?.dockWindowRequestsRemoveItem(self, item: item)
    }

    func dockContentViewRequestsAddApp() {
        dockDelegate?.dockWindowRequestsAddApp(self)
    }
}
