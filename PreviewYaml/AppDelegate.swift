/*
 *  AppDelegate.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit
import CoreServices
import WebKit


@main
@MainActor
final class AppDelegate: NSResponder,
                         NSApplicationDelegate,
                         NSControlTextEditingDelegate,
                         NSMenuDelegate,
                         NSTextFieldDelegate,
                         NSWindowDelegate,
                         WKNavigationDelegate {

    // MARK: - Class UI Properies
    
    // Menu Items
    @IBOutlet weak var helpMenu: NSMenuItem!
    @IBOutlet weak var helpMenuOnlineHelp: NSMenuItem!
    @IBOutlet weak var helpMenuAppStoreRating: NSMenuItem!
    @IBOutlet weak var helpMenuOthersPreviewMarkdown: NSMenuItem!
    @IBOutlet weak var helpMenuOthersPreviewCode: NSMenuItem!
    @IBOutlet weak var helpMenuOthersPreviewjson: NSMenuItem!
    // FROM 1.1.4
    @IBOutlet weak var helpMenuWhatsNew: NSMenuItem!
    @IBOutlet weak var helpMenuReportBug: NSMenuItem!
    @IBOutlet weak var mainMenuSettings: NSMenuItem!

    // Windows
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var infoButton: NSButton!
    @IBOutlet weak var settingsButton: NSButton!
    @IBOutlet weak var feedbackButton: NSButton!
    @IBOutlet weak var mainTabView: NSTabView!

    // Window > Info Tab Items
    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var infoLabel: NSTextField!

    // Window > Settings Tab Items
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var applyButton: NSButton!
    @IBOutlet var colourSelectionPopup: NSPopUpButton!
    @IBOutlet var colourWell: NSColorWell!
    @IBOutlet var fontPopup: NSPopUpButton!
    @IBOutlet var stylePopup: NSPopUpButton!
    @IBOutlet var useLightSwitch: NSSwitch!
    @IBOutlet var doIndentScalarsSwitch: NSSwitch!
    @IBOutlet var showBadYamlSwitch: NSSwitch!
    @IBOutlet var showYamlMarksSwitch: NSSwitch!
    @IBOutlet var indentPopup: NSPopUpButton!

    // Window > Feedback Tab Items
    @IBOutlet weak var messageSizeLabel: NSTextField!
    @IBOutlet weak var messageSendButton: NSButton!
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!

    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!

    // FROM 2.0.0
    // Advanced Settings Sheet
    @IBOutlet weak var advancedSettingsSheet: NSWindow!
    @IBOutlet weak var helpAdvancedButton: NSButton!
    @IBOutlet weak var previewSizeAdvancedPopup: NSPopUpButton!
    @IBOutlet weak var tintTumbnailsAdvancedSwitch: NSSwitch!
    @IBOutlet weak var tintTumbnailsAdvancedLabel: NSTextField!
    @IBOutlet weak var previewMarginSizeText: NSTextField!
    @IBOutlet weak var previewMarginRangeText: NSTextField!


    // MARK: - Private Properies

    var localYamlUTI: String = "N/A"

    // MARK: - Private Properies

    internal var whatsNewNav: WKNavigation?     = nil
    internal var fonts: [PMFont]                = []
    // FROM 2.0.0
    private  var tabManager: PMTabManager       = PMTabManager()
    internal var hasSentFeedback: Bool          = false
    internal var timer: Timer?                  = nil
    internal let defaultSettings: PYSettings    = PYSettings()      // Standard values
    internal var currentSettings: PYSettings    = PYSettings()      // Loaded val

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    internal var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Asynchronously get the list of code fonts
        // FROM 2.0.0 - Use Swift Concurrency
        Task {
            asyncGetFonts()
        }

        // Set application group-level defaults
        self.defaultSettings.registerSettings(self.appSuiteName, getVersion())

        // Add the app's version number to the UI
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Version \(version) (\(build))"

        // Disable the Help menu Spotlight features
        let dummyHelpMenu: NSMenu = NSMenu(title: "Dummy")
        let theApp = NSApplication.shared
        theApp.helpMenu = dummyHelpMenu

        // FROM 2.0.0
        // Configure the tab manager
        self.tabManager.parent = self
        self.tabManager.buttons.append(self.infoButton)
        self.tabManager.buttons.append(self.settingsButton)
        self.tabManager.buttons.append(self.feedbackButton)
        self.infoButton.toolTip = "About PreviewYaml 2"
        self.settingsButton.toolTip = "Set preview styles and content"
        self.feedbackButton.toolTip = "Send feedback to the developer"
        self.infoButton.alphaValue = 1.0
        self.settingsButton.alphaValue = 1.0
        self.feedbackButton.alphaValue = 1.0

        // Add callback closures, one per tab, to the tab manager
        self.tabManager.callbacks.append(nil)   // Info tab
        self.tabManager.callbacks.append {      // Settings tab
            self.willShowSettingsPage()
        }
        self.tabManager.callbacks.append {
            self.willShowFeedbackPage()         // Feedback tab
        }

        // Clear the Feedback tab
        // NOTE Don't initialise the Settings tab here too:
        //      It must happen after we've got a list of fonts
        initialiseFeedback()

        // FROM 2.0.0
        // Set up advanced settings
        self.previewMarginSizeText.delegate = self
        self.previewMarginRangeText.stringValue = "Valid range \(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MIN)-\(BUFFOON_CONSTANTS.PREVIEW_SIZE.PREVIEW_MARGIN_WIDTH_MAX)"

        // Centre the main window and display
        setInfoText()
        self.window.delegate = self
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
    @IBAction
    private func doClose(_ sender: Any) {

        closeBasics()
        closeSettings()
    }
    

    /**
     Close sheets and perform other general close-related tasks.

     FROM 2.0.0
     */
    internal func closeBasics() {

        // Close the What's New sheet if it's open
        if self.whatsNewWindow.isVisible {
            self.whatsNewWindow.close()
        }
    }


    /**
     Handle a settings-change call to action, if there is one, and either bail (to allow the user
     to save the settings) or move on to the feedback check.

     FROM 2.0.0
     */
    internal func closeSettings() {

        // Are there any unsaved changes to the settings?
        if checkSettings() {
            let alert: NSAlert = makeAlert("You have unsaved settings",
                                           "Do you wish to cancel and save or change them, or quit the app anyway?",
                                           false)
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: self.window) { (response) in
                if response == .alertFirstButtonReturn {
                    // The user clicked 'Quit': now check for feedback changes
                    self.closeFeedback()
                }
            }

            // Exit the close process to allow the user to save their changed settings
            return
        }

        // Move on to the next phase: the feedback check
        closeFeedback()
    }


    /**
     Handle a feedback-unsent call to action, if one is needed, and either bail (to all the user
     to send the feedback) or close the main window.

     FROM 2.0.0
     */
    internal func closeFeedback() {

        // Does the feeback page contain text? If so let the user know
        if self.feedbackText.stringValue.count > 0 && !self.hasSentFeedback {
            let alert: NSAlert = makeAlert("You have unsent feedback",
                                           "Do you wish to cancel and send it, or quit the app anyway?",
                                           false)
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: self.window) { (response) in
                if response == .alertFirstButtonReturn {
                    // The user clicked 'Quit'
                    self.window.close()
                }
            }

            // Exit the close process to allow the user to send their entered feedback
            return
        }

        // No feedback text to send/ignore so close the window which will trigger an app closure
        self.window.close()
    }


    @IBAction
    private func doSwitchTab(sender: NSButton) {

        // FROM 2.0.0
        self.tabManager.buttonClicked(sender)
    }


    @IBAction
    private func doShowSettings(sender: Any) {

        // FROM 2.0.0
        self.tabManager.programmaticallyClickButton(at: 1)
    }


    @IBAction
    private func doShowFeedback(sender: Any) {

        // FROM 2.0.0
        self.tabManager.programmaticallyClickButton(at: 2)
    }


    /**
     Alternative route to help.
     */
    @IBAction
    private func doShowPrefsHelp(sender: Any) {

        let path: String
        if sender as? NSButton == self.helpAdvancedButton {
            path = BUFFOON_CONSTANTS.URL_MAIN + "#advanced-settings"
        } else {
            path = BUFFOON_CONSTANTS.URL_MAIN + "#customise-the-preview"
        }

        NSWorkspace.shared.open(URL(string:path)!)
    }


    /**
     Called from various **Help** items to open various websites.

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    @objc
    private func doShowSites(sender: Any) {

        // Open the websites for contributors, help and suc
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = BUFFOON_CONSTANTS.URL_MAIN
        
        // Depending on the menu selected, set the load path
        if item == self.helpMenuAppStoreRating {
            path = BUFFOON_CONSTANTS.APP_STORE + "?action=write-review"
        } else if item == self.helpMenuOnlineHelp {
            path += "#how-to-use-previewyaml"
        } else if item == self.helpMenuOthersPreviewMarkdown {
            path = BUFFOON_CONSTANTS.APP_URLS.PM
        } else if item == self.helpMenuOthersPreviewCode {
            path = BUFFOON_CONSTANTS.APP_URLS.PC
        } else if item == self.helpMenuOthersPreviewjson {
            path = BUFFOON_CONSTANTS.APP_URLS.PJ
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL(string:path)!)
    }


    // MARK: - Window Set Up Functions

    /**
     Create and display the information text label. This is done programmatically
     because we're using an NSAttributedString rather than a plain string.
     */
    private func setInfoText() {

        // Set the attributes
        let bodyAtts: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0),
            .foregroundColor: NSColor.labelColor
        ]

        let boldAtts : [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13.0, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]

        let infoText: NSMutableAttributedString = NSMutableAttributedString(string: "You need only run this app once, to register its YAML Previewer and YAML Thumbnailer application extensions with macOS. You can then manage these extensions in ", attributes: bodyAtts)
        let boldText: NSAttributedString = NSAttributedString(string: "System Settings > Extensions > Quick Look", attributes: boldAtts)
        infoText.append(boldText)
        infoText.append(NSAttributedString(string: ".\n\nCases where previews cannot be rendered can usually be resolved by logging out of your Mac, logging in again and running this app once more.", attributes: bodyAtts))
        self.infoLabel.attributedStringValue = infoText
    }

}
