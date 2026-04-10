/*
 *  Common.swift
 *  PreviewYaml
 *  Code common to Yaml Previewer and Yaml Thumbnailer
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Foundation
import Yaml
import AppKit
import Yams


// FROM 1.1.0
// Implement as a class
final class Common: NSObject {

    // MARK: - Definitions

    enum AttributeType {
        case Key
        case Scalar
        case String
        case Special
        case Comment
    }


    // MARK: - Public Properties
    
    var doShowLightBackground: Bool   = false
    var doShowTag: Bool               = true

    
    // MARK: - Private Properties
    
    private var doShowRawYaml: Bool   = false
    private var doIndentScalars: Bool = false
    private var yamlIndent: Int       = BUFFOON_CONSTANTS.YAML_INDENT
    // FROM 1.1.5
    private var renderThumbnail: Bool = false
    private var renderDone: Bool      = false
    private var renderLineCount: Int  = 0
    // FROM 1.2.0
    private var renderColons: Bool    = false
    private var sortKeys: Bool        = true
    // FROM
    private var extraInset: Int       = 0

    // YAML string attributes...
    private var keyAttributes: [NSAttributedString.Key: Any] = [:]
    private var scalarAttributes: [NSAttributedString.Key: Any] = [:]
    // FROM 1.2.0
    private var specialAttributes: [NSAttributedString.Key: Any] = [:]
    private var stringAttributes: [NSAttributedString.Key: Any] = [:]

    // String artifacts...
    private var hr: NSAttributedString = NSAttributedString.init(string: "")
    private var cr: NSAttributedString = NSAttributedString.init(string: "")

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions
    
    init(_ isThumbnail: Bool) {
        
        super.init()
        
        // FROM 1.1.5
        self.renderThumbnail        = isThumbnail
        
        var fontSize: CGFloat       = CGFloat(BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        var fontName: String        = BUFFOON_CONSTANTS.CODE_FONT_NAME
        var keyColour: String       = BUFFOON_CONSTANTS.CODE_COLOUR_HEX
        // FROM 1.2.0
        var stringColour: String    = BUFFOON_CONSTANTS.STRING_COLOUR_HEX
        var specialColour: String   = BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX

        // The suite name is the app group name, set in each extension's entitlements, and the host app's
        if let prefs = UserDefaults(suiteName: self.appSuiteName) {
            self.doIndentScalars       = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SCALARS)
            self.doShowRawYaml         = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BAD)
            self.doShowLightBackground = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.USE_LIGHT)
            self.doShowTag             = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.TAG)
            self.yamlIndent            = isThumbnail ? 2 : prefs.integer(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.INDENT)
            // FROM 1.2.0
            self.sortKeys              = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SORT)
            self.renderColons          = prefs.bool(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.COLON)

            fontSize = CGFloat(isThumbnail
                               ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE
                               : prefs.float(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.BODY_SIZE))
            
            // FROM 1.1.0
            fontName        = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_FONT) ?? BUFFOON_CONSTANTS.CODE_FONT_NAME
            keyColour       = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.CODE_COLOUR) ?? BUFFOON_CONSTANTS.CODE_COLOUR_HEX
            // FROM 1.2.0
            stringColour    = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.STRING_COLOUR) ?? BUFFOON_CONSTANTS.STRING_COLOUR_HEX
            specialColour   = prefs.string(forKey: BUFFOON_CONSTANTS.PREFS_KEYS.SPECIAL_COLOUR) ?? BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX
        }
        
        // Just in case the above block reads in zero values
        // NOTE The other values CAN be zero
        if fontSize < CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[0]) ||
            fontSize > CGFloat(BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.FONT_SIZE_OPTIONS.count - 1]) {
            fontSize = CGFloat(isThumbnail ? BUFFOON_CONSTANTS.BASE_THUMB_FONT_SIZE : BUFFOON_CONSTANTS.BASE_PREVIEW_FONT_SIZE)
        }

        // Set the YAML key:value fonts and sizes
        var font: NSFont
        if let chosenFont: NSFont = NSFont.init(name: fontName, size: fontSize) {
            font = chosenFont
        } else {
            font = NSFont.systemFont(ofSize: fontSize)
        }
        
        // Set up the attributed string components we may use during rendering
        self.keyAttributes = [
            .foregroundColor: NSColor.hexToColour(keyColour),
            .font: font
        ]
        
        self.scalarAttributes = [
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.labelColor),
            .font: font
        ]

        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.labelColor)])
        
        self.cr = NSAttributedString.init(string: "\n",
                                          attributes: self.scalarAttributes)
        
        // FROM 1.2.0
        self.specialAttributes = [
            .foregroundColor: (isThumbnail || self.doShowLightBackground ? NSColor.black : NSColor.hexToColour(specialColour)),
            .font: font
        ]
        
        self.stringAttributes = [
            .foregroundColor: (isThumbnail ? NSColor.black : NSColor.hexToColour(stringColour)),
            .font: font
        ]
    }
    
    
    /**
     Update certain style variables on a UI mode switch.

     This is used by render demo app.
     */
    func resetStylesOnModeChange() {
        
        // Set up the attributed string components we may use during rendering
        self.hr = NSAttributedString(string: "\n\u{00A0}\u{0009}\u{00A0}\n\n",
                                     attributes: [.strikethroughStyle: NSUnderlineStyle.thick.rawValue,
                                                  .strikethroughColor: self.doShowLightBackground ? NSColor.black : NSColor.labelColor])

        self.scalarAttributes[.foregroundColor]  = self.doShowLightBackground ? NSColor.black : NSColor.labelColor
        self.specialAttributes[.foregroundColor] = self.doShowLightBackground ? NSColor.black : NSColor.hexToColour(BUFFOON_CONSTANTS.SPECIAL_COLOUR_HEX)
    }


    // MARK: - The Primary Function

    /**
     Use YamlSwift to render the input YAML as an NSAttributedString.

     - Parameters:
        - yamlFileString: The raw YAML code.

     - Returns: The rendered source as an NSAttributedString.
     */
    func getAttributedString(_ yamlFileString: String) -> NSAttributedString {

        // Set up the base string
        var renderedString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        // FROM 1.1.5
        self.renderLineCount = 0
        self.renderDone = false

        renderedString.append(prettyPrintYAML(yamlFileString))
        return renderedString
        /*

        // Parse the YAML data
        do {
            // First fix any .NAN, +/-.INF in the file
            let processed = fixNan(yamlFileString)

            // NOTE The following call takes time on large files
            // TODO Optimise it
            //let yaml = try Yaml.loadMultiple(processed)


            /*
            if let yaml = try Yams.load(yaml: processed) as? [String: Any] {
                // Document base is a mapping
                if let yamlString = processYamlDict(yaml) {
                    renderedString.append(yamlString)
                }
            } else if let yaml = try Yams.load(yaml: processed) as? [Any] {
                // Document base is a sequence
                if let yamlString = processYamlArray(yaml) {
                    renderedString.append(yamlString)
                }
            }
            */

            var yamlDocs: [(Bool, Any)] = []
            for item in try Yams.load_all(yaml: processed) {
                if let validItem: [String: Any] = item as? [String: Any] {
                    yamlDocs.append((true, validItem))
                } else if let validItem: [ Any] = item as? [Any] {
                    yamlDocs.append((false, validItem))
                }
            }

            for (i, yamlDoc) in yamlDocs.enumerated() {
                if yamlDoc.0 {
                    // Document base is a mapping
                    if let yamlString = processYamlDict(yamlDoc.1 as! [String:Any]) {
                        renderedString.append(yamlString)
                    }
                } else {
                    // Document base is a sequence
                    if let yamlString = processYamlArray(yamlDoc.1 as! [Any]) {
                        renderedString.append(yamlString)
                    }
                }

                // Add a separator between docs
                if i < yamlDocs.count - 1 {
                    renderedString.append(self.hr)
                }
            }


            /* YAMS Node
            do {
                let nodes = try Yams.compose_all(yaml: processed)
                for node in nodes {
                    renderedString.append(processNode(node))
                }
            }
             */


            // Just in case...
            if renderedString.length == 0 {
                renderedString = NSMutableAttributedString.init(string: "Could not render the YAML.\n",
                                                                attributes: self.keyAttributes)
            }
            
#if DEBUG
            let countString: String = "Lines: \(self.renderLineCount), sorted: \(self.sortKeys ? "true" : "false") Indent scalars: \(self.doIndentScalars ? "true" : "false")\n"
            renderedString.insert(NSMutableAttributedString.init(string: countString,
                                                                 attributes: self.keyAttributes), at: 0)
#endif
            
        } catch {
            // No YAML to render, or the YAML was mis-formatted
            // Get the error as reported by YamlSwift
            let yamlErr: YamlError = error as! YamlError
            var yamlErrString: String = yamlErr.localizedDescription
            renderedString.append(NSAttributedString(string: yamlErrString + "\n"))

            // Should we include the raw text?
            // At least the user can see the data this way
            if self.doShowRawYaml {
                renderedString.append(self.hr)
                renderedString.append(NSMutableAttributedString.init(string: yamlFileString + "\n",
                                                                  attributes: self.scalarAttributes))
            }
        }
        
        return renderedString as NSAttributedString
        */
    }


    // MARK: - Yaml Functions

    func processYamlArray(_ yaml: [Any], _ indent: Int = 0) -> NSAttributedString? {

        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.scalarAttributes)

        for (i, item) in yaml.enumerated() {
            if let yamlString = renderPair(item, indent, false) {
                // Apply a prefix to separate array and dictionary elements from a
                // previous one -- so apply to all but the first item
                if i > 0 {
                    if let _ = item as? [Any] {
                        returnString.append(self.cr)
                        self.renderLineCount += 1
                    } else if let _ = item as? [String: Any] {
                        returnString.append(self.cr)
                        self.renderLineCount += 1
                    }
                }

                // Add the element itself
                returnString.append(yamlString)
            }
        }

        return returnString
    }


    func processYamlDict(_ yaml: [String: Any]) -> NSAttributedString? {

        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.scalarAttributes)
        var keys: [String] = Array(yaml.keys)
        /*
        if self.sortKeys {
            keys = keys.sorted(by: { (a, b) -> Bool in
                // Strings?
                if let a_s = a as? String {
                    if let b_s: String = b as? String {
                        return (a_s.lowercased() < b_s.lowercased())
                    }
                }

                /*
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
                 */

                return false
            })
        }
         */

        // Iterate through the keys array
        for i in 0..<keys.count {
            // Get the key:value pairs
            let key = keys[i]
            let value = yaml[key] ?? "NULL"

            // Render the key
            if let yamlString = renderPair(key, 0, true) {
                returnString.append(yamlString)
            }

            // If the value is a collection, we drop to the next line and indent
            if let _ = value as? [Any] {
                returnString.append(self.cr)
                self.renderLineCount += 1
            } else if let _ = value as? [String: Any] {
                returnString.append(self.cr)
                self.renderLineCount += 1
            } else if self.doIndentScalars {
                returnString.append(self.cr)
                self.renderLineCount += 1
            }

            // Render the key's value of whatever type
            if let yamlString = renderPair(value, 1, false) {
                returnString.append(yamlString)
            }
        }

        return returnString
    }


    func renderPair(_ item: Any, _ indent: Int, _ isKey: Bool) -> NSAttributedString? {

        // If we're rendering a thumbnail and we've reached the limit, bail
        if self.renderDone {
            return nil
        }

        if self.renderThumbnail && self.renderLineCount >= BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT {
            self.renderDone = true
            return nil
        }

        // Set up the base string
        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.scalarAttributes)
        let spacing = isKey ? indent : 0

        if let mapItem = item as? [String: Any] {
            let keys: [String] = Array(mapItem.keys)
            for (i, key) in keys.enumerated() {
                // Get the key:value pairs
                let value = mapItem[key] ?? "NULL"

                // Render the key
                if let yamlString = renderPair(key, indent, true) {
                    returnString.append(yamlString)
                }

                // If the value is a collection, we drop to the next line and indent
                if let _ = value as? [Any] {
                    returnString.append(self.cr)
                    self.renderLineCount += 1
                } else if let _ = value as? [String: Any] {
                    returnString.append(self.cr)
                    self.renderLineCount += 1
                } else if self.doIndentScalars {
                    returnString.append(self.cr)
                    self.renderLineCount += 1
                }

                // Render the key's value
                if let yamlString = renderPair(value, indent + 1, false) {
                    returnString.append(yamlString)
                }

                // Prefix root-level key:value pairs after the first with a new line
                if i == keys.count - 1 {
                    // returnString.append(self.cr)
                }
            }
        } else if let listItem = item as? [Any] {
            // Iterate through array elements
            // NOTE A given element can be of any YAML type
            for (i, item) in listItem.enumerated() {
                if let yamlString = renderPair(item, indent, false) {
                    // Apply a prefix to separate array and dictionary elements from a
                    // previous one -- so apply to all but the first item
                    if i > 0 {
                        if let _ = item as? [Any] {
                            returnString.append(self.cr)
                            self.renderLineCount += 1
                        } else if let _ = item as? [String: Any] {
                            returnString.append(self.cr)
                            self.renderLineCount += 1
                        }
                    }

                    // Add the element itself
                    returnString.append(yamlString)
                }
            }
        } else if let stringItem = item as? String {
            // This can be used to render keys or values
            var attributeType: AttributeType = isKey ? .Key : .String

            // Segment the string by CRs
            let parts: [String] = stringItem.components(separatedBy: "\n")
            if parts.count > 2 {
                // A multiline string
                if self.renderThumbnail {
                    // For thumbnails make a combined string without between-line whitespace
                    var joined: String = ""
                    for i in 0..<parts.count {
                        joined += parts[i].trimmingCharacters(in: .whitespaces)
                    }
                    returnString.append(getIndentedAttributedString(joined + "\n", spacing, attributeType))
                } else {
                    for i in 0..<parts.count {
                        let part: String = parts[i].trimmingCharacters(in: .whitespaces)
                        if part.count == 0 {
                            continue
                        }

                        returnString.append(getIndentedAttributedString(part, spacing, attributeType, (!isKey && i > 0)))
                        if i < part.count - 2 {
                            returnString.append(self.cr)
                        }
                    }
                }
            } else {
                // Output the single-line string
                if stringItem.contains("NaN") || stringItem.contains("INF") { attributeType = .Special }
                returnString.append(getIndentedAttributedString(stringItem, spacing, attributeType))
            }

            // Post key colon or CR
            returnString.append(isKey
                                ? NSAttributedString.init(string: (self.renderColons ? ": " : " "), attributes: self.scalarAttributes)
                                : self.cr)

            if isKey {
                self.extraInset = returnString.string.count

                if self.doIndentScalars {
                    returnString.append(self.cr)
                }
            }

            if !isKey { self.renderLineCount += parts.count }
        } else if let intItem = item as? Int {
            var valString: String = "\(intItem)"
            valString += (isKey ? " " : "\n")
            returnString.append(getIndentedAttributedString(valString, spacing, isKey ? .Key : .Scalar))
            self.renderLineCount += 1
        } else if let doubleItem = item as? Double {
            var valString: String = "\(doubleItem)"
            valString += (isKey ? " " : "\n")
            returnString.append(getIndentedAttributedString(valString, spacing, isKey ? .Key : .Scalar))
            self.renderLineCount += 1
        } else if let boolItem = item as? Bool {
            var valString: String = boolItem ? "TRUE" : "FALSE"
            valString += (isKey ? " " : "\n")
            returnString.append(getIndentedAttributedString(valString, spacing, isKey ? .Key : .Special))
            self.renderLineCount += 1
        } else if let dateItem = item as? Date {
            // DATE
            // May be a key or a value
            let attributeType: AttributeType = isKey ? .Key : .Special
            let dateString: String = dateItem.formatted()
            returnString.append(getIndentedAttributedString(dateString, spacing, attributeType))

            // Post key colon or CR
            returnString.append(isKey
                                ? NSAttributedString.init(string: (self.renderColons ? ": " : " "), attributes: self.scalarAttributes)
                                : self.cr)

            if !isKey { self.renderLineCount += 1 }
        } else {
            // NULL
            // May be a key or a value
            let attributeType: AttributeType = isKey ? .Key : .Special
            let valString: String = isKey ? "NULL KEY" : "NULL VALUE"
            returnString.append(getIndentedAttributedString(valString, spacing, attributeType))

            // Append a space (item is a key) or a CR (item is a value)
            returnString.append(isKey
                                ? NSAttributedString.init(string: " ", attributes: self.scalarAttributes)
                                : self.cr)

            if !isKey { self.renderLineCount += 1 }
        }

        return returnString.string.count > 0 ? returnString : nil
    }


    /**
     Return a space-prefix NSAttributedString.

     - Parameters:
        - baseString:    The string to be indented.
        - indent:        The number of indent spaces to add.
        - attributeType: The attribute to apply.

     - Returns: The indented string as an NSAttributedString.
     */
    func getIndentedAttributedString(_ baseString: String, _ indent: Int, _ attributeType: AttributeType, _ useExtra: Bool = false) -> NSAttributedString {

        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)

        /*
        var spaceString = ""
        if indent > 0 {
            spaceString = String(repeating: ".", count: indent * self.yamlIndent - "\(indent)".count)
            spaceString = "\(indent)" + spaceString
        }
         */

        let spaceString = String(repeating: " ", count: (indent * self.yamlIndent) + (useExtra ? self.extraInset : 0))
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString, attributes: getAttributes(.Scalar)))
        indentedString.append(NSAttributedString.init(string: trimmedString, attributes: getAttributes(attributeType)))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }
    

    /**
     Return an attribute dictionary from a passed attribute type.

     - Parameters:
        - attributeType: The requested attribute type.

     - Returns: The attributes as a dictionary.
     */
    private func getAttributes(_ attributeType: AttributeType) -> [NSAttributedString.Key: Any] {

        switch attributeType {
            case .Key:
                return self.keyAttributes
            case .String:
                return self.stringAttributes
            case .Special:
                return self.specialAttributes
            default:
                return self.scalarAttributes
        }
    }


    /**
     Attempt to trap and fix .NaN, -.INF and .INF, which give YamlSwift trouble.

     - Parameters:
        - yamlString: The YAML file contents.

     - Returns: The corrected YAML content.
     */
    func fixNan(_ yamlString: String) -> String {
        
        let numberRegexes = [#"-\.(inf|Inf|INF)+"#, #"\.(inf|Inf|INF)+"#, #"\.(nan|NaN|NAN)+"#]
        let quoteRegex = #""[^"]+"|(\+)"#
        let unfixedlines = yamlString.components(separatedBy: CharacterSet.newlines)
        var fixedString: String = ""
        
        // Run through all the YAML file's lines
        for i in 0..<unfixedlines.count {
            // Look for a pattern on the current line
            var count: Int = 0
            var line: String = unfixedlines[i]
            
            for regex in numberRegexes {
                // Check for a match with a special number we're looking for
                if let itemRange: Range = line.range(of: regex, options: .regularExpression) {
                    // Double-check the matched item is not in quotes
                    let quoteRange: Range? = line.range(of: quoteRegex, options: .regularExpression)
                    if quoteRange == nil {
                        // Set the symbol based on the current value of 'count'
                        // Can make this more Swift-y with an enum
                        var symbol = ""
                        switch(count) {
                            case 0:
                                symbol = "\"-INF\""
                            case 1:
                                symbol = "\"+INF\""
                            default:
                                symbol = "\"NaN\""
                        }
                        
                        // Swap out the originl symbol for a string version
                        // (which doesn't cause a crash YamlString crash)
                        line = line.replacingCharacters(in: itemRange, with: symbol)
                        break;
                    }
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


    func processNode(_ node: Yams.Node, _ isKey: Bool = false, _ level: Int = 0) -> NSAttributedString {

        let returnString: NSMutableAttributedString = NSMutableAttributedString()

        if node.mapping != nil {
            for item in node.mapping! {
                returnString.append(processNode(item.key, true, level))
                returnString.append(processNode(item.value, false, level + 1))
            }
        } else if node.sequence != nil {

            for item in node.sequence! {
                returnString.append(processNode(item, false, level + 1))
            }
        } else {
            if node.scalar != nil {
                if let sc = node.scalar {
                    if level > 0 {
                        returnString.append(NSMutableAttributedString(string: String(repeating: "\t", count: level)))
                    }

                    returnString.append(NSMutableAttributedString(string: sc.string + (isKey ? ": " : "\n"),
                                                                  attributes: isKey ? self.keyAttributes : self.scalarAttributes))
                }
            }
        }

        return returnString as NSAttributedString
    }


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

        // FROM 1.1.5
        // If we're rendering a thumbnail and we've reached the limit, bail
        if self.renderThumbnail && self.renderLineCount >= BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT {
            self.renderDone = true
            return nil
        }

        // Set up the base string
        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.scalarAttributes)

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
                            returnString.append(self.cr)

                            // FROM 1.1.5
                            self.renderLineCount += 1
                        }

                        // Add the element itself
                        returnString.append(yamlString)
                    }
                }
            }
        case .dictionary:
            if let dict = part.dictionary {
                // Iterate through the dictionary's keys and their values
                // NOTE A given value can be of any YAML type

                // Sort the dictionary's keys (ascending)
                // We assume all keys will be strings, ints, doubles or bools
                // FROM 1.2.0 -- sort is optional, but true by default
                var keys: [Yaml] = Array(dict.keys)
                if self.sortKeys {
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
                }

                // Iterate through the sorted keys array
                for i in 0..<keys.count {
                    // Prefix root-level key:value pairs after the first with a new line
                    if indent == 0 && i > 0 {
                        returnString.append(self.cr)
                    }

                    // Get the key:value pairs
                    let key: Yaml = keys[i]
                    let value: Yaml = dict[key] ?? .null

                    // Render the key
                    if let yamlString = renderYaml(key, indent, true) {
                        returnString.append(yamlString)
                    }

                    // If the value is a collection, we drop to the next line and indent
                    var valueIndent: Int = 0
                    if (value.array != nil || value.dictionary != nil || self.doIndentScalars) {
                        valueIndent = indent + self.yamlIndent
                        returnString.append(self.cr)

                        // FROM 1.1.5
                        self.renderLineCount += 1
                    }

                    // Render the key's value
                    if let yamlString = renderYaml(value, valueIndent, false) {
                        returnString.append(yamlString)
                    }
                }
            }
        case .string:
            // This can be used to render keys or values
            if let keyOrValue = part.string {
                var attributeType: AttributeType = isKey ? .Key : .String

                // Segment the string by CRs
                let parts: [String] = keyOrValue.components(separatedBy: "\n")
                if parts.count > 2 {
                    // A multiline string
                    if self.renderThumbnail {
                        // For thumbnails make a combined string without between-line whitespace
                        var joined: String = ""
                        for i in 0..<parts.count {
                            joined += parts[i].trimmingCharacters(in: .whitespaces)
                        }
                        returnString.append(getIndentedAttributedString(joined + "\n", indent, attributeType))
                    } else {
                        // For previrews, make indented lines per source line
                        for i in 0..<parts.count {
                            let part: String = parts[i].trimmingCharacters(in: .whitespaces)
                            if part.count == 0 {
                                continue
                            }

                            returnString.append(getIndentedAttributedString(part + (i < parts.count - 2 ? "\n" : " "), indent, attributeType))
                        }
                    }
                } else {
                    // Output the single-line string
                    if keyOrValue.contains("NaN") || keyOrValue.contains("INF") { attributeType = .Special }
                    returnString.append(getIndentedAttributedString(keyOrValue, indent, attributeType))
                }

                /* REMOVED 1.2.0
                 returnString.setAttributes(attsToUse, range: NSMakeRange(0, returnString.length))
                 */

                // FROM 1.2.0 -- render colons if asked
                returnString.append(isKey
                                    ? NSAttributedString.init(string: (self.renderColons ? ": " : " "), attributes: self.scalarAttributes)
                                    : self.cr)

                // FROM 1.1.5
                if !isKey { self.renderLineCount += parts.count }
            }
        case .null:
            // May be a key or a value
            let valString: String = isKey ? "NULL KEY" : "NULL VALUE"
            returnString.append(getIndentedAttributedString(valString, indent, isKey ? .Key : .Special))
            /* REMOVED 1.2.0
            returnString.append(getIndentedString(valString, indent))
            returnString.setAttributes(self.specialAttributes, range: NSMakeRange(0, returnString.length))
             */

            // Append a space (item is a key) or a CR (item is a value)
            returnString.append(isKey
                                ? NSAttributedString.init(string: " ", attributes: self.scalarAttributes)
                                : self.cr)

            // FROM 1.1.5
            if !isKey { self.renderLineCount += 1 }
        case .bool:
            var valString: String = ""

            if let boolValue = part.bool {
                valString = boolValue ? "TRUE" : "FALSE"
            }

            valString += (isKey ? " " : "\n")
            returnString.append(getIndentedAttributedString(valString, indent, isKey ? .Key : .Special))
            self.renderLineCount += 1
        default:
            // Place all the scalar values here
            // TODO These *may* be keys too, so we need to check that
            var valString: String = ""

            if let val = part.int {
                valString = "\(val)"
            } else if let val = part.double {
                valString = "\(val)"
            } else {
                valString = "UNKNOWN"
            }

            // FROM 1.1.5
            valString += (isKey ? " " : "\n")
            returnString.append(getIndentedAttributedString(valString, indent, isKey ? .Key : .Scalar))

            /* REMOVED 1.2.0
             returnString.setAttributes((isKey ? self.keyAttributes : self.scalarAttributes), range: NSMakeRange(0, returnString.length))
             */

            // FROM 1.1.5
            self.renderLineCount += 1
        }

        return returnString.string.count > 0 ? returnString : nil
    }


    public func prettyPrintYAML(_ source: String) -> NSAttributedString {

        let returnString: NSMutableAttributedString = NSMutableAttributedString.init(string: "", attributes: self.scalarAttributes)
        let docs = YAMLParser(source).parse()
        if docs.isEmpty {
            return returnString
        }

        if docs.count == 1 {
            return docs[0].prettyPrinted(indent: 0)
        }

        _ = docs.map { doc in
            returnString.append(doc.prettyPrinted(indent: 0))
            returnString.append(self.cr)
        }

        return returnString
    }

}


