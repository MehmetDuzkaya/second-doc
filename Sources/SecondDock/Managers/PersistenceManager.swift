import Foundation

/// Handles saving and loading dock configurations to/from disk as JSON.
class PersistenceManager {
    static let shared = PersistenceManager()

    private init() {}

    /// URL to the configuration file: ~/Library/Application Support/SecondDock/docks.json
    private var configFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("SecondDock", isDirectory: true)
        return folder.appendingPathComponent("docks.json")
    }

    /// Encode dock configurations to JSON and write to disk.
    func saveDocks(_ docks: [DockConfiguration]) {
        ensureDirectoryExists()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(docks)
            try data.write(to: configFileURL, options: .atomic)
        } catch {
            print("[SecondDock] Dock yapılandırmaları kaydedilemedi: \(error.localizedDescription)")
        }
    }

    /// Read from disk and decode JSON into dock configurations. Returns empty array on failure.
    func loadDocks() -> [DockConfiguration] {
        let url = configFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let docks = try JSONDecoder().decode([DockConfiguration].self, from: data)
            return docks
        } catch {
            print("[SecondDock] Dock yapılandırmaları yüklenemedi: \(error.localizedDescription)")
            return []
        }
    }

    /// Ensure the Application Support/SecondDock directory exists.
    private func ensureDirectoryExists() {
        let folder = configFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: folder.path) {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                print("[SecondDock] Dizin oluşturulamadı: \(error.localizedDescription)")
            }
        }
    }
}
