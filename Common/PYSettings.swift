/*
 *  PYSettings.swift
 *  PreviewApps
 *
 *  Created by Tony Smith on 08/10/2024.
 *  Copyright © 2026 Tony Smith. All rights reserved.
 */

import Foundation


/**
 Internal settings record structure.
 Values are pre-set to the app defaults.
 */

class PYSettings {

    var fontSize: CGFloat                   = CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE)
    var fontName: String                    = BUFFOON_CONSTANTS.BODY_FONT_NAME
    var doReverseMode: Bool                 = false
    var doIndentScalars: Bool               = false
    var showYamlMarks: Bool                 = true
    var showRawYamlOnError: Bool            = false
    var indentSize: Int                     = BUFFOON_CONSTANTS.PREVIEW_SIZE.INDENT

    var displayColours: [String: String]    = [
        BUFFOON_CONSTANTS.COLOUR_IDS.KEYS:      BUFFOON_CONSTANTS.HEX_COLOUR.KEYS,
        BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS:   BUFFOON_CONSTANTS.HEX_COLOUR.STRINGS,
        BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS:  BUFFOON_CONSTANTS.HEX_COLOUR.SPECIALS,
        BUFFOON_CONSTANTS.COLOUR_IDS.MARKS:     BUFFOON_CONSTANTS.HEX_COLOUR.MARKS
    ]

    /*
     ADVANCED SETTINGS
     */
    var previewMarginWidth: CGFloat         = BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH
    var previewWindowScale: CGFloat         = BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_L
    var thumbnailMatchFinderMode: Bool      = false

    /*
     NON-SAVE SETTINGS, FOR CONVENIENCE
     */
    var isThumbnail: Bool                   = false


    /**
     Populate the current settings value with those read from disk.
     */
    func loadSettings(_ suite: String) {

        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let defaults = UserDefaults(suiteName: suite) {
            self.fontSize = CGFloat(defaults.float(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE))
            self.fontName = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME) ?? BUFFOON_CONSTANTS.BODY_FONT_NAME

            self.doReverseMode = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            self.showYamlMarks = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARKS)
            self.showRawYamlOnError = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_RAW)
            self.doIndentScalars = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_INDENT_SCALARS)
            self.indentSize = defaults.integer(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_INDENT)

            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.KEYS] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_KEYS_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.KEYS
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_STRINGS_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.STRINGS
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SPECIALS_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.SPECIALS
            self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.MARKS] = defaults.string(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARKS_COLOUR)
            ?? BUFFOON_CONSTANTS.HEX_COLOUR.MARKS

            self.previewMarginWidth = CGFloat(defaults.double(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN_WIDTH))
            self.previewWindowScale = CGFloat(defaults.double(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE))
            self.thumbnailMatchFinderMode = defaults.bool(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_FINDER)
        }
    }


    /**
     Write Settings page state values to disk, but only those that have been changed.
     If this happens, also update the current settings store
     */
    func saveSettings(_ suite: String) {

        if let defaults = UserDefaults(suiteName: suite) {
            // TO-DO Test each on to see if the setting needs to be saved
            defaults.setValue(self.fontSize, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            defaults.setValue(self.fontName, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)

            defaults.setValue(self.doReverseMode, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            defaults.setValue(self.showYamlMarks, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARKS)
            defaults.setValue(self.showRawYamlOnError, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_RAW)
            defaults.setValue(self.doIndentScalars, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_INDENT_SCALARS)
            defaults.setValue(self.indentSize, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_INDENT)

            // For colours, the UI sets the keys prefixed `new_xxx` when the colour of category xxx
            // has changed. If there's no `new_xxx`, then category xxx's colour has not been changed
            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_KEYS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.KEYS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_KEYS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_KEYS_COLOUR)
            }

            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_STRINGS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_STRINGS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_STRINGS_COLOUR)
            }

            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_SPECIALS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_SPECIALS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SPECIALS_COLOUR)
            }

            if let newColour: String = self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_MARKS] {
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.MARKS] = newColour
                self.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.NEW_MARKS] = nil
                defaults.setValue(newColour, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARKS_COLOUR)
            }

            defaults.setValue(self.previewMarginWidth, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN_WIDTH)
            defaults.setValue(self.previewWindowScale, forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE)
            defaults.setValue(self.thumbnailMatchFinderMode, forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_FINDER)
        }
    }


    /**
     Configure the app's preferences with default values.
     */
    internal func registerSettings(_ suite: String, _ version: String) {

        // Check if each preference value exists -- set if it doesn't
        if let defaults = UserDefaults(suiteName: suite) {
            // Preview body font size, stored as a CGFloat
            // Default: 16.0
            let bodyFontSizeDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            if bodyFontSizeDefault == nil {
                defaults.setValue(CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE),
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_SIZE)
            }

            // Font for previews and thumbnails
            // Default: Menlo
            let fontName: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            if fontName == nil {
                defaults.setValue(BUFFOON_CONSTANTS.BODY_FONT_NAME,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_BODY_FONT_NAME)
            }

            // Use light background even in dark mode, stored as a bool
            // Default: false
            let useLightDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            if useLightDefault == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_USE_LIGHT)
            }

            // Should we show YAML marks?
            // Default: true
            let showFurniture: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARKS)
            if showFurniture == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_MARKS)
            }

            // Present malformed JSON on error?
            // Default: false
            let presentBadJson: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_RAW)
            if presentBadJson == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SHOW_RAW)
            }

            // Indent scalar values?
            // Default: false
            let indentScalars: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_INDENT_SCALARS)
            if indentScalars == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_INDENT_SCALARS)
            }

            // Record the preferred indent depth in spaces
            // Default: 8
            let indentDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_INDENT)
            if indentDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_SIZE.INDENT,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_YAML_INDENT)
            }

            // Show the What's New sheet
            // Default: true
            // This is a version-specific preference suffixed with, eg, '-2-3'. Once created
            // this will persist, but with each new major and/or minor version, we make a
            // new preference that will be read by 'doShowWhatsNew()' to see if the sheet
            // should be shown this run
            let key: String = BUFFOON_CONSTANTS.PREFS_IDS.WHATS_NEW + version
            let showNewDefault: Any? = defaults.object(forKey: key)
            if showNewDefault == nil {
                defaults.setValue(true, forKey: key)
            }

            // Colour of JSON keys in the preview, stored as a hex string
            // Default: #CA0D0E
            var colourDefault: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_KEYS_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.COLOUR_IDS.KEYS,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_KEYS_COLOUR)
            }

            // Colour of strings in the preview, stored as a hex string
            // Default: #FC6A5DFF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_STRINGS_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_STRINGS_COLOUR)
            }

            // Colour of special values (Bools, NULL, etc) in the preview, stored as a hex string
            // Default: #FC6A5DFF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SPECIALS_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_SPECIALS_COLOUR)
            }

            // Colour of JSON markers in the preview, stored as a hex string
            // Default: #0096FF
            colourDefault = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARKS_COLOUR)
            if colourDefault == nil {
                defaults.setValue(BUFFOON_CONSTANTS.COLOUR_IDS.MARKS,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARKS_COLOUR)
            }

            // ADVANCED - What margin size should we apply?
            let marginWidth: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN_WIDTH)
            if marginWidth == nil {
                defaults.setValue(BUFFOON_CONSTANTS.PREVIEW_SIZE.MARGIN_WIDTH,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_MARGIN_WIDTH)
            }

            // ADVANCED - What is the default preview window size multiplier?
            let winScale: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE)
            if winScale == nil {
                defaults.setValue(BUFFOON_CONSTANTS.SCALERS.WINDOW_SIZE_L,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.PREVIEW_WINDOW_SCALE)
            }

            // ADVANCED - Should we match thumbnail colours to the macOS mode?
            let matchFinder: Any? = defaults.object(forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_FINDER)
            if matchFinder == nil {
                defaults.setValue(false,
                                  forKey: BUFFOON_CONSTANTS.PREFS_IDS.THUMB_MATCH_FINDER)
            }
        }
    }
}