// ============================================================
// MARK: - Data Model
// ============================================================

/// An ordered representation of a YAML value.
/// Mappings use an array of (key, value) pairs so that
/// the original source order is always preserved.
public indirect enum YAMLNode {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case sequence([YAMLNode])
    case mapping([(key: String, value: YAMLNode)])
}


// ============================================================
// MARK: - Pretty Printer
// ============================================================

extension YAMLNode {

    /// Returns a canonical, human-readable YAML representation.
    public func prettyPrinted(indent level: Int = 0, indentCount ic: Int = 2) -> NSAttributedString {

        let pad = String(repeating: " ", count: level * ic)
        let rs = NSMutableAttributedString(string: "")

        switch self {
            case .null:
                return NSAttributedString(string: "NULL")
            case .bool(let b):
                return NSAttributedString(string: b ? "true" : "false")
            case .int(let i):
                return NSAttributedString(string: String(i))
            case .double(let d):
                if d.isNaN {
                    return NSAttributedString(string: "NaN")
                }

                if d == .infinity {
                    return NSAttributedString(string: "INF")
                }

                if d == -.infinity {
                    return NSAttributedString(string: "-INF")
                }

                if d.truncatingRemainder(dividingBy: 1) == 0 {
                    return NSAttributedString(string: "\(Int(d)).0")
                }

                return NSAttributedString(string: String(d))
            case .string(let s):
                return formatString(s)
            case .sequence(let items):
                if items.isEmpty {
                    return rs
                }

                _ = items.map { item -> NSAttributedString in
                    // For a mapping item, put the first key on the same line as "- ".
                    if case .mapping(let pairs) = item, !pairs.isEmpty {
                        let body      = item.prettyPrinted(indent: level + 1)
                        let bodyLines = body.string.components(separatedBy: "\n")
                        let first     = bodyLines[0].trimmingCharacters(in: .whitespaces)
                        let rest      = bodyLines.dropFirst().joined(separator: "\n")
                        return rest.isEmpty ? NSAttributedString(string: "\(pad)\(first)")
                                            : NSAttributedString(string: "\(pad)\(first)\n\(rest)")
                    }

                    let inner = item.prettyPrinted(indent: level + 1)
                    rs.append(inner)
                    if item != items.last {
                        rs.append(NSAttributedString(string: "\n"))
                    }

                    return NSAttributedString(string: "\(pad)\(inner)")
                }

            case .mapping(let pairs):
                if pairs.isEmpty {
                    return rs
                }

                _ = pairs.map { (key, value) -> String in
                    let k = formatKey(key)
                    switch value {
                    case .mapping(let p)  where !p.isEmpty:
                        return "\(pad)\(k):\n\(value.prettyPrinted(indent: level + 1))"
                    case .sequence(let a) where !a.isEmpty:
                        return "\(pad)\(k):\n\(value.prettyPrinted(indent: level + 1))"
                    default:
                        return "\(pad)\(k): \(value.prettyPrinted(indent: 0))"
                    }
                }
        }

        return rs as NSAttributedString
    }


