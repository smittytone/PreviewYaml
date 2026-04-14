/*
 *  AppDelegateMisc.swift
 *  PreviewYaml
 *  Extension for AppDelegate providing functionality used across PreviewApps.
 *
 *  These functions can be used by all PreviewApps
 *
 *  Created by Tony Smith on 10/04/20276.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit
import WebKit
import UniformTypeIdentifiers


extension AppDelegate {

    // MARK: - Alert Handler Functions

    /**
     Generic alert generator.

     - Parameters:
         - head:        The alert's title.
         - message:     The alert's message.
         - addOkButton: Should we add an OK button?
         - isCritical:  Should we make this a crirical alert

     - Returns: The NSAlert.
     */
    internal func makeAlert(_ head: String, _ message: String, _ addOkButton: Bool = true, _ isCritical: Bool = false) -> NSAlert {

        let alert = NSAlert()
        alert.messageText = head
        alert.informativeText = message

        if addOkButton {
            alert.addButton(withTitle: "OK")
        }

        if isCritical {
            alert.alertStyle = .critical
        }

        return alert
    }


    // MARK: - Support Functions

    /**
     Build a basic 'major.manor' version string for prefs usage.

     - Returns: The version string.
     */
    internal func getVersion() -> String {

        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let parts: [String] = (version as NSString).components(separatedBy: ".")
        return parts[0] + "-" + parts[1]
    }


    /**
     Disable all panel-opening menu items.
     */
    internal func hidePanelGenerators() {

        self.helpMenuReportBug.isEnabled = false
        self.helpMenuWhatsNew.isEnabled = false
        self.mainMenuSettings.isEnabled = false
    }


    /**
     Enable all panel-opening menu items.
     */
    internal func showPanelGenerators() {

        self.helpMenuReportBug.isEnabled = true
        self.helpMenuWhatsNew.isEnabled = true
        self.mainMenuSettings.isEnabled = true
    }


    // MARK: - WKWebNavigation Delegate Functions

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        // Asynchronously show the sheet once the HTML has loaded
        // (triggered by delegate method)

        if let nav = self.whatsNewNav {
            if nav == navigation {
                // Display the sheet
                // FROM 1.1.2 -- add timer to prevent 'white flash'
                Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { timer in
                    timer.invalidate()

                    // FROM 2.0.0 -- Use Swift Concurrency
                    Task { @MainActor in
                        self.window.beginSheet(self.whatsNewWindow, completionHandler: nil)
                    }
                }
            }
        }
    }


    // MARK: - NSWindowDelegate Functions

    /**
      Catch when the user clicks on the window's red close button.
     */
    func windowShouldClose(_ sender: NSWindow) -> Bool {

        if !checkFeedbackOnQuit() && !checkSettings() {
            // No unsaved settings or unsent feedback, so we're good to close
            return true
        }

        // Close mmanually
        // NOTE The above check will fail if there are settings changes and/or
        //      unsent feedback, in which case the following calls will trigger
        //      alerts
        closeBasics()
        closeSettings()
        return false
    }

}
