/*
 *  AppDelegate.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2023 Tony Smith. All rights reserved.
 */


import Cocoa
import CoreServices
import WebKit


@main
final class AppDelegate: NSObject,
                         NSApplicationDelegate,
                         URLSessionDelegate,
                         URLSessionDataDelegate,
                         WKNavigationDelegate {

    // MARK: - Class UI Properies
    
    // Menu Items
    @IBOutlet var helpMenuOnlineHelp: NSMenuItem!
    @IBOutlet var helpMenuAcknowledgments: NSMenuItem!
    @IBOutlet var helpMenuAppStoreRating: NSMenuItem!
    @IBOutlet var helpMenuAckYamlSwift: NSMenuItem!
    // FROM 1.0.1
    @IBOutlet var helpMenuOthersPreviewMarkdown: NSMenuItem!
    // FROM 1.0.2
    @IBOutlet var helpMenuOthersPreviewCode: NSMenuItem!
    // FROM 1.1.3
    @IBOutlet var helpMenuOthersPreviewjson: NSMenuItem!
    // FROM 1.1.4
    @IBOutlet var helpMenuOthersPreviewText: NSMenuItem!
    @IBOutlet var helpMenuWhatsNew: NSMenuItem!
    @IBOutlet var helpMenuReportBug: NSMenuItem!
    @IBOutlet var mainMenuSettings: NSMenuItem!
    
    // Panel Items
    @IBOutlet var versionLabel: NSTextField!
    
    // Windows
    @IBOutlet var window: NSWindow!

    // Report Sheet
    @IBOutlet var reportWindow: NSWindow!
    @IBOutlet var feedbackText: NSTextField!
    @IBOutlet var connectionProgress: NSProgressIndicator!

    // Preferences Sheet
    //@IBOutlet weak var codeColourPopup: NSPopUpButton!
    @IBOutlet var preferencesWindow: NSWindow!
    @IBOutlet var fontSizeSlider: NSSlider!
    @IBOutlet var fontSizeLabel: NSTextField!
    @IBOutlet var useLightCheckbox: NSButton!
    //@IBOutlet var doShowTagCheckbox: NSButton!
    @IBOutlet var doIndentScalarsCheckbox: NSButton!
    @IBOutlet var doShowRawYamlCheckbox: NSButton!
    @IBOutlet var codeFontPopup: NSPopUpButton!
    @IBOutlet var codeIndentPopup: NSPopUpButton!
    // FROM 1.1.0
    @IBOutlet var codeColorWell: NSColorWell!
    @IBOutlet var codeStylePopup: NSPopUpButton!
    // FROM 1.1.1
    //@IBOutlet var tagInfoTextField: NSTextField!
    // FROM 1.2.0
    @IBOutlet var doSortKeysCheckbox: NSButton!
    @IBOutlet var doShowColonCheckbox: NSButton!
    @IBOutlet var colourSelectionPopup: NSPopUpButton!

    // What's New Sheet
    @IBOutlet var whatsNewWindow: NSWindow!
    @IBOutlet var whatsNewWebView: WKWebView!
    

    // MARK: - Private Properies
    
    internal var whatsNewNav: WKNavigation? = nil
    private  var feedbackTask: URLSessionTask? = nil
    private  var indentDepth: Int = BUFFOON_CONSTANTS.YAML_INDENT
             var localYamlUTI: String = "N/A"
    private  var doShowLightBackground: Bool = false
    private  var doShowTag: Bool = false
    private  var doShowRawYaml: Bool = false
    private  var doIndentScalars: Bool = false
    // FROM 1.1.0
    internal var codeFonts: [PMFont] = []
    private  var codeFontName: String = BUFFOON_CONSTANTS.CODE_FONT_NAME
    private  var codeColourHex: String = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private  var codeFontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
    // FROM 1.1.1
    internal var isMontereyPlus: Bool = false
    // FROM 1.1.4
    private  var havePrefsChanged: Bool = false
    // FROM 1.2.0
    private var doSortKeys: Bool = true
    private var doShowColons: Bool = false
    private var displayColours: [String:String] = [:]

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // FROM 1.1.0
        // Asynchronously get the list of code fonts
        DispatchQueue.init(label: "com.bps.previewyaml.async-queue").async {
            self.asyncGetFonts()
        }

        // Set application group-level defaults
        registerPreferences()
        
        // FROM 1.1.1
        recordSystemState()
        
        // Get the local UTI for Yaml files
        self.localYamlUTI = getLocalFileUTI(BUFFOON_CONSTANTS.SAMPLE_UTI_FILE)

        // Add the app's version number to the UI
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Version \(version) (\(build))"
        
        // Disable the Help menu Spotlight features
        let dummyHelpMenu: NSMenu = NSMenu.init(title: "Dummy")
        let theApp = NSApplication.shared
        theApp.helpMenu = dummyHelpMenu
        
        // FROM 1.1.4
        // Watch for macOS UI mode changes
        DistributedNotificationCenter.default.addObserver(self,
                                                          selector: #selector(interfaceModeChanged),
                                                          name: NSNotification.Name(rawValue: "AppleInterfaceThemeChangedNotification"),
                                                          object: nil)

        // Centre the main window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        // Show the 'What's New' panel if we need to
        // NOTE Has to take place at the end of the function
        doShowWhatsNew(self)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK: - Action Functions

    /**
     Called from **File > Close** and the various Quit controls.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doClose(_ sender: Any) {
        
        // Reset the QL thumbnail cache... just in case it helps
        _ = runProcess(app: "/usr/bin/qlmanage", with: ["-r", "cache"])
        
        // FROM 1.1.4
        // Check for open panels
        if self.preferencesWindow.isVisible {
            if self.havePrefsChanged {
                let alert: NSAlert = showAlert("You have unsaved settings",
                                               "Do you wish to cancel and save them, or quit the app anyway?",
                                               false)
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                alert.beginSheetModal(for: self.preferencesWindow) { (response: NSApplication.ModalResponse) in
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        // The user clicked 'Quit'
                        self.preferencesWindow.close()
                        self.window.close()
                    }
                }
                
                return
            }
            
            self.preferencesWindow.close()
        }
        
        if self.whatsNewWindow.isVisible {
            self.whatsNewWindow.close()
        }
        
        if self.reportWindow.isVisible {
            if self.feedbackText.stringValue.count > 0 {
                let alert: NSAlert = showAlert("You have unsent feedback",
                                               "Do you wish to cancel and send it, or quit the app anyway?",
                                               false)
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Cancel")
                alert.beginSheetModal(for: self.reportWindow) { (response: NSApplication.ModalResponse) in
                    if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                        // The user clicked 'Quit'
                        self.reportWindow.close()
                        self.window.close()
                    }
                }
                
                return
            }
            
            self.reportWindow.close()
        }
                
        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    /**
     Called from various **Help** items to open various websites.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doShowSites(sender: Any) {
        
        // Open the websites for contributors, help and suc
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = BUFFOON_CONSTANTS.URL_MAIN
        
        // Depending on the menu selected, set the load path
        if item == self.helpMenuAcknowledgments {
            path += "#acknowledgements"
        } else if item == self.helpMenuAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE + "?action=write-review"
        } else if item == self.helpMenuAckYamlSwift {
            path = "https://github.com/behrang/YamlSwift"
        } else if item == self.helpMenuOnlineHelp {
            path += "#how-to-use-previewyaml"
        } else if item == self.helpMenuOthersPreviewMarkdown {
            path = BUFFOON_CONSTANTS.APP_URLS.PM
        } else if item == self.helpMenuOthersPreviewCode {
            path = BUFFOON_CONSTANTS.APP_URLS.PC
        } else if item == self.helpMenuOthersPreviewjson {
            path = BUFFOON_CONSTANTS.APP_URLS.PJ
        } else if item == self.helpMenuOthersPreviewText {
            path = BUFFOON_CONSTANTS.APP_URLS.PT
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }

    /**
     Open the System Preferences app at the Extensions pane.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doOpenSysPrefs(sender: Any) {

        // Open the System Preferences app at the Extensions pane
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }


    // MARK: - Report Functions

    /**
     Display a window in which the user can submit feedback, or report a bug.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doShowReportWindow(sender: Any?) {
        
        // FROM 1.1.4
        // Hide manus we don't want used
        hidePanelGenerators()
        
        // Reset the UI
        self.connectionProgress.stopAnimation(self)
        self.feedbackText.stringValue = ""

        // Present the window
        self.window.beginSheet(self.reportWindow, completionHandler: nil)
    }


    /**
     User has clicked the Report window's **Cancel** button, so just close the sheet.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doCancelReportWindow(sender: Any) {

        // User has clicked the Report window's 'Cancel' button,
        // so just close the sheet

        self.connectionProgress.stopAnimation(self)
        self.window.endSheet(self.reportWindow)
        
        // FROM 1.1.4
        // Restore menus
        showPanelGenerators()
    }


    /**
     User has clicked the Report window's **Send** button.

     Get the message (if there is one) from the text field and submit it.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction @objc private func doSendFeedback(sender: Any) {

        // User has clicked the Report window's 'Send' button,
        // so get the message (if there is one) from the text field and submit it
        
        let feedback: String = self.feedbackText.stringValue

        if feedback.count > 0 {
            // Start the connection indicator if it's not already visible
            self.connectionProgress.startAnimation(self)
            
            /*
             Add your own `func sendFeedback(_ feedback: String) -> URLSessionTask?` function
             */
            self.feedbackTask = sendFeedback(feedback)
            
            if self.feedbackTask != nil {
                // We have a valid URL Session Task, so start it to send
                self.feedbackTask!.resume()
                return
            } else {
                // Report the error
                sendFeedbackError()
            }
        }
        
        // No feedback, so close the sheet
        self.window.endSheet(self.reportWindow)
        
        // FROM 1.1.4
        // Restore menus
        showPanelGenerators()
        
        // NOTE sheet closes asynchronously unless there was no feedback to send,
        //      or an error occured with setting up the feedback session
    }
    

    // MARK: - Preferences Functions

    /**
     Initialise and display the **Preferences** sheet.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doShowPreferences(sender: Any) {

        // FROM 1.1.4
        // Hide menus we don't want used when the panel is open
        hidePanelGenerators()
        
        // FROM 1.1.4
        // Reset the changed prefs flag
        self.havePrefsChanged = false

        // The suite name is the app group name, set in each the entitlements file of
        // the host app and of each extension
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            self.codeFontSize           = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE))
            self.indentDepth            = defaults.integer(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            self.doShowLightBackground  = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            self.doShowTag              = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.TAG)
            self.doShowRawYaml          = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            self.doIndentScalars        = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            
            // FROM 1.1.0
            self.codeFontName           = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_FONT) ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            //self.codeColourHex = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR) ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX

            // FROM 1.2.0
            self.doSortKeys                 = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SORT)
            self.doShowColons               = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.COLON)
            self.displayColours["key"]      = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            self.displayColours["string"]   = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR) ?? BUFFOON_CONSTANTS.STRING_COLOUR_HEX
            self.displayColours["special"]  = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR) ?? BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX
        }

        // Get the menu item index from the stored value
        // NOTE The index is that of the list of available fonts (see 'Common.swift') so
        //      we need to convert this to an equivalent menu index because the menu also
        //      contains a separator and two title items
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: self.codeFontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off
        //self.doShowTagCheckbox.state = self.doShowTag ? .on : .off
        self.doShowRawYamlCheckbox.state = self.doShowRawYaml ? .on : .off
        self.doIndentScalarsCheckbox.state = self.doIndentScalars ? .on : .off
        
        let indents: [Int] = [1, 2, 4, 8]
        self.codeIndentPopup.selectItem(at: indents.firstIndex(of: self.indentDepth)!)
        
        // FROM 1.1.0
        // Set the colour panel's initial view
        NSColorPanel.setPickerMode(.RGB)
        self.codeColorWell.color = NSColor.hexToColour(self.displayColours["key"] ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX)
        
        // FROM 1.1.0
        // Set the font name popup
        // List the current system's monospace fonts
        self.codeFontPopup.removeAllItems()
        for i: Int in 0..<self.codeFonts.count {
            let font: PMFont = self.codeFonts[i]
            self.codeFontPopup.addItem(withTitle: font.displayName)
        }

        self.codeStylePopup.isEnabled = false
        selectFontByPostScriptName(self.codeFontName)

        /* REMOVED 1.2.0
        // FROM 1.1.1
        // Hide tag selection on Monterey
        if self.isMontereyPlus {
            self.doShowTagCheckbox.toolTip = "Not available in macOS 12.0 and up"
            // self.tagInfoTextField.stringValue = "macOS 12.0 Monterey adds its own thumbnail file extension tags, so this option is no longer available."
        }
        
        // FROM 1.1.2
        // Hide this option, don't just disable it
        self.doShowTagCheckbox.isHidden = self.isMontereyPlus
        */
        
        // FROM 1.1.4
        // Check for the OS mode
        let appearance: NSAppearance = NSApp.effectiveAppearance
        if let appearanceName: NSAppearance.Name = appearance.bestMatch(from: [.aqua, .darkAqua]) {
            self.useLightCheckbox.isEnabled = (appearanceName != .aqua)
        }

        // FROM 1.2.0
        self.doSortKeysCheckbox.state = self.doSortKeys ? .on : .off
        self.doShowColonCheckbox.state = self.doShowColons ? .on : .off
        self.colourSelectionPopup.selectItem(at: 0)

        // Display the sheet
        self.window.beginSheet(self.preferencesWindow, completionHandler: nil)
    }


    /**
        When the font size slider is moved and released, this function updates the font size readout.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doMoveSlider(sender: Any) {
        
        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        self.havePrefsChanged = true
    }


    /**
     Called when the user selects a font from either list.

     FROM 1.1.0

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction private func doUpdateFonts(sender: Any) {
        
        self.havePrefsChanged = true
        setStylePopup()
    }

    
    /**
        Close the **Preferences** sheet without saving.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doClosePreferences(sender: Any) {

        if self.havePrefsChanged {
            let alert: NSAlert = showAlert("You have made changes",
                                           "Do you wish to go back and save them, or ignore them? ",
                                           false)
            alert.addButton(withTitle: "Go Back")
            alert.addButton(withTitle: "Ignore Changes")
            alert.beginSheetModal(for: self.preferencesWindow) { (response: NSApplication.ModalResponse) in
                if response != NSApplication.ModalResponse.alertFirstButtonReturn {
                    // The user clicked 'Cancel'
                    self.closePrefsWindow()
                }
            }
        } else {
            closePrefsWindow()
        }
    }


    /**
        Follow-on function to close the **Preferences** sheet without saving.
        FROM 1.1.0

        - Parameters:
            - sender: The source of the action.
     */

    private func closePrefsWindow() {

        // FROM 1.1.0
        // Close the colour selection panel if it's open
        if self.codeColorWell.isActive {
            NSColorPanel.shared.close()
            self.codeColorWell.deactivate()
        }

        self.window.endSheet(self.preferencesWindow)

        // FROM 1.1.4
        // Restore menus
        showPanelGenerators()

        // FROM 1.2.0
        clearNewColours()
        self.havePrefsChanged = false
    }


    /**
        Close the **Preferences** sheet and save any settings that have changed.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doSavePreferences(sender: Any) {

        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            /* REMOVED 1.2.0
            let newColour: String = self.codeColorWell.color.hexString
            if newColour != self.codeColourHex {
                self.codeColourHex = newColour
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            }
            */

            let newValue: CGFloat = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.codeFontSize {
                defaults.setValue(newValue, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE)
            }
            
            var state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            }

            /* REMOVED 1.2.0
            state = self.doShowTagCheckbox.state == .on
            if self.isMontereyPlus { state = false }
            if self.doShowTag != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.TAG)
            }
            */

            state = self.doShowRawYamlCheckbox.state == .on
            if self.doShowRawYaml != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            }
            
            state = self.doIndentScalarsCheckbox.state == .on
            if self.doIndentScalars != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            }
            
            let indents: [Int] = [1, 2, 4, 8]
            let indent: Int = indents[self.codeIndentPopup.indexOfSelectedItem]
            if self.indentDepth != indent {
                defaults.setValue(indent, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            }
            
            // FROM 1.1.0
            // Set the chosen font if it has changed
            if let fontName: String = getPostScriptName() {
                if fontName != self.codeFontName {
                    self.codeFontName = fontName
                    defaults.setValue(fontName, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_FONT)
                }
            }

            // FROM 1.2.0
            state = self.doSortKeysCheckbox.state == .on
            if self.doSortKeys != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SORT)
            }

            state = self.doShowColonCheckbox.state == .on
            if self.doShowColons != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.COLON)
            }

            if let newColour: String = self.displayColours["new_key"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            }

            if let newColour: String = self.displayColours["new_string"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR)
            }

            if let newColour: String = self.displayColours["new_special"] {
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR)
            }

            // Sync any changes
            defaults.synchronize()
        }
        
        // FROM 1.1.0
        // Close the colour selection panel if it's open
        if self.codeColorWell.isActive {
            NSColorPanel.shared.close()
            self.codeColorWell.deactivate()
        }

        // Remove the sheet now we have the data
        self.window.endSheet(self.preferencesWindow)
        
        // Restore menus
        showPanelGenerators()

        // FROM 1.2.0
        clearNewColours()
    }
    
    
    /**
        Generic IBAction for any Prefs control to register it has been used.
     
        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func checkboxClicked(sender: Any) {
        
        self.havePrefsChanged = true
    }


    /**
        Update the colour preferences dictionary with a value from the
        colour well when a colour is chosen.

        - Parameters:
            - sender: The source of the action.
     */
    @objc @IBAction private func colourSelected(sender: Any) {

        let keys: [String] = ["key", "string", "special"]
        let key: String = "new_" + keys[self.colourSelectionPopup.indexOfSelectedItem]
        self.displayColours[key] = self.codeColorWell.color.hexString
        self.havePrefsChanged = true
    }


    /**
        Update the colour well with the stored colour: either a new one, previously
        chosen, or the loaded preference.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doChooseColourType(sender: Any) {

        let keys: [String] = ["key", "string", "special"]
        let key: String = keys[self.colourSelectionPopup.indexOfSelectedItem]

        // If there's no `new_xxx` key, the next line will evaluate to false
        if let colour: String = self.displayColours["new_" + key] {
            if colour.count != 0 {
                // Set the colourwell with the updated colour and exit
                self.codeColorWell.color = NSColor.hexToColour(colour)
                return
            }
        }

        // Set the colourwell with the stored colour
        if let colour: String = self.displayColours[key] {
            self.codeColorWell.color = NSColor.hexToColour(colour)
        }
    }


    /**
        Zap any temporary colour values.
        FROM 1.2.0

     */
    private func clearNewColours() {

        let keys: [String] = ["key", "string", "special"]
        for key in keys {
            if let _: String = self.displayColours["new_" + key] {
                self.displayColours["new_" + key] = nil
            }
        }
    }


    // MARK: - What's New Sheet Functions

    /**
        Show the **What's New** sheet.

        If we're on a new, non-patch version, of the user has explicitly
        asked to see it with a menu click See if we're coming from a menu click
        (`sender != self`) or directly in code from *appDidFinishLoading()*
        (`sender == self`)

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doShowWhatsNew(_ sender: Any) {
        
        // See if we're coming from a menu click (sender != self) or
        // directly in code from 'appDidFinishLoading()' (sender == self)
        var doShowSheet: Bool = type(of: self) != type(of: sender)
        
        if !doShowSheet {
            // We are coming from the 'appDidFinishLoading()' so check
            // if we need to show the sheet by the checking the prefs
            if let defaults = UserDefaults(suiteName: self.appSuiteName) {
                // Get the version-specific preference key
                let key: String = BUFFOON_CONSTANTS.WHATS_NEW_PREF + getVersion()
                doShowSheet = defaults.bool(forKey: key)
            }
        }
      
        // Configure and show the sheet
        if doShowSheet {
            // FROM 1.1.4
            // Hide manus we don't want used
            hidePanelGenerators()
            
            // First, get the folder path
            let htmlFolderPath = Bundle.main.resourcePath! + "/new"
            
            // Set up the WKWebBiew: no elasticity, horizontal scroller
            self.whatsNewWebView.enclosingScrollView?.hasHorizontalScroller = false
            self.whatsNewWebView.enclosingScrollView?.horizontalScrollElasticity = .none
            self.whatsNewWebView.enclosingScrollView?.verticalScrollElasticity = .none
            
            // Just in case, make sure we can load the file
            if FileManager.default.fileExists(atPath: htmlFolderPath) {
                let htmlFileURL = URL.init(fileURLWithPath: htmlFolderPath + "/new.html")
                let htmlFolderURL = URL.init(fileURLWithPath: htmlFolderPath)
                self.whatsNewNav = self.whatsNewWebView.loadFileURL(htmlFileURL, allowingReadAccessTo: htmlFolderURL)
            }
        }
    }


    /**
        Close the **What's New** sheet.

        Make sure we clear the preference flag for this minor version, so that
        the sheet is not displayed next time the app is run (unless the version changes)

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doCloseWhatsNew(_ sender: Any) {

        // Close the sheet
        self.window.endSheet(self.whatsNewWindow)
        
        // Scroll the web view back to the top
        self.whatsNewWebView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)

        // Set this version's preference
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let key: String = BUFFOON_CONSTANTS.PREFS_KEYS.WHATS_NEW + getVersion()
            defaults.setValue(false, forKey: key)

            #if DEBUG
            print("\(key) reset back to true")
            defaults.setValue(true, forKey: key)
            #endif

            defaults.synchronize()
        }
        
        // FROM 1.1.4
        // Restore menus
        showPanelGenerators()
    }


    // MARK: - Misc Functions

    /**
     Called by the app at launch to register its initial defaults.
     */
    private func registerPreferences() {

        // Check if each preference value exists -- set if it doesn't
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            // Preview body font size, stored as a CGFloat
            // Default: 16.0
            let bodyFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE)
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE)
            }

            // Thumbnail view base font size, stored as a CGFloat, not currently used
            // Default: 28.0
            let thumbFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.THUMB_SIZE)
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.THUMB_SIZE)
            }
            
            /* REMOVED 1.2.0
            // FROM 1.1.0
            // Colour of keys in the preview, stored as in integer array index
            // Default: #007D78FF
            let codeColourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            }
            */

            // FROM 1.1.0
            // Font for previews and thumbnails
            // Default: Courier
            let codeFontName: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_FONT)
            if codeFontName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_FONT_NAME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_FONT)
            }
            
            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            if useLightDefault == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            }

            // Show the file identity ('tag') on Finder thumbnails
            // Default: true
            let showTagDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.TAG)
            if showTagDefault == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.TAG)
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = BUFFOON_CONSTANTS.PREFS_KEYS.WHATS_NEW + getVersion()
            let showNewDefault: Any? = defaults.object(forKey: key)
            if showNewDefault == nil {
                defaults.setValue(true, forKey: key)
            }
            
            // Record the preferred indent depth in spaces
            // Default: 2
            let indentDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            if indentDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.YAML_INDENT,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            }
            
            // Indent scalar values?
            // Default: false
            let indentScalarsDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            if indentScalarsDefault == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            }
            
            // Present malformed YAML on error?
            // Default: false
            let presentBadYamlDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            if presentBadYamlDefault == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            }

            // FROM 1.2.0
            // Sort dictionary keys
            // Default: true
            let sortKeysDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SORT)
            if sortKeysDefault == nil {
                defaults.setValue(true, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SORT)
            }

            // Render colon after keys
            // Default: false
            let showColonDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.COLON)
            if showColonDefault == nil {
                defaults.setValue(false, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.COLON)
            }

            // Colour of keys in the preview, stored as a hex string
            // Default: #007D78FF
            var colourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR)
            }

            // Colour of strings in the preview, stored as a hex string
            // Default: #FC6A5DFF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.STRING_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR)
            }

            // Colour of special values (NaN +/-INF in the preview, stored as a hex string
            // Default: #D0BF69FF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX,
                                  forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR)
            }

            // Sync any additions
            defaults.synchronize()
        }

    }


    /**
     Handler for macOS UI mode change notifications.
     
     FROM 1.1.4
     */
    @objc private func interfaceModeChanged() {
        
        if self.preferencesWindow.isVisible {
            // Prefs window is up, so switch the use light background checkbox
            // on or off according to whether the current mode is light
            // NOTE For light mode, this checkbox is irrelevant, so the
            //      checkbox should be disabled
            let appearance: NSAppearance = NSApp.effectiveAppearance
            if let appearanceName: NSAppearance.Name = appearance.bestMatch(from: [.aqua, .darkAqua]) {
                // NOTE Appearance it this point seems to reflect the mode
                //      we're coming FROM, not what it has changed to
                self.useLightCheckbox.isEnabled = (appearanceName == .aqua)
            }
        }
    }
    
}
