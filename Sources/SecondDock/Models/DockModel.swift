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

// MARK: - DockItemKind

enum DockItemKind: String, Codable {
    case app
    case file
}

// MARK: - DockItem

/// A single item (application shortcut or file shortcut) in a dock
struct DockItem: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var appPath: String
    var filePath: String?
    var bundleIdentifier: String?
    var kind: DockItemKind

    var isFileItem: Bool {
        return kind == .file
    }

    /// Create from an app path, auto-extracting display name and bundle identifier.
    init(appPath: String) {
        self.id = UUID()
        let cleanPath = (appPath as NSString).standardizingPath
        self.appPath = cleanPath
        self.filePath = nil
        self.kind = .app

        let url = URL(fileURLWithPath: cleanPath)
        let baseName = url.deletingPathExtension().lastPathComponent
        self.name = baseName.isEmpty ? url.lastPathComponent : baseName

        if let bundle = Bundle(path: cleanPath),
           let identifier = bundle.bundleIdentifier {
           self.bundleIdentifier = identifier
        } else {
           self.bundleIdentifier = nil
        }
    }

    /// Create from an arbitrary file URL for a quick preview item.
    init(fileURL: URL) {
        self.id = UUID()
        let cleanPath = (fileURL.path as NSString).standardizingPath
        self.appPath = cleanPath
        self.filePath = cleanPath
        self.kind = .file
        self.name = fileURL.lastPathComponent
        self.bundleIdentifier = nil
    }

    /// Explicit memberwise initializer for Codable and testing.
    init(id: UUID = UUID(), name: String, appPath: String, bundleIdentifier: String? = nil, filePath: String? = nil, kind: DockItemKind = .app) {
        self.id = id
        self.name = name
        self.appPath = (appPath as NSString).standardizingPath
        self.filePath = filePath != nil ? (filePath! as NSString).standardizingPath : nil
        self.bundleIdentifier = bundleIdentifier
        self.kind = kind
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
    var backgroundOpacity: Double
    var autoHide: Bool
    var magnification: Bool
    var magnificationSize: CGFloat
    var showRunningIndicator: Bool
    var hideInFullScreen: Bool    // Tam ekranda otomatik gizlenme

    /// Offset from the screen edge in points
    var edgeOffset: CGFloat { return 4.0 }

    enum CodingKeys: String, CodingKey {
        case id, name, screenIndex, position, items, iconSize, backgroundOpacity, autoHide
        case magnification, magnificationSize, showRunningIndicator, hideInFullScreen
    }

    init(
        id: UUID = UUID(),
        name: String = "Yeni Dock",
        screenIndex: Int = 0,
        position: DockPosition = .bottom,
        items: [DockItem] = [],
        iconSize: CGFloat = 48.0,
        backgroundOpacity: Double = 0.35,
        autoHide: Bool = false,
        magnification: Bool = false,
        magnificationSize: CGFloat = 64.0,
        showRunningIndicator: Bool = true,
        hideInFullScreen: Bool = true
    ) {
        self.id = id
        self.name = name
        self.screenIndex = screenIndex
        self.position = position
        self.items = items
        self.iconSize = iconSize
        self.backgroundOpacity = min(max(backgroundOpacity, 0.0), 1.0)
        self.autoHide = autoHide
        self.magnification = magnification
        self.magnificationSize = magnificationSize
        self.showRunningIndicator = showRunningIndicator
        self.hideInFullScreen = hideInFullScreen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Dock"
        screenIndex = try container.decodeIfPresent(Int.self, forKey: .screenIndex) ?? 0
        position = try container.decodeIfPresent(DockPosition.self, forKey: .position) ?? .bottom
        items = try container.decodeIfPresent([DockItem].self, forKey: .items) ?? []
        iconSize = try container.decodeIfPresent(CGFloat.self, forKey: .iconSize) ?? 48.0
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 0.35
        autoHide = try container.decodeIfPresent(Bool.self, forKey: .autoHide) ?? false
        magnification = try container.decodeIfPresent(Bool.self, forKey: .magnification) ?? false
        magnificationSize = try container.decodeIfPresent(CGFloat.self, forKey: .magnificationSize) ?? 64.0
        showRunningIndicator = try container.decodeIfPresent(Bool.self, forKey: .showRunningIndicator) ?? true
        hideInFullScreen = try container.decodeIfPresent(Bool.self, forKey: .hideInFullScreen) ?? true
    }
}