    // MARK: Formatting helpers

    private func formatString(_ s: String) -> NSAttributedString {

        if s.isEmpty {
            return NSAttributedString(string: "")
        }

        // Values that look like special YAML scalars must be quoted.
        let reserved: Set<String> = [
            "null", "~", "true", "false",
            "yes", "no", "on", "off",
            ".inf", "-.inf", ".nan"
        ]

        if reserved.contains(s.lowercased()) {
            return singleQuote(s)
        }

        // Plain strings that look like numbers must be quoted so they
        // round-trip as strings.
        if Int(s) != nil || Double(s) != nil {
            return singleQuote(s)
        }

        // Characters that have special meaning at the start of a plain scalar.
        let specialStart: Set<Character> = [
            " ", "\"", "'", "#", "&", "*", "!", "|",
            ">", "{", "[", "}", "]", ",", ":", "?",
            "%", "@", "`"
        ]
        if let first = s.first, specialStart.contains(first) {
            return doubleQuote(s)
        }

        // Inline content that would confuse a parser.
        if s.contains(": ") || s.hasSuffix(":") || s.contains(" #") || s.contains("\n") {
            return doubleQuote(s)
        }

        return NSAttributedString(string: s)
    }


    private func formatKey(_ key: String) -> NSAttributedString {

        if key.isEmpty {
            return NSAttributedString(string: "")
        }

        if key.contains(":") || key.contains("#") || key.hasPrefix(" ") {
            return singleQuote(key)
        }

        return NSAttributedString(string: key)
    }


