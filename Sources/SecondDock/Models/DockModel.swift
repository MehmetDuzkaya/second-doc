import Foundation
import AppKit

// MARK: - DockPosition

/// Position of a dock on a screen edge
enum DockPosition: String, Codable, CaseIterable {
    case bottom, top, left, right

    /// Turkish display name for UI
    var displayName: String {
        switch self {
        case .bottom: return "Alt"
        case .top:    return "Üst"
        case .left:   return "Sol"
        case .right:  return "Sağ"
        }
    }

    /// Whether the dock lays out horizontally
    var isHorizontal: Bool {
        return self == .bottom || self == .top
    }
}

// MARK: - DockItem

/// A single item (app shortcut) in a dock
struct DockItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var appPath: String
    var bundleIdentifier: String?

    /// Create from an app path, auto-extracting display name and bundle identifier.
    init(appPath: String) {
        self.id = UUID()
        self.appPath = appPath

        // Extract display name from path: "/Applications/Safari.app" -> "Safari"
        let url = URL(fileURLWithPath: appPath)
        self.name = url.deletingPathExtension().lastPathComponent

        // Try to read bundle identifier from the app bundle
        if let bundle = Bundle(path: appPath),
           let identifier = bundle.bundleIdentifier {
            self.bundleIdentifier = identifier
        } else {
            self.bundleIdentifier = nil
        }
    }

    /// Explicit memberwise initializer for Codable and testing
    init(id: UUID = UUID(), name: String, appPath: String, bundleIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
    }
}

// MARK: - DockConfiguration

/// Configuration for one dock instance
struct DockConfiguration: Codable, Identifiable {
    var id: UUID
    var name: String              // User-given name, e.g. "İş Araçları"
    var screenIndex: Int          // Which monitor (0-based)
    var position: DockPosition
    var items: [DockItem]
    var iconSize: CGFloat
    var autoHide: Bool
    var magnification: Bool
    var magnificationSize: CGFloat
    var showRunningIndicator: Bool

    /// Offset from the screen edge in points
    var edgeOffset: CGFloat { return 4.0 }

    init(
        id: UUID = UUID(),
        name: String = "Yeni Dock",
        screenIndex: Int = 0,
        position: DockPosition = .bottom,
        items: [DockItem] = [],
        iconSize: CGFloat = 48.0,
        autoHide: Bool = false,
        magnification: Bool = true,
        magnificationSize: CGFloat = 64.0,
        showRunningIndicator: Bool = true
    ) {
        self.id = id
        self.name = name
        self.screenIndex = screenIndex
        self.position = position
        self.items = items
        self.iconSize = iconSize
        self.autoHide = autoHide
        self.magnification = magnification
        self.magnificationSize = magnificationSize
        self.showRunningIndicator = showRunningIndicator
    }
}
