/*
 *  Common.swift
 *  PreviewYaml
 *  Code common to Yaml Previewer and Yaml Thumbnailer
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2021 Tony Smith. All rights reserved.
 */

import Foundation
import Yaml
import AppKit


// Use defaults for some user-selectable values
private var keyColourIndex: Int = BUFFOON_CONSTANTS.CODE_COLOUR_INDEX
private var textFontIndex: Int = BUFFOON_CONSTANTS.CODE_FONT_INDEX
private var textSizeBase: CGFloat = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
private var doShowLightBackground: Bool = false
private let codeFonts: [String] = ["AndaleMono", "Courier", "Menlo-Regular", "Monaco"]
private var hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n", attributes: [.strikethroughStyle: NSUnderlineStyle.patternDot.rawValue, .strikethroughColor: NSColor.labelColor])
private var keyAtts: [NSAttributedString.Key:Any] = [
    NSAttributedString.Key.foregroundColor: getColour(keyColourIndex),
    NSAttributedString.Key.font: NSFont.init(name: codeFonts[textFontIndex], size: textSizeBase) as Any
]
private var valAtts: [NSAttributedString.Key:Any] = [
    NSAttributedString.Key.foregroundColor: (doShowLightBackground ? NSColor.black : NSColor.labelColor),
    NSAttributedString.Key.font: NSFont.init(name: codeFonts[textFontIndex], size: textSizeBase) as Any
]
private let newLine: NSAttributedString = NSAttributedString.init(string: "\n")


// MARK: Primary Function

func getAttributedString(_ yamlFileString: String, _ isThumbnail: Bool) -> NSAttributedString {

    // FROM 1.1.0
    // Use SwiftyMarkdown to render the input markdown as an NSAttributedString, which is returned
    // NOTE Set the font colour according to whether we're rendering a thumbail or a preview
    //      (thumbnails always rendered black on white; previews may be the opposite [dark mode])

    var renderedString: NSMutableAttributedString = NSMutableAttributedString()
    
    do {
        let yaml = try Yaml.load(yamlFileString)
        
        // Render the YAML to NSAttributedString
        if let yamlString = renderYaml(yaml, 0, false) {
            renderedString.append(yamlString)
        }
    }
    catch {
        // No YAML to render, or mis-formatted
        let errorString: NSMutableAttributedString = NSMutableAttributedString.init(string: "Could not render the YAML. It may be mis-formed.\n", attributes: keyAtts)
#if DEBUG
        errorString.append(NSMutableAttributedString.init(string: error.localizedDescription + "\n", attributes: keyAtts))
        errorString.append(NSMutableAttributedString.init(string: yamlFileString + "\n", attributes: valAtts))
#endif
        renderedString = errorString
    }
        
    return renderedString
}


// MARK: Yaml Functions

func renderYaml(_ part: Yaml, _ indent: Int, _ isKey: Bool) -> NSAttributedString? {
    
    // Render a supplied YAML sub-component ('part') to an NSAttributedString,
    // indenting as required, and using a different text format for keys.
    // This is called recursively as it drills down through YAML values.
    // Returns nil on error
    
    let returnString: NSMutableAttributedString = NSMutableAttributedString.init()
    
    switch (part) {
    case .array:
        if let value = part.array {
            // Iterate through array elements
            // NOTE A given element can be of any YAML type
            for i in 0..<value.count {
                if let yamlString = renderYaml(value[i], indent, false) {
                    returnString.append(yamlString)
                    returnString.append(newLine)
                }
            }
            return returnString
        }
    case .dictionary:
        if let dict = part.dictionary {
            // Iterate through the dictionary's keys and their values
            // NOTE A given value can be of any YAML type
            
            // Sort the dictionary's keys (ascending)
            // We assume all keys will be strings, ints, doubles or bools
            var keys: [Yaml] = Array(dict.keys)
            keys = keys.sorted(by: { (a, b) -> Bool in
                // Strings?
                if let a_s: String = a.string {
                    if let b_s: String = b.string {
                        return (a_s.lowercased() < b_s.lowercased())
                    }
                }
                
                // Ints?
                if let a_i: Int = a.int {
                    if let b_i: Int = b.int {
                        return (a_i < b_i)
                    }
                }
                
                // Doubles?
                if let a_d: Double = a.double {
                    if let b_d: Double = b.double {
                        return (a_d < b_d)
                    }
                }
                
                // Bools
                if let a_b: Bool = a.bool {
                    if let b_b: Bool = b.bool {
                        return (a_b && !b_b)
                    }
                }
                
                return false
            })
            
            // Iterate through the sorted keys array
            for i in 0..<keys.count {
                // Get the key:value pairs
                let key: Yaml = keys[i]
                let value: Yaml = dict[key] ?? ""
                
                // Render the key
                if let yamlString = renderYaml(key, indent, true) {
                    returnString.append(yamlString)
                }
                
                // If the value is a collection, we drop to the next line and indent
                var valueIndent = 0
                if value.array != nil || value.dictionary != nil {
                    valueIndent = indent + BUFFOON_CONSTANTS.YAML_INDENT
                    returnString.append(newLine)
                }
                
                // Render the key's value
                if let yamlString = renderYaml(value, valueIndent, false) {
                    returnString.append(yamlString)
                }
                
                // Hack: if this is the root dictionary, add a blank line between keys
                if (indent == 0) {
                    returnString.append(newLine)
                }
            }
            return returnString
        }
    case .string:
        if let keyOrValue = part.string {
            returnString.append(getIndentedString(keyOrValue, indent))
            returnString.addAttributes((isKey ? keyAtts : valAtts),
                                       range: NSMakeRange(0, returnString.length))

            if (isKey) {
                returnString.append(NSAttributedString.init(string: " "))
            }

            return returnString
        }
    default:
        // Place all the scalar values here
        // TODO These *may* be keys too, so we need to check that
        if let val = part.int {
            returnString.append(getIndentedString("\(val)", indent))
        } else if let val = part.bool {
            returnString.append(getIndentedString((val ? "true" : "false"), indent))
        } else if let val = part.double {
            returnString.append(getIndentedString("\(val)", indent))
        }
        
        returnString.addAttributes(valAtts, range: NSMakeRange(0, returnString.length))
        return returnString
    }
    
    // Error condition
    return nil
}