    private func singleQuote(_ s: String) -> NSAttributedString {

        return NSAttributedString(string:"‘\(s.replacingOccurrences(of: "'", with: "''"))’")
    }


    private func doubleQuote(_ s: String) -> NSAttributedString {

        let escaped = s
            .replacingOccurrences(of: "\\",  with: "\\\\")
            .replacingOccurrences(of: "\"",  with: "\\\"")
            .replacingOccurrences(of: "\n",  with: "\\n")
            .replacingOccurrences(of: "\t",  with: "\\t")
            .replacingOccurrences(of: "\r",  with: "\\r")
        return NSAttributedString(string:"\"\(escaped)\"")
    }
}


// ============================================================
// MARK: - Internal: Processed line
// ============================================================

private struct Line {

    let number: Int
    let indent: Int
    /// Trimmed content with inline comments removed (but NOT raw text –
    /// block-scalar bodies are read from the raw source separately).
    let text: String

    var isEmpty:    Bool { text.isEmpty }
    var isDocStart: Bool { text == "---" || text.hasPrefix("--- ") }
    var isDocEnd:   Bool { text == "..." }
}


// ============================================================
// MARK: - Internal: Parser
// ============================================================

private final class YAMLParser {

    var currentLine: Int = 0
    let lines: [Line]
    // Keep the raw lines so that block-scalar bodies can be read without comment-stripping.
    let rawLines: [String]


