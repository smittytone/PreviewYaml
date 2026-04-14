/*
 *  AppDelegateFontHandling.swift
 *  PreviewApps
 *
 *  These functions can be used by all PreviewApps
 *
 *  Created by Tony Smith on 18/06/2021.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */


import Foundation
import Cocoa
import WebKit


extension AppDelegate {

    // MARK: - Font Management

    /**
     Build a list of available fonts.

     Should be called asynchronously. Two sets created: monospace fonts and regular fonts.
     Requires 'bodyFonts' and 'codeFonts' to be set as instance properties.
     Comment out either of these, as required.

     The final font lists each comprise pairs of strings: the font's PostScript name
     then its display name.
     */
    internal func asyncGetFonts() {

        var cf: [PMFont] = []
        let fm = NSFontManager.shared
        let families: [String] = fm.availableFontFamilies
        for family in families {
            // Remove known unwanted fonts
            if family.hasPrefix(".") || family == "Apple Braille" || family == "Apple Color Emoji" {
                continue
            }

            // For each family, examine its fonts for suitable ones
            if let fonts: [[Any]] = fm.availableMembers(ofFontFamily: family) {
                // This will hold a font family: individual fonts will be added to
                // the 'styles' array
                var familyRecord: PMFont = PMFont()
                familyRecord.displayName = family

                for font: [Any] in fonts {
                    var fontRecord: PMFont = PMFont()
                    fontRecord.postScriptName = font[0] as! String
                    fontRecord.styleName = font[1] as! String
                    fontRecord.traits = font[3] as! UInt

                    if familyRecord.styles == nil {
                        familyRecord.styles = []
                    }

                    familyRecord.styles!.append(fontRecord)
                }

                if familyRecord.styles != nil && familyRecord.styles!.count > 0 {
                    cf.append(familyRecord)
                }
            }
        }

        // All done, update the main stores and begin to load
        // settings (which immediately updates the UI, via `displaySettings()`,
        // which itself requires the font store to be populated
        // FROM 2.0.0 -- Use Swift Concurrency
        Task { @MainActor in
            // Run task on main thread (See notes in PreviewCode)
            self.fonts = cf
            self.loadSettings()
        }
    }


    /**
     Build and enable the font style popup.

     - Parameters:
        - styleName: The name of currently selected style, or nil to select the first one.
     */
    internal func setStylePopup(_ styleName: String? = nil) {

        if let selectedFamily: String = self.fontPopup.titleOfSelectedItem {
            self.stylePopup.removeAllItems()
            for family: PMFont in self.fonts {
                if selectedFamily == family.displayName {
                    if let styles: [PMFont] = family.styles {
                        self.stylePopup.isEnabled = true
                        for style: PMFont in styles {
                            self.stylePopup.addItem(withTitle: style.styleName)
                        }

                        if styleName != nil {
                            self.stylePopup.selectItem(withTitle: styleName!)
                        }
                    }
                }
            }
        }
    }


    /**
     Select the font popup using the stored PostScript name
     of the user's chosen font.

     - Parameters:
        - postScriptName: The PostScript name of the font.
     */
    internal func selectFontByPostScriptName(_ postScriptName: String) {

        for family: PMFont in self.fonts {
            if let styles: [PMFont] = family.styles {
                for style: PMFont in styles {
                    if style.postScriptName == postScriptName {
                        self.fontPopup.selectItem(withTitle: family.displayName)
                        setStylePopup(style.styleName)
                    }
                }
            }
        }
    }


    /**
     Get the PostScript name from the selected family and style.

     - Returns: The PostScript name as a string, or nil.
     */
    internal func getPostScriptName() -> String? {

        if let selectedFont: String = self.fontPopup.titleOfSelectedItem {
            let selectedStyle: Int = self.stylePopup.indexOfSelectedItem
            for family: PMFont in self.fonts {
                if family.displayName == selectedFont {
                    if let styles: [PMFont] = family.styles {
                        let font: PMFont = styles[selectedStyle]
                        return font.postScriptName
                    }
                }
            }
        }

        return nil
    }
}
