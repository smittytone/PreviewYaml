//
//  AppDelegateSettings.swift
//  PreviewYaml
//
//  Created by Tony Smith on 10/04/2026.
//

import AppKit


extension AppDelegate {

    // MARK: - Operational Functions


    /**
     Update UI when we are about to switch to it.

     // FROM 2.0.0
     */
    internal func willShowSettingsPage() {

        // Fix track colour on macOS 26
        if #available(macOS 26.0, *) {
            self.fontSizeSlider.tintProminence = .none
        }

        // FROM 2.0.0
        // Disable this switch below 26.1
        if #available(macOS 26.1, *) {
            self.tintTumbnailsAdvancedLabel.isEnabled = true
            self.tintTumbnailsAdvancedSwitch.isEnabled = true
        } else {
            self.tintTumbnailsAdvancedLabel.isEnabled = false
            self.tintTumbnailsAdvancedSwitch.isEnabled = false
        }

        // Disable the Feedback > Send button if we have sent a message.
        // It will be re-enabled by typing something
        self.applyButton.isEnabled = checkSettings()

        // Applied to enable keyboard control of the slider
        self.window.makeFirstResponder(self)
    }


    // MARK: - User Action Functions

    /**
     When the font size slider is moved and released, this function updates the font size readout.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    private func doMoveSlider(sender: Any) {

        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[index]))pt"
        self.applyButton.isEnabled = checkSettings()
    }


    override func keyDown(with event: NSEvent) {

        // Use the cursor keys to adjust the slider

        if (event.keyCode == 126 || event.keyCode == 124) && self.fontSizeSlider.floatValue < 6.0 {
            self.fontSizeSlider.floatValue += 1
            if self.fontSizeSlider.floatValue > 6.0 {
                self.fontSizeSlider.floatValue = 6.0
            }

            doMoveSlider(sender: self)
        }

        if (event.keyCode == 125 || event.keyCode == 123) && self.fontSizeSlider.floatValue > 0.0 {
            self.fontSizeSlider.floatValue -= 1
            if self.fontSizeSlider.floatValue < 0.0 {
                self.fontSizeSlider.floatValue = 0.0
            }

            doMoveSlider(sender: self)
        }
    }


    /**
     Called when the user selects a font from either list.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    private func doUpdateFonts(sender: Any) {

        setStylePopup()
        self.applyButton.isEnabled = checkSettings()
    }


    /**
     Update the colour preferences dictionary with a value from the
     colour well when a colour is chosen.

     - Parameters:
        - sender: The source of the action.
     */
    @objc
    @IBAction
    private func colourSelected(sender: Any) {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        let key: String = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
        self.currentSettings.displayColours[key] = self.colourWell.color.hexString
        self.applyButton.isEnabled = checkSettings()
    }


    /**
     Update the colour well with the stored colour: either a new one, previously
     chosen, or the loaded preference.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doChooseColourType(sender: Any) {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        let key: String = keys[self.colourSelectionPopup.indexOfSelectedItem]

        // If there's no `new_xxx` key, the next line will evaluate to false
        if let colour: String = self.currentSettings.displayColours["new_" + key] {
            if colour.count != 0 {
                // Set the colourwell with the updated colour and exit
                self.colourWell.color = NSColor.hexToColour(colour)
                self.applyButton.isEnabled = checkSettings()
                return
            }
        }

        // Set the colourwell with the stored colour
        if let colour: String = self.currentSettings.displayColours[key] {
            self.colourWell.color = NSColor.hexToColour(colour)
        }

        self.applyButton.isEnabled = checkSettings()
    }


    /**
     Handler for controls whose values are read on save.

     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doChangeValue(sender: Any) {

        self.applyButton.isEnabled = checkSettings()
    }


    /**
     The user has clicked on the `Apply` button.

     FROM 2.0.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doApplyCurrentSettings(sender: Any) {

         // First, make sure changes have been made
         if checkSettings() {
             // Changes are present, so save them.
             // NOTE This call updates the current settings values from the Settings tab UI.
             saveSettings()
             willShowSettingsPage()
         }
    }


    /**
     The user has clicked on the `Defaults` button.

     NOTE This does not save the settings, it only updates Settings tab UI state.

     FROM 2.0.0

     - Parameters:
         - sender: The source of the action.
      */
    @IBAction
    internal func doApplyDefaultSettings(sender: Any) {

        displaySettings(self.defaultSettings)
        applyDefaultColours()
        self.applyButton.isEnabled = checkSettings()
     }


    // MARK: - Advanced Settings

    @IBAction
    internal func doShowAdvancedSettings(sender: Any) {

        self.window.beginSheet(self.advancedSettingsSheet)
    }


    @IBAction
    internal func doCloseAdvancedSettings(sender: Any) {

        self.window.endSheet(self.advancedSettingsSheet)
        willShowSettingsPage()
    }


    // MARK: - Data Access/Storage Functions

    /**
     Update the UI with the supplied settings.

     FROM 2.0.0

     - Parameters:
        - settings: An instance holding the settings to show in the UI.
     */
    internal func displaySettings(_ settings: PYSettings) {

        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        let index: Int = BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.lastIndex(of: settings.fontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[index]))pt"

        // Extend font selection to all available fonts
        // First, the body text font...
        self.fontPopup.removeAllItems()
        self.stylePopup.isEnabled = false

        for i: Int in 0..<self.fonts.count {
            let font: PMFont = self.fonts[i]
            self.fontPopup.addItem(withTitle: font.displayName)
        }

        self.fontPopup.selectItem(withTitle: "")
        selectFontByPostScriptName(settings.fontName)

        // Set the colour well
        // NOTE This has only one colour, so we always reset to "heads" on changes
        self.colourWell.color = NSColor.hexToColour(settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.KEYS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.KEYS)
        self.colourSelectionPopup.selectItem(at: 0)
        self.clearNewColours()

        // Set the switches
        self.useLightSwitch.state = settings.doReverseMode ? .on : .off
        self.showYamlMarksSwitch.state = settings.showYamlMarks ? .on : .off
        self.showBadYamlSwitch.state = settings.showRawYamlOnError ? .on : .off
        self.doIndentScalarsSwitch.state = settings.doIndentScalars ? .on : .off

        // Set the indent size popup
        let indents: [Int] = [1, 2, 4, 8]
        self.indentPopup.selectItem(at: indents.firstIndex(of: settings.indentSize) ?? 1)

        // Tahoe match thumbnail style
        self.tintTumbnailsAdvancedSwitch.state = settings.thumbnailMatchFinderMode ? .on : .off

        // Preview window size
        var idx = 2
        if settings.previewWindowScale == BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_S {
            idx = 0
        } else if settings.previewWindowScale == BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_M {
            idx = 1
        }

        self.previewSizeAdvancedPopup.selectItem(at: idx)

        // Preview margin size
        self.previewMarginSizeText.stringValue = String(format:"%.1f", settings.previewMarginWidth)
    }


    /**
     Generate a set of settings derived from the state of the UI - except for the colour values,
     as these are stored directly in the current settings store. THIS WILL CHANGE

     FROM 2.0.0

     - Returns A settings instance.
     */
    internal func settingsFromDisplay() -> PYSettings {

        let displayedSettings = PYSettings()
        displayedSettings.fontSize = BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
        displayedSettings.fontName = getPostScriptName() ?? BUFFOON_CONSTANTS.BODY_FONT_NAME

        displayedSettings.doReverseMode = self.useLightSwitch.state == .on
        displayedSettings.showYamlMarks = self.showYamlMarksSwitch.state == .on
        displayedSettings.showRawYamlOnError = self.showBadYamlSwitch.state == .on
        displayedSettings.doIndentScalars = self.doIndentScalarsSwitch.state == .on
        displayedSettings.thumbnailMatchFinderMode = self.tintTumbnailsAdvancedSwitch.state == .on

        let indents: [Int] = [1, 2, 4, 8]
        displayedSettings.indentSize = indents[self.indentPopup.indexOfSelectedItem]

        let idx = self.previewSizeAdvancedPopup.indexOfSelectedItem
        switch idx {
            case 1:
                displayedSettings.previewWindowScale = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_M
            case 2:
                displayedSettings.previewWindowScale = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_L
            default:
                displayedSettings.previewWindowScale = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_S
        }

        displayedSettings.previewMarginWidth = Double(self.previewMarginSizeText.stringValue) ?? BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH

        return displayedSettings
    }

    /**
     Populate the current settings value with those read from disk.
     */
    internal func loadSettings() {

        // Get the settings
        self.currentSettings.loadSettings(self.appSuiteName)

        // Use the loaded settings to update the Settings tab UI
        displaySettings(self.currentSettings)
    }


    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store
     */
    internal func saveSettings() {

        // Update the current settings store with values from the UI
        // NOTE We need to preserve the `displayColours` values, so copy them to
        //      the temporary store first.
        let displayedSettings = settingsFromDisplay()
        displayedSettings.displayColours = self.currentSettings.displayColours
        self.currentSettings = displayedSettings
        self.currentSettings.saveSettings(self.appSuiteName)
    }


    /**
     Compare the current Settings page values to those we have stored in `currentSettings`.
     If any are different, we need to warn the user.

     FROM 2.0.0

     - Returns:
        `true` if one or more settings has changed, otherwise `false`.
     */
    internal func checkSettings() -> Bool {

        let displayedSettings = settingsFromDisplay()
        var settingsHaveChanged = self.currentSettings.doReverseMode != displayedSettings.doReverseMode

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.showYamlMarks != displayedSettings.showYamlMarks
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.showRawYamlOnError != displayedSettings.showRawYamlOnError
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.doIndentScalars != displayedSettings.doIndentScalars
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.fontName != displayedSettings.fontName
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.fontSize != displayedSettings.fontSize
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_KEYS] != nil
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_STRINGS] != nil
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_SPECIALS] != nil
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_MARKS] != nil
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_COMMENTS] != nil
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.indentSize != displayedSettings.indentSize
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.thumbnailMatchFinderMode != displayedSettings.thumbnailMatchFinderMode
        }

        if !settingsHaveChanged {
            settingsHaveChanged = self.currentSettings.previewWindowScale != displayedSettings.previewWindowScale
        }

        if !settingsHaveChanged {
            settingsHaveChanged = (self.currentSettings.previewMarginWidth != displayedSettings.previewMarginWidth) &&
                                   !(displayedSettings.previewMarginWidth.isClose(to: self.currentSettings.previewMarginWidth))
        }

        return settingsHaveChanged
    }


    /**
     Zap any temporary colour values.

     FROM 2.0.0
     */
    internal func clearNewColours() {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        for key in keys {
            if let _: String = self.currentSettings.displayColours["new_" + key] {
                self.currentSettings.displayColours["new_" + key] = nil
            }
        }
    }


    /**
     Set colours to defaults any temporary colour values.

     FROM 2.0.0
     */
    internal func applyDefaultColours() {

        let keys: [String] = BUFFOON_CONSTANTS.COLOUR_OPTIONS
        for key in keys {
            // Only apply the default as a new colour, if the current colour is different
            if self.defaultSettings.displayColours[key] != self.currentSettings.displayColours[key] {
                self.currentSettings.displayColours["new_" + key] = self.defaultSettings.displayColours[key]
            }
        }
    }

}