    init(_ yamlSource: String) {
        // Separate out the lines
        self.rawLines = yamlSource.components(separatedBy: "\n")

        // Process the lines in order
        self.lines = self.rawLines.enumerated().map {
            Self.processLine($0.element, $0.offset)
        }
    }


    // MARK: - Line processing

    private static func processLine(_ rawLine: String, _ number: Int) -> Line {

        let indent = rawLine.prefix(while: { $0 == " " }).count
        let trimmed = String(rawLine.dropFirst(indent))
        if trimmed.hasPrefix("#") {
            return Line(number: number, indent: indent, text: "")
        }

        let text = stripInlineComment(trimmed)
        return Line(number: number, indent: indent, text: text)
    }


    // Remove a ` # …` inline comment that is not inside quotes.
    private static func stripInlineComment(_ s: String) -> String {

        var inSingle = false
        var inDouble = false
        var prev: Character = "\0"
        var idx = s.startIndex

        while idx < s.endIndex {
            let c = s[idx]
            if c == "'" && !inDouble {
                inSingle.toggle()
            } else if c == "\"" && !inSingle {
                inDouble.toggle()
            } else if c == "#" && !inSingle && !inDouble && (prev == " " || prev == "\t" || prev == "\0") {
                return String(s[s.startIndex..<idx]).trimmingCharacters(in: .whitespaces)
            }

            prev = c
            idx  = s.index(after: idx)
        }

        return s
    }