func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {
    
    // Return a space-prefix NSAttributedString where 'indent' specifies
    // the number of spaces to add
    
    let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
    let spaces = "                                                     "
    let spaceString = String(spaces.suffix(indent))
    let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
    indentedString.append(NSAttributedString.init(string: spaceString))
    indentedString.append(NSAttributedString.init(string: trimmedString))
    return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
}


// MARK: Formatting Functions

func setBaseValues(_ isThumbnail: Bool) {

    // Set common base style values for the markdown render

    // The suite name is the app group name, set in each extension's entitlements, and the host app's
    if let defaults = UserDefaults(suiteName: MNU_SECRETS.PID + ".suite.previewyaml") {
        defaults.synchronize()
        textSizeBase = CGFloat(isThumbnail
                              ? defaults.float(forKey: "com-bps-previewyaml-thumb-font-size")
                              : defaults.float(forKey: "com-bps-previewyaml-base-font-size"))
        keyColourIndex = defaults.integer(forKey: "com-bps-previewyaml-code-colour-index")
        textFontIndex = defaults.integer(forKey: "com-bps-previewyaml-code-font-index")
        doShowLightBackground = defaults.bool(forKey: "com-bps-previewyaml-do-use-light")
    }

    // Just in case the above block reads in zero values
    // NOTE The other valyes CAN be zero
    if textSizeBase < 1.0 || textSizeBase > 28.0 {
        textSizeBase = CGFloat(isThumbnail ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE : BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
    }

    // Set the YAML key:value fonts and sizes
    keyAtts = [
        NSAttributedString.Key.foregroundColor: getColour(keyColourIndex),
        NSAttributedString.Key.font: NSFont.init(name: codeFonts[textFontIndex], size: textSizeBase) as Any
    ]
    
    valAtts = [
        NSAttributedString.Key.foregroundColor: (doShowLightBackground ? NSColor.black : NSColor.labelColor),
        NSAttributedString.Key.font: NSFont.init(name: codeFonts[textFontIndex], size: textSizeBase) as Any
    ]
    
    hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                            attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                         .strikethroughColor: (doShowLightBackground ? NSColor.black : NSColor.white)])

}


func getColour(_ index: Int) -> NSColor {

    // Return the colour from the selection

    switch index {
        case 0:
            return NSColor.systemPurple
        case 1:
            return NSColor.systemBlue
        case 2:
            return NSColor.systemRed
        case 3:
            return NSColor.systemGreen
        case 4:
            return NSColor.systemOrange
        case 5:
            return NSColor.systemPink
        case 6:
            return NSColor.systemTeal
        case 7:
            return NSColor.systemBrown
        case 8:
            return NSColor.systemYellow
        case 9:
            return NSColor.systemIndigo
        default:
            return NSColor.systemGray
    }
}
