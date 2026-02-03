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
        var renderedString: NSMutableAttributedString = NSMutableAttributedString.init(string: "",
                                                                                       attributes: self.scalarAttributes)
        // FROM 1.1.5
        self.renderLineCount = 0
        self.renderDone = false
        
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