    // MARK: - Document parsing

    /**
     Convert the sequence of lines into a sequence of nodes.
     */
    func parse() -> [YAMLNode] {

        var nodes: [YAMLNode] = []
        while currentLine < lines.count {
            skipBlanks()
            if currentLine >= lines.count {
                break
            }

            let line = lines[currentLine]
            if line.isDocEnd {
                currentLine += 1
                continue
            }

            if line.isDocStart {
                currentLine += 1          // Consume the `---` marker
                skipBlanks()
                if currentLine < lines.count, !lines[currentLine].isDocStart, !lines[currentLine].isDocEnd {
                    nodes.append(parseNode(minIndent: 0))
                } else {
                    nodes.append(.null)
                }
            } else {
                nodes.append(parseNode(minIndent: 0))
            }
        }

        return nodes
    }

    // MARK: - Node dispatch

    func parseNode(minIndent: Int) -> YAMLNode {

        skipBlanks()
        guard currentLine < lines.count else {
            return .null
        }

        let line = lines[currentLine]
        guard !line.isDocStart, !line.isDocEnd else {
            return .null
        }

        guard line.indent >= minIndent else {
            return .null
        }

        let text = line.text

        if text.hasPrefix("- ") || text == "-" {
            return parseSequence(indent: line.indent)
        }

        if findColonIndex(in: text) != nil {
            return parseMapping(indent: line.indent, injectedFirst: nil)
        }

        if isBlockScalarHeader(text) {
            return parseBlockScalar()
        }

        currentLine += 1
        return parseScalarText(text)
    }


    // MARK: - Sequence

