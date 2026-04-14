/*
 *  AppDelegateWhatsNew.swift
 *  PreviewApps
 *
 *  Extension for AppDelegate providing What's New sheet functionality.
 *
 *  Created by Tony Smith on 10/10/2024.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import AppKit


extension AppDelegate {

    /**
     Show the **What's New** sheet.

     If we're on a new, non-patch version, of the user has explicitly
     asked to see it with a menu click See if we're coming from a menu click
     (`sender != self`) or directly in code from *appDidFinishLoading()*
     (`sender == self`)

     - Parameters:
        - sender: The source of the action.
     */
    @IBAction
    internal func doShowWhatsNew(_ sender: Any) {

        // See if we're coming from a menu click (sender != self) or
        // directly in code from 'appDidFinishLoading()' (sender == self)
        var doShowSheet: Bool = type(of: self) != type(of: sender)

        if !doShowSheet {
            // We are coming from the 'appDidFinishLoading()' so check
            // if we need to show the sheet by the checking the prefs
            if let defaults = UserDefaults(suiteName: self.appSuiteName) {
                // Get the version-specific preference key
                let key: String = BUFFOON_CONSTANTS.PREFS_IDS.WHATS_NEW + getVersion()
                doShowSheet = defaults.bool(forKey: key)
            }
        }

        // Configure and show the sheet
        if doShowSheet {
            // FROM 1.0.3
            // Hide menus we don't want used while panel is open
            hidePanelGenerators()

            // First, get the folder path
            let htmlFolderPath = Bundle.main.resourcePath! + "/new"

            // Set up the WKWebBiew: no elasticity, horizontal scroller
            self.whatsNewWebView.enclosingScrollView?.hasHorizontalScroller = false
            self.whatsNewWebView.enclosingScrollView?.horizontalScrollElasticity = .none
            self.whatsNewWebView.enclosingScrollView?.verticalScrollElasticity = .none
            self.whatsNewWebView.configuration.suppressesIncrementalRendering = true
            self.whatsNewWebView.configuration.limitsNavigationsToAppBoundDomains = true

            // Just in case, make sure we can load the file
            if FileManager.default.fileExists(atPath: htmlFolderPath) {
                let htmlFileURL = URL(fileURLWithPath: htmlFolderPath + "/new.html")
                let htmlFolderURL = URL(fileURLWithPath: htmlFolderPath)
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
    @IBAction
    internal func doCloseWhatsNew(_ sender: Any) {

        // Close the sheet
        self.window.endSheet(self.whatsNewWindow)

        // Scroll the web view back to the top
        self.whatsNewWebView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)

        // Set this version's preference
        if let defaults = UserDefaults(suiteName: self.appSuiteName) {
            let key: String = BUFFOON_CONSTANTS.PREFS_IDS.WHATS_NEW + getVersion()
#if DEBUG
            print("\(key) reset back to true")
            defaults.setValue(true, forKey: key)
#else
            defaults.setValue(false, forKey: key)
#endif
        }

        // FROM 1.0.3
        // Restore menus
        showPanelGenerators()
    }

}
