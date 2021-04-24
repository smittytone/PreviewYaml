/*
 *  AppDelegate.swift
 *  PreviewYaml
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */

import Cocoa
import CoreServices
import WebKit


@main
class AppDelegate: NSObject,
                   NSApplicationDelegate,
                   URLSessionDelegate,
                   URLSessionDataDelegate,
                   WKNavigationDelegate {

    // MARK:- Class UI Properies
    // Menu Items
    @IBOutlet var helpMenuPY: NSMenuItem!
    @IBOutlet var helpMenuAcknowledgments: NSMenuItem!
    @IBOutlet var helpAppStoreRating: NSMenuItem!
    @IBOutlet var helpMenuYaml: NSMenuItem!
    
    // Panel Items
    @IBOutlet var versionLabel: NSTextField!
    
    // Windows
    @IBOutlet var window: NSWindow!

    // Report Sheet
    @IBOutlet weak var reportWindow: NSWindow!
    @IBOutlet weak var feedbackText: NSTextField!
    @IBOutlet weak var connectionProgress: NSProgressIndicator!

    // Preferences Sheet
    @IBOutlet weak var preferencesWindow: NSWindow!
    @IBOutlet weak var fontSizeSlider: NSSlider!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var useLightCheckbox: NSButton!
    @IBOutlet weak var doShowTagCheckbox: NSButton!
    @IBOutlet weak var codeFontPopup: NSPopUpButton!
    @IBOutlet weak var codeColourPopup: NSPopUpButton!

    // What's New Sheet
    @IBOutlet weak var whatsNewWindow: NSWindow!
    @IBOutlet weak var whatsNewWebView: WKWebView!

    // MARK:- Private Properies
    private var feedbackTask: URLSessionTask? = nil
    private var previewFontSize: CGFloat = 16.0
    private var previewCodeColour: Int = 1
    private var previewLinkColour: Int = 2
    private var previewCodeFont: Int = 0
    private var doShowLightBackground: Bool = false
    private var doShowTag: Bool = false
    private var localYamlUTI: String = "N/A"
    private var whatsNewNav: WKNavigation? = nil
    
    
    // MARK:- Class Lifecycle Functions

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Set application group-level defaults
        registerPreferences()
        
        // Get the local UTI for markdown files
        self.localYamlUTI = getLocalYamlUTI()

        // Add the version number to the panel
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        versionLabel.stringValue = "Version \(version) (\(build))"

        // Disable the Help menu Spotlight features
        let dummyHelpMenu: NSMenu = NSMenu.init(title: "Dummy")
        let theApp = NSApplication.shared
        theApp.helpMenu = dummyHelpMenu
        
        // Centre window and display
        self.window.center()
        self.window.makeKeyAndOrderFront(self)

        // Show 'What's New' if we need to
        // (and set up the WKWebBiew: no elasticity, horizontal scroller)
        // NOTE Has to take place at the end of the function
        self.whatsNewWebView.enclosingScrollView?.hasHorizontalScroller = false
        self.whatsNewWebView.enclosingScrollView?.horizontalScrollElasticity = .none
        self.whatsNewWebView.enclosingScrollView?.verticalScrollElasticity = .none
        doShowWhatsNew(self)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        // When the main window closed, shut down the app
        return true
    }


    // MARK:- Action Functions

    @IBAction func doClose(_ sender: Any) {
        
        // Reset the QL thumbnail cache... just in case
        _ = runProcess(app: "/usr/bin/qlmanage", with: ["-r", "cache"])
        
        // Close the window... which will trigger an app closure
        self.window.close()
    }
    
    
    @IBAction @objc func doShowSites(sender: Any) {
        
        // Open the websites for contributors
        let item: NSMenuItem = sender as! NSMenuItem
        var path: String = "https://smittytone.net/previewmarkdown/index.html"

        if item == self.helpMenuAcknowledgments {
            path += "#acknowledgements"
        } else if item == self.helpAppStoreRating {
            path = "https://apps.apple.com/gb/app/previewmarkdown/id1492280469?action=write-review"
        } else if item == self.helpMenuYaml {
            path = "https://github.com/behrang/YamlSwift"
        } else if item == self.helpMenuPY {
            path += "#how-to-use-previewmarkdown"
        }
        
        // Open the selected website
        NSWorkspace.shared.open(URL.init(string:path)!)
    }


    @IBAction func openSysPrefs(sender: Any) {

        // Open the System Preferences app at the Extensions pane
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }


    @IBAction @objc func showFeedbackWindow(sender: Any?) {

        // Display a window in which the user can submit feedback

        // Reset the UI
        self.connectionProgress.stopAnimation(self)
        self.feedbackText.stringValue = ""

        // Present the window
        self.window.beginSheet(self.reportWindow, completionHandler: nil)
    }


    @IBAction @objc func doCancelReportWindow(sender: Any) {

        // User has clicked 'Cancel', so just close the sheet

        self.connectionProgress.stopAnimation(self)
        self.window.endSheet(self.reportWindow)
    }


    @IBAction @objc func doSendFeedback(sender: Any) {

        // User clicked 'Send' so get the message (if there is one) from the text field and send it
        let feedback: String = self.feedbackText.stringValue

        if feedback.count > 0 {
            // Start the connection indicator if it's not already visible
            self.connectionProgress.startAnimation(self)
            
            self.feedbackTask = sendFeedback(feedback)
            
            if self.feedbackTask != nil {
                // We have a valid URL Session Task, so start it to send
                self.feedbackTask!.resume()
            } else {
                // Report the error
                sendFeedbackError()
            }
        } else {
            // No feedback, so close the sheet
            self.window.endSheet(self.reportWindow)
        }
        
        // NOTE sheet closes asynchronously unless there was no feedback to send
    }
    
    
    func sendFeedback(_ feedback: String) -> URLSessionTask? {
        
        // Send the string etc.
        // First get the data we need to build the user agent string
        let userAgent: String = getUserAgentForFeedback()
        
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
        if let url: URL = URL.init(string: MNU_SECRETS.ADDRESS.A + MNU_SECRETS.ADDRESS.B) {
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


    @IBAction func doShowPreferences(sender: Any) {

        // FROM 1.2.0
        // Display the Preferences... sheet

        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewyaml") {
            self.previewFontSize = CGFloat(defaults.float(forKey: "com-bps-previewyaml-base-font-size"))
            self.previewCodeColour = defaults.integer(forKey: "com-bps-previewyaml-code-colour-index")
            self.previewCodeFont = defaults.integer(forKey: "com-bps-previewyaml-code-font-index")
            self.doShowLightBackground = defaults.bool(forKey: "com-bps-previewyaml-do-use-light")
            self.doShowTag = defaults.bool(forKey: "com-bps-previewyaml-do-show-tag")
        }

        // Get the menu item index from the stored value
        // NOTE The other values are currently stored as indexes -- should this be the same?
        //let options: [CGFloat] = [10.0, 12.0, 14.0, 16.0, 18.0, 24.0, 28.0]
        let index: Int = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.lastIndex(of: self.previewFontSize) ?? 3
        self.fontSizeSlider.floatValue = Float(index)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
        self.codeColourPopup.selectItem(at: self.previewCodeColour)
        self.codeFontPopup.selectItem(at: self.previewCodeFont)
        self.useLightCheckbox.state = self.doShowLightBackground ? .on : .off
        self.doShowTagCheckbox.state = self.doShowTag ? .on : .off
        
        // Display the sheet
        self.window.beginSheet(self.preferencesWindow, completionHandler: nil)
    }


    @IBAction func doMoveSlider(sender: Any) {

        // FROM 1.2.0
        let index: Int = Int(self.fontSizeSlider.floatValue)
        self.fontSizeLabel.stringValue = "\(Int(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[index]))pt"
    }


    @IBAction func doClosePreferences(sender: Any) {

        // FROM 1.2.0
        // Close the Preferences... sheet

        self.window.endSheet(self.preferencesWindow)
    }


    @IBAction func doSavePreferences(sender: Any) {

        // FROM 1.2.0
        // Close the Preferences... sheet and save the prefs, if they have changed

        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewyaml") {
            if self.codeColourPopup.indexOfSelectedItem != self.previewCodeColour {
                defaults.setValue(self.codeColourPopup.indexOfSelectedItem,
                                  forKey: "com-bps-previewyaml-code-colour-index")
            }

            if self.codeFontPopup.indexOfSelectedItem != self.previewCodeFont {
                defaults.setValue(self.codeFontPopup.indexOfSelectedItem,
                                  forKey: "com-bps-previewyaml-code-font-index")
            }

            var state: Bool = self.useLightCheckbox.state == .on
            if self.doShowLightBackground != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewyaml-do-use-light")
            }

            state = self.doShowTagCheckbox.state == .on
            if self.doShowTag != state {
                defaults.setValue(state,
                                  forKey: "com-bps-previewyaml-do-show-tag")
            }

            let newValue: CGFloat = BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[Int(self.fontSizeSlider.floatValue)]
            if newValue != self.previewFontSize {
                defaults.setValue(newValue,
                                  forKey: "com-bps-previewyaml-base-font-size")
            }
            
            // Sync any changes
            defaults.synchronize()
        }

        // Remove the sheet now we have the data
        self.window.endSheet(self.preferencesWindow)
    }


    @IBAction func doShowWhatsNew(_ sender: Any) {

        // FROM 1.2.0
        // Show the 'What's New' sheet, if we're on a new, non-patch version
           
        // See if we're coming from a menu click (sender != self) or
        // directly in code from 'appDidFinishLoading()' (sender == self)
        var doShowSheet: Bool = type(of: self) != type(of: sender)
        
        if !doShowSheet {
            // We are coming from the 'appDidFinishLoading()' so check
            // if we need to show the sheet by the checking the prefs
            if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewyaml") {
                // Get the version-specific preference key
                let key: String = "com-bps-previewyaml-do-show-whats-new-" + getVersion()
                doShowSheet = defaults.bool(forKey: key)
            }
        }
      
        // Configure and show the sheet: first, get the folder path
        if doShowSheet {
            let htmlFolderPath = Bundle.main.resourcePath! + "/new"

            // Just in case, make sure we can load the file
            if FileManager.default.fileExists(atPath: htmlFolderPath) {
                let htmlFileURL = URL.init(fileURLWithPath: htmlFolderPath + "/new.html")
                let htmlFolderURL = URL.init(fileURLWithPath: htmlFolderPath)
                self.whatsNewNav = self.whatsNewWebView.loadFileURL(htmlFileURL, allowingReadAccessTo: htmlFolderURL)
            }
        }
    }


    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        // FROM 1.2.0
        // Asynchronously show the sheet once the HTML has loaded
        // (triggered by delegate method)

        if let nav = self.whatsNewNav {
            if nav == navigation {
                // Display the sheet
                self.window.beginSheet(self.whatsNewWindow, completionHandler: nil)
            }
        }
    }


    @IBAction func doCloseWhatsNew(_ sender: Any) {

        // FROM 1.2.0
        // Close the 'What's New' sheet, making sure we clear the preference flag for this minor version,
        // so that the sheet is not displayed next time the app is run (unless the version changes)

        // Close the sheet
        self.window.endSheet(self.whatsNewWindow)
        
        // Scroll the web view back to the top
        self.whatsNewWebView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)

        // Set this version's preference
        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewyaml") {
            let key: String = "com-bps-previewyaml-do-show-whats-new-" + getVersion()
            defaults.setValue(false, forKey: key)

            #if DEBUG
            print("\(key) reset back to true")
            defaults.setValue(true, forKey: key)
            #endif

            defaults.synchronize()
        }
    }


    @IBAction func doLogOut(_ sender: Any) {

        // FROM 1.2.0
        // Run a log out sequence if the user requests it

        let app: String = "/usr/bin/osascript"
        let args: [String] = ["-e", "tell application \"System Events\" to log out"]

        // Run the process
        // NOTE This time we wait for its conclusion
        let success = runProcess(app: app, with: (args.count > 0 ? args : []))
        if !success {
            // Log out request failed for some reason
            let alert: NSAlert = NSAlert.init()
            alert.messageText = "Log out request failed"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }


    func runProcess(app path: String, with args: [String]) -> Bool {

        // FROM 1.2.0
        // Generic task creation and run function

        let task: Process = Process()
        task.executableURL = URL.init(fileURLWithPath: path)
        task.arguments = args

        // Pipe out the output to avoid putting it in the log
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
        } catch {
            return false
        }

        // Block until the task has completed (short tasks ONLY)
        task.waitUntilExit()

        if !task.isRunning {
            if (task.terminationStatus != 0) {
                // Command failed -- collect the output if there is any
                let outputHandle = outputPipe.fileHandleForReading
                var outString: String = ""
                if let line = String(data: outputHandle.availableData, encoding: String.Encoding.utf8) {
                    outString = line
                }

                if outString.count > 0 {
                    print("\(outString)")
                } else {
                    print("Error", "Exit code \(task.terminationStatus)")
                }
                return false
            }
        }

        return true
    }


    // MARK: - URLSession Delegate Functions

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {

        // Some sort of connection error - report it
        self.connectionProgress.stopAnimation(self)
        sendFeedbackError()
    }


    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        // The operation to send the comment completed
        self.connectionProgress.stopAnimation(self)
        if let _ = error {
            // An error took place - report it
            sendFeedbackError()
        } else {
            // The comment was submitted successfully
            let alert: NSAlert = showAlert("Thanks For Your Feedback!",
                                           "Your comments have been received and we’ll take a look at them shortly.")
            alert.beginSheetModal(for: self.reportWindow) { (resp) in
                // Close the feedback window when the modal alert returns
                self.window.endSheet(self.reportWindow)
            }
        }
    }


    // MARK: - Misc Functions

    func sendFeedbackError() {

        // Present an error message specific to sending feedback
        // This is called from multiple locations: if the initial request can't be created,
        // there was a send failure, or a server error
        let alert: NSAlert = showAlert("Feedback Could Not Be Sent",
                                       "Unfortunately, your comments could not be send at this time. Please try again later.")
        alert.beginSheetModal(for: self.reportWindow,
                              completionHandler: nil)
        
    }


    func showAlert(_ head: String, _ message: String) -> NSAlert {

        // Generic alert presentation
        let alert: NSAlert = NSAlert()
        alert.messageText = head
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        return alert
    }


    func registerPreferences() {

        // Called by the app at launch to register its initial defaults

        if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewyaml") {
            // Check if each preference value exists -- set if it doesn't
            // Preview body font size, stored as a CGFloat
            // Default: 16.0
            let bodyFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-base-font-size")
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE),
                                  forKey: "com-bps-previewyaml-base-font-size")
            }

            // Thumbnail view base font size, stored as a CGFloat, not currently used
            // Default: 14.0
            let thumbFontSizeDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-thumb-font-size")
            if thumbFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE),
                                  forKey: "com-bps-previewyaml-thumb-font-size")
            }

            // Colour of code blocks in the preview, stored as in integer array index
            // Default: 0 (purple)
            let codeColourDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-code-colour-index")
            if codeColourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_COLOUR_INDEX,
                                  forKey: "com-bps-previewyaml-code-colour-index")
            }

            // Font for code blocks in the preview, stored as in integer array index
            // Default: 0 (Andale Mono)
            let codeFontDefault: Any? = defaults.object(forKey: "com-bps-previewyaml-code-font-index")
            if codeFontDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.CODE_FONT_INDEX,
                                  forKey: "com-bps-previewyaml-code-font-index")
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
                defaults.setValue(true,
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

            // Sync any additions
            defaults.synchronize()
        }

    }
    
    
    func getLocalYamlUTI() -> String {
        
        
        // This is not PII. It used solely for debugging purposes
        
        var localMarkdownUTI: String = "NONE"
        let samplePath = Bundle.main.resourcePath! + "/sample.yml"
        
        if FileManager.default.fileExists(atPath: samplePath) {
            // Create a URL reference to the sample file
            let sampleURL = URL.init(fileURLWithPath: samplePath)
            
            do {
                // Read back the UTI from the URL
                if let uti = try sampleURL.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
                    localMarkdownUTI = uti
                }
            } catch {
                // NOP
            }
        }
        
        return localMarkdownUTI
    }


    func getVersion() -> String {

        // FROM 1.2.0
        // Build a basic 'major.manor' version string for prefs usage

        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let parts: [String] = (version as NSString).components(separatedBy: ".")
        return parts[0] + "-" + parts[1]
    }
    
    
    func getDateForFeedback() -> String {

        // FROM 1.2.0
        // Refactor code out into separate function for clarity

        let date: Date = Date()
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter.string(from: date)
    }


    func getUserAgentForFeedback() -> String {

        // FROM 1.2.0
        // Refactor code out into separate function for clarity

        let sysVer: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let bundle: Bundle = Bundle.main
        let app: String = bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as! String
        let version: String = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(app)/\(version)-\(build) (Mac macOS \(sysVer.majorVersion).\(sysVer.minorVersion).\(sysVer.patchVersion))"
    }




}