    func parseSequence(indent: Int) -> YAMLNode {

        var items: [YAMLNode] = []

        while currentLine < lines.count {
            skipBlanks()
            guard currentLine < lines.count else {
                break
            }

            let line = lines[currentLine]
            if line.isDocStart || line.isDocEnd {
                break
            }

            if line.indent != indent {
                break
            }

            guard line.text.hasPrefix("- ") || line.text == "-" else {
                break
            }

            currentLine += 1
            let rest = line.text == "-"
                ? ""
                : String(line.text.dropFirst(2)).trimmingCharacters(in: .whitespaces)

            if rest.isEmpty {
                skipBlanks()
                if currentLine < lines.count, lines[currentLine].indent > indent, !lines[currentLine].isDocStart, !lines[currentLine].isDocEnd {
                    items.append(parseNode(minIndent: indent + 1))
                } else {
                    items.append(.null)
                }
            } else if isBlockScalarHeader(rest) {
                items.append(parseBlockScalarBody(bodyIndentHint: indent + 2, style: rest))
            } else if findColonIndex(in: rest) != nil {
                // "- key: value" — inline mapping entry
                items.append(parseMapping(indent: indent + 2, injectedFirst: rest))
            } else if rest.hasPrefix("- ") || rest == "-" {
                // Nested sequence on the same line; uncommon but valid
                items.append(parseScalarText(rest))   // best-effort
            } else {
                items.append(parseScalarText(rest))
            }
        }

        return .sequence(items)
    }


    // MARK: - Mapping

