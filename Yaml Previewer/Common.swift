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


// FROM 1.1.0
// Implement as a class
final class Common: NSObject {
    
    // MARK: - Public Properties
    
    var doShowLightBackground: Bool   = false
    var doShowTag: Bool               = true
    
    
    // MARK: - Private Properties
    
    private var doShowRawYaml: Bool   = false
    private var doIndentScalars: Bool = false
    private var yamlIndent: Int       = BUFFOON_CONSTANTS.YAML_INDENT
    
    // YAML string attributes...
    private var keyAtts: [NSAttributedString.Key: Any] = [:]
    private var valAtts: [NSAttributedString.Key: Any] = [:]
    
    // String artifacts...
    private var hr: NSAttributedString      = NSAttributedString.init(string: "")
    private var newLine: NSAttributedString = NSAttributedString.init(string: "")


    // MARK:- Lifecycle Functions
    
    init(_ isThumbnail: Bool) {
        
        super.init()
        
        var fontBaseSize: CGFloat       = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        var fontBaseName: String        = BUFFOON_CONSTANTS.CODE_FONT_NAME
        var codeColour: String          = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        
        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let prefs = UserDefaults(suiteName: MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME) {
            self.doIndentScalars       = prefs.bool(forKey: "com-bps-previewyaml-do-indent-scalars")
            self.doShowRawYaml         = prefs.bool(forKey: "com-bps-previewyaml-show-bad-yaml")
            self.doShowLightBackground = prefs.bool(forKey: "com-bps-previewyaml-do-use-light")
            self.doShowTag             = prefs.bool(forKey: "com-bps-previewyaml-do-show-tag")
            self.yamlIndent            = isThumbnail ? 2 : prefs.integer(forKey: "com-bps-previewyaml-yaml-indent")
            
            fontBaseSize = CGFloat(isThumbnail
                                            ? prefs.float(forKey: "com-bps-previewyaml-thumb-font-size")
                                            : prefs.float(forKey: "com-bps-previewyaml-base-font-size"))
            
            // FROM 1.1.0
            fontBaseName          = prefs.string(forKey: "com-bps-previewyaml-base-font-name") ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            codeColour            = prefs.string(forKey: "com-bps-previewyaml-code-colour-hex") ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        }
        
        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if fontBaseSize < CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[0]) ||
            fontBaseSize > CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.count - 1]) {
            fontBaseSize = CGFloat(isThumbnail ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE : BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        }

        // Set the YAML key:value fonts and sizes
        var font: NSFont
        if let chosenFont: NSFont = NSFont.init(name: fontBaseName, size: fontBaseSize) {
            font = chosenFont
        } else {
            font = NSFont.systemFont(ofSize: fontBaseSize)
        }
        
        // Set up the attributed string components we may use during rendering
        self.keyAtts = [
            .foregroundColor: NSColor.hexToColour(codeColour),
            .font: font
        ]
        
        self.valAtts = [
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.labelColor),
            .font: font
        ]
        
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.white)])
        
        self.newLine = NSAttributedString.init(string: "\n",
                                               attributes: valAtts)
    }
    
    
    // MARK:- The Primary Function

    /**
     Use YamlSwift to render the input YAML as an NSAttributedString.

     - Parameters:
        - yamlFileString: The raw YAML code.

     - Returns: The rendered source as an NSAttributedString.
     */
    func getAttributedString(_ yamlFileString: String) -> NSAttributedString {

        // Set up the base string
        var renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                       attributes: self.valAtts)
        
        do {
            // Parse the YAML data,
            // first fixing any .NAN, +/-.INF in the file
            // let processed = fixNan(yamlFileString)
            let yaml = try Yaml.loadMultiple(yamlFileString)
            
            // Render the YAML to NSAttributedString
            for i in 0..<yaml.count {
                if let yamlString = renderYaml(yaml[i], 0, false) {
                    if i > 0 {
                        renderedString.append(hr)
                    }
                    renderedString.append(yamlString)
                }
            }
            
            // Just in case...
            if renderedString.length == 0 {
                renderedString = NSMutableAttributedString.init(string: "Could not render the YAML.\n",
                                                                attributes: self.keyAtts)
            }
        } catch {
            // No YAML to render, or the YAML was mis-formatted
            // Get the error as reported by YamlSwift
            let yamlErr: Yaml.ResultError = error as! Yaml.ResultError
            var yamlErrString: String
            switch(yamlErr) {
                case .message(let s):
                    yamlErrString = s ?? "unknown"
            }

            // Assemble the error string
            let errorString: NSMutableAttributedString = NSMutableAttributedString.init(string: "Could not render the YAML. Error: " + yamlErrString,
                                                                                        attributes: self.keyAtts)

            // Should we include the raw text?
            // At least the user can see the data this way
            if self.doShowRawYaml {
                errorString.append(self.hr)
                errorString.append(NSMutableAttributedString.init(string: yamlFileString + "\n",
                                                                  attributes: self.valAtts))
            }

            renderedString = errorString
        }
        
        return renderedString as NSAttributedString
    }


    // MARK:- Yaml Functions

    /**
     Render a supplied YAML sub-component ('part') to an NSAttributedString.

     Indents the value as required.

     - Parameters:
        - part:   A partial Yaml object.
        - indent: The number of indent spaces to add.
        - isKey:  Is the Yaml part a key?

     - Returns: The rendered string as an NSAttributedString, or nil on error.
     */
    func renderYaml(_ part: Yaml, _ indent: Int, _ isKey: Bool) -> NSAttributedString? {
        
        // Set up the base string
        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: valAtts)
        
        switch (part) {
        case .array:
            if let value = part.array {
                // Iterate through array elements
                // NOTE A given element can be of any YAML type
                for i in 0..<value.count {
                    if let yamlString = renderYaml(value[i], indent, false) {
                        // Apply a prefix to separate array and dictionary elements from a
                        // previous one -- so apply to all but the first item
                        if i > 0 && (value[i].array != nil || value[i].dictionary != nil) {
                            returnString.append(self.newLine)
                        }
                        
                        // Add the element itself
                        returnString.append(yamlString)
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
                    // Prefix root-level key:value pairs after the first with a new line
                    if indent == 0 && i > 0 {
                        returnString.append(self.newLine)
                    }
                    
                    // Get the key:value pairs
                    let key: Yaml = keys[i]
                    let value: Yaml = dict[key] ?? ""
                    
                    // Render the key
                    if let yamlString = renderYaml(key, indent, true) {
                        returnString.append(yamlString)
                    }
                    
                    // If the value is a collection, we drop to the next line and indent
                    var valueIndent: Int = 0
                    if value.array != nil || value.dictionary != nil || self.doIndentScalars {
                        valueIndent = indent + self.yamlIndent
                        returnString.append(self.newLine)
                    }
                    
                    // Render the key's value
                    if let yamlString = renderYaml(value, valueIndent, false) {
                        returnString.append(yamlString)
                    }
                }
                
                return returnString
            }
        case .string:
            if let keyOrValue = part.string {
                let parts: [String] = keyOrValue.components(separatedBy: "\n")
                if parts.count > 2 {
                    for i in 0..<parts.count {
                        let part: String = parts[i]
                        returnString.append(getIndentedString(part + (i < parts.count - 2 ? "\n" : ""), indent))
                    }
                } else {
                    returnString.append(getIndentedString(keyOrValue, indent))
                }

                returnString.setAttributes((isKey ? self.keyAtts : self.valAtts),
                                           range: NSMakeRange(0, returnString.length))
                returnString.append(isKey ? NSAttributedString.init(string: " ", attributes: self.valAtts) : self.newLine)
                return returnString
            }
        case .null:
            let valString: String = isKey ? "NULL KEY" : "NULL VALUE"
            returnString.append(getIndentedString(valString, indent))
            returnString.setAttributes(self.valAtts,
                                       range: NSMakeRange(0, returnString.length))
            returnString.append(isKey ? NSAttributedString.init(string: " ", attributes: self.valAtts) : self.newLine)
            return returnString
        default:
            // Place all the scalar values here
            // TODO These *may* be keys too, so we need to check that
            var valString: String = ""
            
            if let val = part.int {
                valString = "\(val)\n"
            } else if let val = part.double {
                valString = "\(val)\n"
            } else if let val = part.bool {
                valString = val ? "TRUE\n" : "FALSE\n"
            } else {
                valString = "UNKNOWN\n"
            }
            
            returnString.append(getIndentedString(valString, indent))
            returnString.setAttributes((isKey ? self.keyAtts : self.valAtts),
                                       range: NSMakeRange(0, returnString.length))
            return returnString
        }
        
        // Error condition
        return nil
    }


    /**
     Return a space-prefix NSAttributedString.

     - Parameters:
        - baseString: The string to be indented.
        - indent:     The number of indent spaces to add.

     - Returns: The indented string as an NSAttributedString.
     */
    func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {
        
        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaces = "                                                     "
        let spaceString = String(spaces.suffix(indent))
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString))
        indentedString.append(NSAttributedString.init(string: trimmedString))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }


    // MARK: - EXPERIMENTAL

    /**
     Attempt to trap and fix .NaN, -.INF and .INF, which give YamlSwift trouble.

     - Parameters:
        - yamlString: The YAML file contents.

     - Returns: The corrected YAML content.
     */
    func fixNan(_ yamlString: String) -> String {
        
        let regexes = [#"-\.(inf|Inf|INF)+"#, #"\.(inf|Inf|INF)+"#, #"\.(nan|NaN|NAN)+"#]
        let unfixedlines = yamlString.components(separatedBy: CharacterSet.newlines)
        var fixedString: String = ""
        
        // Run through all the YAML file's lines
        for i in 0..<unfixedlines.count {
            // Look for a pattern on the current line
            var count: Int = 0
            var line: String = unfixedlines[i]
            
            for regex in regexes {
                if let itemRange: Range = line.range(of: regex, options: .regularExpression) {
                    // Set the symbol based on the current value of 'count'
                    // Can make this more Swift-y with an enum
                    var symbol = ""
                    switch(count) {
                    case 0:
                        symbol = "\"-INF\""
                    case 1:
                        symbol = "\"+INF\""
                    default:
                        symbol = "\"NAN\""
                    }
                    
                    // Swap out the originl symbol for a string version
                    // (which doesn't cause a crash YamlString crash)
                    line = line.replacingCharacters(in: itemRange, with: symbol)
                    break;
                }
                
                // Move to next symbol
                count += 1
            }
            
            // Compose the return string
            fixedString += (line + "\n")
        }
        
        // Send the updated string back
        return fixedString
    }

}
