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

    // MARK:- Class UI Properies
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
    @IBOutlet weak var reportWindow: NSWindow!
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!

    // Preferences Sheet
    //@IBOutlet weak var codeColourPopup: NSPopUpButton!
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var useLightCheckbox: NSButton!
    @IBOutlet weak var doShowTagCheckbox: NSButton!
    @IBOutlet weak var doIndentScalarsCheckbox: NSButton!
    @IBOutlet weak var doShowRawYamlCheckbox: NSButton!
    @IBOutlet weak var codeFontPopup: NSPopUpButton!
    @IBOutlet weak var codeIndentPopup: NSPopUpButton!
    // FROM 1.1.0
    @IBOutlet weak var codeColorWell: NSColorWell!
    @IBOutlet weak var codeStylePopup: NSPopUpButton!
    // FROM 1.1.1
    //@IBOutlet weak var tagInfoTextField: NSTextField!
    // FROM 1.1.6
    @IBOutlet weak var doSortKeysCheckbox: NSButton!
    @IBOutlet weak var doShowColonCheckbox: NSButton!

    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!
    

    // MARK:- Private Properies
    // private var previewCodeColour: Int = BUFFOON_CONSTANTS.CODE_COLOUR_INDEX
    // private var previewCodeFont: Int = BUFFOON_CONSTANTS.CODE_FONT_INDEX
    internal var whatsNewNav: WKNavigation? = nil
    private  var feedbackTask: URLSessionTask? = nil
    private  var indentDepth: Int = BUFFOON_CONSTANTS.YAML_INDENT
    private  var localYamlUTI: String = "N/A"
    private  var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME
    private  var doShowLightBackground: Bool = false
    private  var doShowTag: Bool = false
    private  var doShowRawYaml: Bool = false
    private  var doIndentScalars: Bool = false
    // FROM 1.0.1
    private var feedbackPath: String = MNU_SECRETS.ADDRESS.B
    // FROM 1.1.0
    internal var codeFonts: [PMFont] = []
    private  var codeFontName: String = BUFFOON_CONSTANTS.CODE_FONT_NAME
    private  var codeColourHex: String = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
    private  var codeFontSize: CGFloat = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
    // FROM 1.1.1
    internal var isMontereyPlus: Bool = false
    // FROM 1.1.4
    private  var havePrefsChanged: Bool = false
    // FROM 1.1.6
    private var doSortKeys: Bool = true
    private var doShowColons: Bool = false
    

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


    // MARK:- Action Functions

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
            
            self.feedbackTask = submitFeedback(feedback)
            
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
            self.codeFontSize = CGFloat(defaults.float(forKey: "com-bps-previewyaml-base-font-size"))
            self.indentDepth = defaults.integer(forKey: "com-bps-previewyaml-yaml-indent")
            
            self.doShowLightBackground = defaults.bool(forKey: "com-bps-previewyaml-do-use-light")
            self.doShowTag = defaults.bool(forKey: "com-bps-previewyaml-do-show-tag")
            self.doShowRawYaml = defaults.bool(forKey: "com-bps-previewyaml-show-bad-yaml")
            self.doIndentScalars = defaults.bool(forKey: "com-bps-previewyaml-do-indent-scalars")
            
            // FROM 1.1.0
            self.codeFontName = defaults.string(forKey: "com-bps-previewyaml-base-font-name") ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            self.codeColourHex = defaults.string(forKey: "com-bps-previewyaml-code-colour-hex") ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        }

        // Get the menu item index from the stored value
        // NOTE The index is that of the list of available fonts (see 'Common.swift') so
        //      we need to convert this to an equivalent menu index because the menu also
        //      contains a separator and two title items
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: self.codeFontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off
        self.doShowTagCheckbox.state = self.doShowTag ? .on : .off
        self.doShowRawYamlCheckbox.state = self.doShowRawYaml ? .on : .off
        self.doIndentScalarsCheckbox.state = self.doIndentScalars ? .on : .off
        
        let indents: [Int] = [1, 2, 4, 8]
        self.codeIndentPopup.selectItem(at: indents.firstIndex(of: self.indentDepth)!)
        
        // FROM 1.1.0
        // Set the colour panel's initial view
        // self.codeColourPopup.selectItem(at: self.previewCodeColour)
        NSColorPanel.setPickerMode(.RGB)
        self.codeColorWell.color = NSColor.hexToColour(self.codeColourHex)
        
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
        
        // FROM 1.1.1
        // Hide tag selection on Monterey
        if self.isMontereyPlus {
            self.doShowTagCheckbox.toolTip = "Not available in macOS 12.0 and up"
            // self.tagInfoTextField.stringValue = "macOS 12.0 Monterey adds its own thumbnail file extension tags, so this option is no longer available."
        }
        
        // FROM 1.1.2
        // Hide this option, don't just disable it
        self.doShowTagCheckbox.isHidden = self.isMontereyPlus
        // self.tagInfoTextField.isHidden = self.isMontereyPlus
        
        // FROM 1.1.4
        // Check for the OS mode
        let appearance: NSAppearance = NSApp.effectiveAppearance
        if let appearName: NSAppearance.Name = appearance.bestMatch(from: [.aqua, .darkAqua]) {
            self.useLightCheckbox.isHidden = (appearName == .aqua)
        }

        // FROM 1.1.6
        self.doSortKeysCheckbox.state = self.doSortKeys ? .on : .off
        self.doShowColonCheckbox.state = self.doShowColons ? .on : .off

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
    }


    /**
        Close the **Preferences** sheet and save any settings that have changed.

        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func doSavePreferences(sender: Any) {

        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let newColour: String = self.codeColorWell.color.hexString
            if newColour != self.codeColourHex {
                self.codeColourHex = newColour
                defaults.setValue(newColour,
                                  forKey: "com-bps-previewyaml-code-colour-hex")
            }
            
            let newValue: CGFloat = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.codeFontSize {
                defaults.setValue(newValue,
                                  forKey: "com-bps-previewyaml-base-font-size")
            }
            
            var state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewyaml-do-use-light")
            }

            state = self.doShowTagCheckbox.state == .on
            if self.isMontereyPlus { state = false }
            if self.doShowTag != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewyaml-do-show-tag")
            }
            
            state = self.doShowRawYamlCheckbox.state == .on
            if self.doShowRawYaml != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewyaml-show-bad-yaml")
            }
            
            state = self.doIndentScalarsCheckbox.state == .on
            if self.doIndentScalars != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewyaml-do-indent-scalars")
            }
            
            let indents: [Int] = [1, 2, 4, 8]
            let indent: Int = indents[self.codeIndentPopup.indexOfSelectedItem]
            if self.indentDepth != indent {
                defaults.setValue(indent,
                                  forKey: "com-bps-previewyaml-yaml-indent")
            }
            
            // FROM 1.1.0
            // Set the chosen font if it has changed
            if let fontName: String = getPostScriptName() {
                if fontName != self.codeFontName {
                    self.codeFontName = fontName
                    defaults.setValue(fontName,
                                      forKey: "com-bps-previewyaml-base-font-name")
                }
            }

            // FROM 1.1.6
            state = self.doSortKeysCheckbox.state == .on
            if self.doSortKeys != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SORT)
            }

            state = self.doShowColonCheckbox.state == .on
            if self.doShowColons != state {
                defaults.setValue(state, forKey: BUFFOON_CONSTANTS.PREFS_KEYS.COLON)
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
    }
    
    
    /**
        Generic IBAction for any Prefs control to register it has been used.
     
        - Parameters:
            - sender: The source of the action.
     */
    @IBAction private func checkboxClicked(sender: Any) {
        
        self.havePrefsChanged = true
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
            let key: String = "com-bps-previewyaml-do-show-whats-new-" + getVersion()
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
            let bodyFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-base-font-size")
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE),
                                  forKey: "com-bps-previewyaml-base-font-size")
            }

            // Thumbnail view base font size, stored as a CGFloat, not currently used
            // Default: 28.0
            let thumbFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-thumb-font-size")
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE),
                                  forKey: "com-bps-previewyaml-thumb-font-size")
            }
            
            // FROM 1.1.0
            // Colour of code blocks in the preview, stored as in integer array index
            // Default: #007D78FF
            let codeColourDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-code-colour-hex")
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_HEX,
                                  forKey: "com-bps-previewyaml-code-colour-hex")
            }
            
            // FROM 1.1.0
            // Font for previews and thumbnails
            // Default: Courier
            let codeFontName: Any? = defaults.object(forKey: "com-bps-previewyaml-base-font-name")
            if codeFontName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_FONT_NAME,
                                  forKey: "com-bps-previewyaml-base-font-name")
            }
            
            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-do-use-light")
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewyaml-do-use-light")
            }

            // Show the file identity ('tag') on Finder thumbnails
            // Default: true
            let showTagDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-do-show-tag")
            if showTagDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewyaml-do-show-tag")
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = "com-bps-previewyaml-do-show-whats-new-" + getVersion()
            let showNewDefault: Any? = defaults.object(forKey: key)
            if showNewDefault == nil {
                defaults.setValue(true, forKey: key)
            }
            
            // Record the preferred indent depth in spaces
            // Default: 2
            let indentDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-yaml-indent")
            if indentDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.YAML_INDENT,
                                  forKey: "com-bps-previewyaml-yaml-indent")
            }
            
            // Indent scalar values?
            // Default: false
            let indentScalarsDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-do-indent-scalars")
            if indentScalarsDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewyaml-do-indent-scalars")
            }
            
            // Present malformed YAML on error?
            // Default: false
            let presentBadYamlDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-show-bad-yaml")
            if presentBadYamlDefault == nil {
                defaults.setValue(false,
                                  forKey: "com-bps-previewyaml-show-bad-yaml")
            }

            // FROM 1.1.6
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

            // Sync any additions
            defaults.synchronize()
        }

    }
    

    /**
     Send the feedback string etc.

     - Parameters:
        - feedback: The text of the user's comment.

     - Returns: A URLSessionTask primed to send the comment, or `nil` on error.
     */
    private func submitFeedback(_ feedback: String) -> URLSessionTask? {

        // First get the data we need to build the user agent string
        let userAgent: String = getUserAgentForFeedback()
        let endPoint: String = MNU_SECRETS.ADDRESS.A

        // Get the date as a string
        let dateString: String = getDateForFeedback()

        // Assemble the message string
        let dataString: String = """
         *FEEDBACK REPORT*
         *Date:* \(dateString)
         *User Agent:* \(userAgent)
         *UTI:* \(self.localYamlUTI)
         *FEEDBACK:*
         \(feedback)
         """

        // Build the data we will POST:
        let dict: NSMutableDictionary = NSMutableDictionary()
        dict.setObject(dataString,
                        forKey: NSString.init(string: "text"))
        dict.setObject(true, forKey: NSString.init(string: "mrkdwn"))

        // Make and return the HTTPS request for sending
        if let url: URL = URL.init(string: self.feedbackPath + endPoint) {
            var request: URLRequest = URLRequest.init(url: url)
            request.httpMethod = "POST"

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: dict,
                                                              options:JSONSerialization.WritingOptions.init(rawValue: 0))

                request.addValue(userAgent, forHTTPHeaderField: "User-Agent")
                request.addValue("application/json", forHTTPHeaderField: "Content-type")

                let config: URLSessionConfiguration = URLSessionConfiguration.ephemeral
                let session: URLSession = URLSession.init(configuration: config,
                                                          delegate: self,
                                                          delegateQueue: OperationQueue.main)
                return session.dataTask(with: request)
            } catch {
                // NOP
            }
        }

        return nil
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
            if let appearName: NSAppearance.Name = appearance.bestMatch(from: [.aqua, .darkAqua]) {
                // NOTE Appearance it this point seems to reflect the mode
                //      we're coming FROM, not what it has changed to
                self.useLightCheckbox.isHidden = (appearName != .aqua)
            }
        }
    }
    
}
