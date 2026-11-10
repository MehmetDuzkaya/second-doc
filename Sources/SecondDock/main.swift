import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // Status bar app, no dock icon

let delegate = AppDelegate()
app.delegate = delegate
app.run()