    func parseMapping(indent: Int, injectedFirst: String?) -> YAMLNode {

        var pairs: [(key: String, value: YAMLNode)] = []

        func absorb(_ text: String) {

            guard let colonIdx = findColonIndex(in: text) else { return }
            let rawKey = String(text[text.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let key = unquoteScalar(rawKey)
            let rawVal = String(text[text.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            if rawVal.isEmpty {
                // Value is on the following lines.
                skipBlanks()
                if currentLine < lines.count, lines[currentLine].indent > indent, !lines[currentLine].isDocStart, !lines[currentLine].isDocEnd {
                    pairs.append((key: key, value: parseNode(minIndent: indent + 1)))
                } else {
                    pairs.append((key: key, value: .null))
                }
            } else if isBlockScalarHeader(rawVal) {
                pairs.append((key: key, value: parseBlockScalarBody(bodyIndentHint: indent + 2, style: rawVal)))
            } else {
                pairs.append((key: key, value: parseScalarText(rawVal)))
            }
        }

        // An injected first line is used when we encounter "- key: value"
        // inside a sequence; we already consumed that line.
        if let first = injectedFirst {
            absorb(first)
        }

        while currentLine < lines.count {
            skipBlanks()
            guard currentLine < lines.count else {
                break
            }

            let line = lines[currentLine]
            if line.isDocStart || line.isDocEnd {
                break }
            if line.indent < indent {
                break
            }

            if line.indent > indent {
                break
            }

            guard findColonIndex(in: line.text) != nil else {
                break
            }

            currentLine += 1 // consume the key line before absorbing
            absorb(line.text)
        }

        return .mapping(pairs)
    }


    // MARK: - Block scalars  (| and >)

    private func isBlockScalarHeader(_ s: String) -> Bool {

        let stripped = s.trimmingCharacters(in: .whitespaces)
        return stripped == "|"  || stripped == "|-" || stripped == "|+" ||
               stripped == ">"  || stripped == ">-" || stripped == ">+" ||
               stripped.hasPrefix("| ") || stripped.hasPrefix("> ")
    }


    func parseBlockScalar() -> YAMLNode {

        let style = lines[currentLine].text
        currentLine += 1
        return parseBlockScalarBody(bodyIndentHint: -1, style: style)
    }


    /// `bodyIndentHint` is the expected indentation of the body; pass -1 to
    /// auto-detect from the first content line.
    func parseBlockScalarBody(bodyIndentHint: Int, style: String) -> YAMLNode {

        let isLiteral = style.hasPrefix("|")
        let chomping: Character = {
            let last = style.last
            if last == "-" {
                return "-"
            }

            if last == "+" {
                return "+"
            }

            return " "   // clip (default)
        }()

        // Determine the effective indent from the first non-empty body line.
        var bodyIndent = bodyIndentHint
        if bodyIndent < 0 {
            var i = currentLine
            while i < lines.count && lines[i].isEmpty {
                i += 1
            }

            bodyIndent = i < lines.count ? lines[i].indent : 0
        }

        var collected: [String] = []
        while currentLine < lines.count {
            let l = lines[currentLine]
            if l.isDocStart || l.isDocEnd { break }
            if !l.isEmpty && l.indent < bodyIndent { break }

            // Preserve the original raw text (minus the leading spaces).
            let rawContent: String
            if l.isEmpty {
                rawContent = ""
            } else {
                let rawLine = rawLines[l.number]
                rawContent  = String(rawLine.dropFirst(bodyIndent))
            }
            collected.append(rawContent)
            currentLine += 1
        }

        // Apply chomping.
        switch chomping {
            case "-":   // strip – remove all trailing newlines
                while let last = collected.last, last.isEmpty { collected.removeLast() }
            case "+":   // keep – preserve all trailing newlines (nothing to do)
                break
            default:    // clip – one trailing newline
                while collected.count > 1, let last = collected.last, last.isEmpty {
                    collected.removeLast()
                }
        }

        let result: String
        if isLiteral {
            result = collected.joined(separator: "\n")
                + (chomping == " " ? "\n" : "")
        } else {
            // Folded: blank lines stay as literal newlines;
            // non-blank lines are joined with a space.
            var out   = ""
            var first = true
            var i     = 0
            while i < collected.count {
                let line = collected[i]
                if line.isEmpty {
                    out  += "\n"
                    first = true
                } else {
                    out  += (first ? "" : " ") + line
                    first = false
                }
                i += 1
            }
            if chomping == " " { out += "\n" }
            result = out
        }
        return .string(result)
    }

    // MARK: - Scalar parsing

    func parseScalarText(_ s: String) -> YAMLNode {

        let t = s.trimmingCharacters(in: .whitespaces)

        if t == "null" || t == "~" || t.isEmpty  { return .null }
        switch t.lowercased() {
            case "true",  "yes", "on":
                return .bool(true)
            case "false", "no",  "off":
                return .bool(false)
            default:
                break
        }

        switch t {
            case ".inf", "+.inf", ".Inf", "+.Inf", ".INF", "+.INF":
                return .double(.infinity)
            case "-.inf", "-.Inf", "-.INF":
                return .double(-.infinity)
            case ".nan",  ".NaN",  ".NAN":
                return .double(.nan)
            default: break
        }

        // Integer literals (decimal, hex, octal, binary)
        if t.hasPrefix("0x") || t.hasPrefix("0X"), let i = Int(t.dropFirst(2), radix: 16) {
            return .int(i)
        }

        if t.hasPrefix("0o") || t.hasPrefix("0O"), let i = Int(t.dropFirst(2), radix: 8) {
            return .int(i)
        }

        if t.hasPrefix("0b") || t.hasPrefix("0B"),
           let i = Int(t.dropFirst(2), radix: 2)   { return .int(i) }
        if let i = Int(t)                           { return .int(i) }
        if let d = Double(t)                        { return .double(d) }

        // Double-quoted string
        if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count >= 2 {
            return .string(unescapeDouble(String(t.dropFirst().dropLast())))
        }
        // Single-quoted string
        if t.hasPrefix("'") && t.hasSuffix("'") && t.count >= 2 {
            let inner = String(t.dropFirst().dropLast())
                .replacingOccurrences(of: "''", with: "'")
            return .string(inner)
        }
        // Flow sequence / mapping
        if t.hasPrefix("[") { return parseFlowSequence(t) ?? .string(t) }
        if t.hasPrefix("{") { return parseFlowMapping(t)  ?? .string(t) }

        return .string(t)
    }

    private func unquoteScalar(_ s: String) -> String {

        if (s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2) || (s.hasPrefix("'")  && s.hasSuffix("'")  && s.count >= 2) {
            return String(s.dropFirst().dropLast())
        }

        return "*\(s)*"
    }

    private func unescapeDouble(_ s: String) -> String {
        
        var result = ""
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if c == "\\" {
                let next = s.index(after: idx)
                guard next < s.endIndex else { result.append(c); break }
                switch s[next] {
                    case "n":
                        result.append("\n")
                    case "t":
                        result.append("\t")
                    case "r":
                        result.append("\r")
                    case "\\":
                        result.append("\\")
                    case "\"":
                        result.append("\"")
                    case "0":
                        result.append("\0")
                    case "a":
                        result.append("\u{07}")
                    case "b":
                        result.append("\u{08}")
                    case "e":
                        result.append("\u{1B}")
                    case " ":
                        result.append(" ")
                    default:
                        result.append("\\"); result.append(s[next])
                }

                idx = s.index(after: next)
            } else {
                result.append(c)
                idx = s.index(after: idx)
            }
        }

        return result
    }


    // MARK: - Flow collections

    private func parseFlowSequence(_ s: String) -> YAMLNode? {

        guard s.hasPrefix("["), s.hasSuffix("]") else { return nil }
        let inner = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return .sequence([]) }
        return .sequence(splitFlowItems(inner).map {
            parseScalarText($0.trimmingCharacters(in: .whitespaces))
        })
    }

    private func parseFlowMapping(_ s: String) -> YAMLNode? {

        guard s.hasPrefix("{"), s.hasSuffix("}") else { return nil }
        let inner = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return .mapping([]) }
        var pairs: [(key: String, value: YAMLNode)] = []
        for item in splitFlowItems(inner) {
            let t = item.trimmingCharacters(in: .whitespaces)
            guard let ci = findColonIndex(in: t) else { continue }
            let k = String(t[t.startIndex..<ci]).trimmingCharacters(in: .whitespaces)
            let v = String(t[t.index(after: ci)...]).trimmingCharacters(in: .whitespaces)
            pairs.append((key: unquoteScalar(k), value: parseScalarText(v)))
        }
        return .mapping(pairs)
    }

    /// Splits a comma-separated flow string, respecting nested brackets and quotes.
    private func splitFlowItems(_ s: String) -> [String] {

        var items:   [String]    = []
        var depth    = 0
        var inSingle = false
        var inDouble = false
        var current  = ""
        for c in s {
            if      c == "'" && !inDouble { inSingle.toggle() }
            else if c == "\"" && !inSingle { inDouble.toggle() }
            else if !inSingle && !inDouble {
                if      c == "[" || c == "{" { depth += 1 }
                else if c == "]" || c == "}" { depth -= 1 }
                else if c == "," && depth == 0 {
                    items.append(current); current = ""; continue
                }
            }
            current.append(c)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { items.append(current) }
        return items
    }

    // MARK: - Utilities

    func skipBlanks() {

        while currentLine < lines.count && lines[currentLine].isEmpty {
            currentLine += 1
        }
    }

    /// Returns the index of the `:` that introduces a mapping value, or nil.
    /// Skips colons that are inside single- or double-quoted strings.
    func findColonIndex(in s: String) -> String.Index? {

        var inSingle = false
        var inDouble = false
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if c == "'" && !inDouble {
                inSingle.toggle()
            } else if c == "\"" && !inSingle {
                inDouble.toggle()
            } else if c == ":" && !inSingle && !inDouble {
                let next = s.index(after: idx)
                // A mapping colon must be followed by a space, tab, or end-of-string.
                if next == s.endIndex || s[next] == " " || s[next] == "\t" {
                    return idx
                }
            }

            idx = s.index(after: idx)
        }

        return nil
    }
}




/**
Get the encoding of the string formed from data.

- Returns: The string's encoding or nil.
*/

extension Data {
    
    var stringEncoding: String.Encoding? {
        var nss: NSString? = nil
        guard case let rawValue = NSString.stringEncoding(for: self,
                                                          encodingOptions: nil,
                                                          convertedString: &nss,
                                                          usedLossyConversion: nil), rawValue != 0 else { return nil }
        return .init(rawValue: rawValue)
    }
}
