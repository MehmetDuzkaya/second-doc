import AppKit

protocol DockSettingsDelegate: AnyObject {
    func dockSettingsDidSave(_ config: DockConfiguration, isNew: Bool)
    func dockSettingsDidCancel()
    func dockSettingsDidDelete(_ config: DockConfiguration)
}

class DockSettingsWindow: NSWindow {
    weak var settingsDelegate: DockSettingsDelegate?
    var config: DockConfiguration
    var isNewDock: Bool

    // UI Elements
    private var nameField: NSTextField!
    private var screenPopup: NSPopUpButton!
    private var positionPopup: NSPopUpButton!
    private var iconSizeSlider: NSSlider!
    private var iconSizeLabel: NSTextField!
    private var autoHideCheckbox: NSButton!
    private var magnificationCheckbox: NSButton!
    private var magnificationSlider: NSSlider!
    private var magnificationSizeLabel: NSTextField!
    private var runningIndicatorCheckbox: NSButton!

    init(config: DockConfiguration?, isNew: Bool) {
        self.isNewDock = isNew

        if let config = config {
            self.config = config
        } else {
            self.config = DockConfiguration(
                id: UUID(),
                name: "",
                screenIndex: 0,
                position: .bottom,
                items: [],
                iconSize: 48,
                autoHide: false,
                magnification: true,
                magnificationSize: 64,
                showRunningIndicator: true
            )
        }

        let windowRect = NSRect(x: 0, y: 0, width: 420, height: 520)
        super.init(
            contentRect: windowRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        title = isNew ? "Yeni Dock" : "Dock Ayarları"
        isReleasedWhenClosed = false
        center()

        buildUI()
        populateFromConfig()
    }

    private func buildUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 520))
        contentView = container

        var y: CGFloat = 470
        let leftMargin: CGFloat = 20
        let rightMargin: CGFloat = 20
        let fieldWidth: CGFloat = 420 - leftMargin - rightMargin
        let labelHeight: CGFloat = 17
        let fieldHeight: CGFloat = 24
        let rowSpacing: CGFloat = 12

        // Dock Name
        let nameLabel = makeLabel("Dock İsmi:", frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: labelHeight))
        container.addSubview(nameLabel)
        y -= fieldHeight + 4
        nameField = NSTextField(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: fieldHeight))
        nameField.placeholderString = "Örn: İş Araçları"
        container.addSubview(nameField)
        y -= rowSpacing + labelHeight

        // Monitor
        let screenLabel = makeLabel("Monitör:", frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: labelHeight))
        container.addSubview(screenLabel)
        y -= fieldHeight + 4
        screenPopup = NSPopUpButton(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: fieldHeight), pullsDown: false)
        let screens = ScreenManager.shared.availableScreens()
        for screen in screens {
            screenPopup.addItem(withTitle: screen.name)
        }
        container.addSubview(screenPopup)
        y -= rowSpacing + labelHeight

        // Position
        let posLabel = makeLabel("Konum:", frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: labelHeight))
        container.addSubview(posLabel)
        y -= fieldHeight + 4
        positionPopup = NSPopUpButton(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: fieldHeight), pullsDown: false)
        positionPopup.addItem(withTitle: "Alt")
        positionPopup.addItem(withTitle: "Üst")
        positionPopup.addItem(withTitle: "Sol")
        positionPopup.addItem(withTitle: "Sağ")
        container.addSubview(positionPopup)
        y -= rowSpacing + labelHeight

        // Icon Size
        let iconLabel = makeLabel("İkon Boyutu:", frame: NSRect(x: leftMargin, y: y, width: 100, height: labelHeight))
        container.addSubview(iconLabel)
        iconSizeLabel = makeLabel("48", frame: NSRect(x: leftMargin + fieldWidth - 40, y: y, width: 40, height: labelHeight))
        iconSizeLabel.alignment = .right
        container.addSubview(iconSizeLabel)
        y -= fieldHeight + 4
        iconSizeSlider = NSSlider(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: fieldHeight))
        iconSizeSlider.minValue = 32
        iconSizeSlider.maxValue = 96
        iconSizeSlider.doubleValue = 48
        iconSizeSlider.isContinuous = true
        iconSizeSlider.target = self
        iconSizeSlider.action = #selector(iconSizeSliderChanged(_:))
        container.addSubview(iconSizeSlider)
        y -= rowSpacing + 8

        // Auto-hide
        autoHideCheckbox = NSButton(checkboxWithTitle: "Otomatik Gizle", target: nil, action: nil)
        autoHideCheckbox.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        container.addSubview(autoHideCheckbox)
        y -= rowSpacing + 8

        // Magnification
        magnificationCheckbox = NSButton(checkboxWithTitle: "Büyütme Efekti", target: self, action: #selector(magnificationToggled(_:)))
        magnificationCheckbox.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        container.addSubview(magnificationCheckbox)
        y -= rowSpacing + labelHeight

        // Magnification Size
        let magSizeLabel = makeLabel("Büyütme Boyutu:", frame: NSRect(x: leftMargin, y: y, width: 120, height: labelHeight))
        container.addSubview(magSizeLabel)
        magnificationSizeLabel = makeLabel("64", frame: NSRect(x: leftMargin + fieldWidth - 40, y: y, width: 40, height: labelHeight))
        magnificationSizeLabel.alignment = .right
        container.addSubview(magnificationSizeLabel)
        y -= fieldHeight + 4
        magnificationSlider = NSSlider(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: fieldHeight))
        magnificationSlider.minValue = 48
        magnificationSlider.maxValue = 128
        magnificationSlider.doubleValue = 64
        magnificationSlider.isContinuous = true
        magnificationSlider.target = self
        magnificationSlider.action = #selector(magnificationSliderChanged(_:))
        container.addSubview(magnificationSlider)
        y -= rowSpacing + 8

        // Running indicator
        runningIndicatorCheckbox = NSButton(checkboxWithTitle: "Çalışan Uygulama Göstergesi", target: nil, action: nil)
        runningIndicatorCheckbox.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        container.addSubview(runningIndicatorCheckbox)
        y -= rowSpacing + 20

        // Separator
        let separator = NSBox(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 1))
        separator.boxType = .separator
        container.addSubview(separator)
        y -= rowSpacing + 8

        // Buttons row
        let buttonY = y - 30

        // Save button (right side)
        let saveButton = NSButton(frame: NSRect(x: 420 - rightMargin - 80, y: buttonY, width: 80, height: 32))
        saveButton.title = "Kaydet"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        container.addSubview(saveButton)

        // Cancel button
        let cancelButton = NSButton(frame: NSRect(x: 420 - rightMargin - 80 - 10 - 80, y: buttonY, width: 80, height: 32))
        cancelButton.title = "İptal"
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        container.addSubview(cancelButton)

        // Delete button (left side, only for existing docks)
        if !isNewDock {
            let deleteButton = NSButton(frame: NSRect(x: leftMargin, y: buttonY, width: 80, height: 32))
            deleteButton.title = "Sil"
            deleteButton.bezelStyle = .rounded
            deleteButton.contentTintColor = .systemRed
            deleteButton.target = self
            deleteButton.action = #selector(deleteClicked)
            container.addSubview(deleteButton)
        }
    }

    private func populateFromConfig() {
        nameField.stringValue = config.name

        let screens = ScreenManager.shared.availableScreens()
        if config.screenIndex < screens.count {
            screenPopup.selectItem(at: config.screenIndex)
        }

        let positionIndex: Int
        switch config.position {
        case .bottom: positionIndex = 0
        case .top: positionIndex = 1
        case .left: positionIndex = 2
        case .right: positionIndex = 3
        }
        positionPopup.selectItem(at: positionIndex)

        iconSizeSlider.doubleValue = Double(config.iconSize)
        iconSizeLabel.stringValue = "\(Int(config.iconSize))"

        autoHideCheckbox.state = config.autoHide ? .on : .off

        magnificationCheckbox.state = config.magnification ? .on : .off
        magnificationSlider.doubleValue = Double(config.magnificationSize)
        magnificationSlider.isEnabled = config.magnification
        magnificationSizeLabel.stringValue = "\(Int(config.magnificationSize))"

        runningIndicatorCheckbox.state = config.showRunningIndicator ? .on : .off
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    // MARK: - Actions

    @objc func saveClicked() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Hata"
            alert.informativeText = "Dock ismi boş olamaz."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Tamam")
            alert.runModal()
            return
        }

        config.name = name
        config.screenIndex = screenPopup.indexOfSelectedItem

        let positions: [DockPosition] = [.bottom, .top, .left, .right]
        config.position = positions[positionPopup.indexOfSelectedItem]

        config.iconSize = CGFloat(iconSizeSlider.integerValue)
        config.autoHide = autoHideCheckbox.state == .on
        config.magnification = magnificationCheckbox.state == .on
        config.magnificationSize = CGFloat(magnificationSlider.integerValue)
        config.showRunningIndicator = runningIndicatorCheckbox.state == .on

        settingsDelegate?.dockSettingsDidSave(config, isNew: isNewDock)
        close()
    }

    @objc func cancelClicked() {
        settingsDelegate?.dockSettingsDidCancel()
        close()
    }

    @objc func deleteClicked() {
        let alert = NSAlert()
        alert.messageText = "Dock'u Sil"
        alert.informativeText = "\"\(config.name)\" dock'unu silmek istediğinize emin misiniz? Bu işlem geri alınamaz."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Sil")
        alert.addButton(withTitle: "İptal")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            settingsDelegate?.dockSettingsDidDelete(config)
            close()
        }
    }

    @objc func iconSizeSliderChanged(_ sender: NSSlider) {
        iconSizeLabel.stringValue = "\(sender.integerValue)"
    }

    @objc func magnificationSliderChanged(_ sender: NSSlider) {
        magnificationSizeLabel.stringValue = "\(sender.integerValue)"
    }

    @objc func magnificationToggled(_ sender: NSButton) {
        magnificationSlider.isEnabled = sender.state == .on
    }
}
