import AppKit

/// Manages monitor detection and dock frame calculations.
class ScreenManager {
    static let shared = ScreenManager()

    private init() {}

    // MARK: - Screen Enumeration

    /// Get all available screens with descriptive Turkish names.
    /// Returns tuples like (0, "Dahili Ekran (1920×1080)", NSScreen).
    func availableScreens() -> [(index: Int, name: String, screen: NSScreen)] {
        return NSScreen.screens.enumerated().map { index, screen in
            let width = Int(screen.frame.width)
            let height = Int(screen.frame.height)
            let baseName = screen.localizedName
            let displayName = "\(baseName) (\(width)×\(height))"
            return (index: index, name: displayName, screen: screen)
        }
    }

    /// Get NSScreen for a given index, falling back to the main screen.
    func screen(at index: Int) -> NSScreen {
        let screens = NSScreen.screens
        if index >= 0, index < screens.count {
            return screens[index]
        }
        return NSScreen.main ?? screens[0]
    }

    // MARK: - Frame Calculation

    /// Spacing between icons in points.
    private let itemSpacing: CGFloat = 8.0
    /// Padding on the edges of the dock in points.
    private let edgePadding: CGFloat = 12.0
    /// Extra space for running-app indicator dots below icons.
    private let indicatorSpace: CGFloat = 6.0

    /// Calculate the window frame for a dock on a given screen edge.
    ///
    /// The dock is centered on the chosen edge and sized to fit all items
    /// with spacing and padding.
    func dockFrame(for config: DockConfiguration, itemCount: Int) -> NSRect {
        let screen = self.screen(at: config.screenIndex)
        let visibleFrame = screen.visibleFrame
        let iconSize = config.iconSize
        let offset = config.edgeOffset
        let count = CGFloat(max(itemCount, 1))

        if config.position.isHorizontal {
            // Horizontal dock (bottom / top)
            let dockWidth  = count * (iconSize + itemSpacing) - itemSpacing + edgePadding * 2
            let dockHeight = iconSize + edgePadding * 2 + indicatorSpace

            let x = visibleFrame.midX - dockWidth / 2

            let y: CGFloat
            switch config.position {
            case .bottom:
                y = visibleFrame.minY + offset
            case .top:
                y = visibleFrame.maxY - dockHeight - offset
            default:
                y = visibleFrame.minY + offset
            }

            return NSRect(x: x, y: y, width: dockWidth, height: dockHeight)
        } else {
            // Vertical dock (left / right)
            let dockWidth  = iconSize + edgePadding * 2 + indicatorSpace
            let dockHeight = count * (iconSize + itemSpacing) - itemSpacing + edgePadding * 2

            let y = visibleFrame.midY - dockHeight / 2

            let x: CGFloat
            switch config.position {
            case .left:
                x = visibleFrame.minX + offset
            case .right:
                x = visibleFrame.maxX - dockWidth - offset
            default:
                x = visibleFrame.minX + offset
            }

            return NSRect(x: x, y: y, width: dockWidth, height: dockHeight)
        }
    }
}
