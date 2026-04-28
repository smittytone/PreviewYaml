/*
 *  Common.swift
 *  PreviewYaml
 *  Code common to Yaml Previewer and Yaml Thumbnailer
 *
 *  Created by Tony Smith on 22/04/2021.
 *  Copyright © 2025 Tony Smith. All rights reserved.
 */


import Yaml
import AppKit


// FROM 1.1.0
// Implement as a class
final class Common {

    // MARK: - Definitions

    enum AttributeType {
        case Key
        case Scalar
        case String
        case Special
        case Comment
    }


    // MARK: - Public Properties
    
    var doShowLightBackground: Bool                                 = false
    // FROM 2.0.0
    public var settings: PYSettings                                 = PYSettings()
    public var tableWidth: CGFloat                                  = 384.0

    
    // MARK: - Private Properties
    
    // FROM 1.1.5
    private var renderDone: Bool                                    = false
    private var renderLineCount: Int                                = 0
    private var sortKeys: Bool                                      = true

    // YAML string attributes...
    private var keyAttributes: [NSAttributedString.Key: Any]        = [:]
    private var scalarAttributes: [NSAttributedString.Key: Any]     = [:]
    // FROM 1.2.0
    private var specialAttributes: [NSAttributedString.Key: Any]    = [:]
    private var stringAttributes: [NSAttributedString.Key: Any]     = [:]
    // FROM 2.0.0
    private var markAttributes: [NSAttributedString.Key: Any]       = [:]
    private var commentAttributes: [NSAttributedString.Key: Any]    = [:]
    private var maxDepth                                            = 0

    // String artifacts...
    private var hr: NSMutableAttributedString                       = NSMutableAttributedString(string: "")
    private var cr: NSMutableAttributedString                       = NSMutableAttributedString(string: "")

    /*
     Replace the following string with your own team ID. This is used to
     identify the app suite and so share preferences set by the main app with
     the previewer and thumbnailer extensions.
     */
    private var appSuiteName: String = MNU_SECRETS.PID + BUFFOON_CONSTANTS.SUITE_NAME


    // MARK: - Lifecycle Functions
    
    init(forThumbnail isThumbnail: Bool) {

        self.settings.loadSettings(self.appSuiteName)
        self.settings.isThumbnail = isThumbnail

        if self.settings.fontSize < BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[0] ||
            self.settings.fontSize > BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS[BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE_OPTIONS.count - 1] {
            self.settings.fontSize = CGFloat(BUFFOON_CONSTANTS.PREVIEW_SIZE.FONT_SIZE)
        }

        // Set the YAML key:value fonts and sizes
        var font: NSFont
        if let chosenFont = NSFont(name: self.settings.fontName, size: self.settings.fontSize) {
            font = chosenFont
        } else {
            font = NSFont.systemFont(ofSize: self.settings.fontSize)
        }
        
        // Use a light theme?
        let useLightMode = isThumbnail || self.settings.doReverseMode

        // Set up the attributed string components we may use during rendering
        self.keyAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.KEYS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.KEYS),
            .font: font
        ]
        
        self.scalarAttributes = [
            .foregroundColor: (useLightMode ? NSColor.black : NSColor.labelColor),
            .font: font
        ]

        // FROM 2.0.0
        // New, TextKit 2-friendly horizontal rule
        let hrTable = NSTextTable()
        hrTable.numberOfColumns = 1
        let hrBlock = NSTextTableBlock(table: hrTable, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
        hrBlock.setWidth(1.0, type: .absoluteValueType, for: .border, edge: .maxY)
        hrBlock.setBorderColor(NSApplication.shared.inLightMode ? NSColor.hexToColour("eeeeeeff") : NSColor.hexToColour("222222ff"))
        let hrParaStyle = NSMutableParagraphStyle()
        hrParaStyle.alignment = .center
        hrParaStyle.textBlocks = [hrBlock]
        let hrFont = font
        self.hr = NSMutableAttributedString(string: BUFFOON_CONSTANTS.CR,
                                            attributes: [.foregroundColor: NSColor.labelColor,
                                                         .paragraphStyle: hrParaStyle,
                                                         .font: hrFont])

        self.cr = NSMutableAttributedString(string: BUFFOON_CONSTANTS.CR,
                                            attributes: self.scalarAttributes)
        
        // FROM 1.2.0
        self.specialAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.SPECIALS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.SPECIALS),
            .font: font
        ]
        
        self.stringAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.STRINGS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.STRINGS),
            .font: font
        ]

        // FROM 2.0.0
        self.markAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.MARKS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.MARKS),
            .font: font
        ]

        self.commentAttributes = [
            .foregroundColor: NSColor.hexToColour(self.settings.displayColours[BUFFOON_CONSTANTS.COLOUR_IDS.COMMENTS] ?? BUFFOON_CONSTANTS.HEX_COLOUR.COMMENTS),
            .font: font
        ]
    }
    
    
    /**
     Update certain style variables on a UI mode switch.

     THIS IS USED SOLELY BY THE RENDER DEMO APP.
     */
    func resetStylesOnModeChange() {

        // Set up the attributed string components we may use during rendering
        self.scalarAttributes[.foregroundColor]  = self.doShowLightBackground ? NSColor.black : NSColor.labelColor
    }


    // MARK: - The Primary Functions

    /**
     Use YamlSwift to render the input YAML as an NSAttributedString.

     - Note: This function does not use Swift Concurrency, because the macOS
             thumbnailing system is not yet Swift Concurrency compliant.

     - Parameters:
        - yamlFileString: The raw YAML code.

     - Returns: The rendered source as an NSAttributedString.
     */
    public func getThumbnailString(fromYaml yamlFileString: String) -> NSAttributedString {

        // Set up the base string
        let renderedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        renderedString.append(processYaml(yamlFileString))
        return renderedString
    }


    /**
     Use YamlSwift to render the input YAML as an NSAttributedString.

     - Note: This function requires Swift Concurrency.

     - Parameters:
        - yamlFileString: The raw YAML code.

     - Returns: The rendered source as an NSAttributedString.
     */
    public func getPreviewString(fromYaml yamlFileString: String) async -> NSAttributedString {

        let renderedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        renderedString.append(processYaml(yamlFileString))
        return renderedString

        /*
        // FROM 1.1.5
        self.renderLineCount = 0
        self.renderDone = false
        
        // Parse the YAML data
        do {
            // First fix any .NAN, +/-.INF in the file
            let processed = fixNan(yamlFileString)

            // NOTE The following call takes time on large files
            // TODO Optimise it
            let yaml = try Yaml.loadMultiple(processed)
            
            // Render the YAML to NSAttributedString
            // NOTE `yaml` is an array of YAML units
            for i in 0..<yaml.count {
                if let yamlString = renderYaml(yaml[i], 0, false) {
                    if i > 0 { renderedString.append(hr) }
                    renderedString.append(yamlString)
                }
                
                // FROM 1.1.5
                // Break out of loop if we're done rendering a thumbnail
                if self.renderDone { break }
            }
            
            // Just in case...
            if renderedString.length == 0 {
                renderedString = NSMutableAttributedString.init(string: "Could not render the YAML.\n",
                                                                attributes: self.keyAttributes)
            }
            
#if DEBUG
            // FROM 1.1.5
            let countString: String = "Lines: \(self.renderLineCount), sorted: \(self.sortKeys ? "true" : "false") \n"
            renderedString.insert(NSMutableAttributedString.init(string: countString,
                                                                 attributes: self.keyAttributes), at: 0)
#endif
            
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
                                                                                        attributes: self.keyAttributes)

            // Should we include the raw text?
            // At least the user can see the data this way
            if self.settings.showRawYamlOnError {
                errorString.append(self.hr)
                errorString.append(NSMutableAttributedString.init(string: yamlFileString + "\n",
                                                                  attributes: self.scalarAttributes))
            }

            renderedString = errorString
        }
        
        return renderedString as NSAttributedString
        */
    }


    // MARK: - Yaml Functions

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
        if self.settings.isThumbnail && self.renderLineCount >= BUFFOON_CONSTANTS.THUMBNAIL_LINE_COUNT {
            self.renderDone = true
            return nil
        }
        
        // Set up the base string
        let returnString: NSMutableAttributedString = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)

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
                    if (value.array != nil || value.dictionary != nil || self.settings.doIndentScalars) {
                        valueIndent = indent + self.settings.indentSize
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
                    if self.settings.isThumbnail {
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
                                    ? NSAttributedString(string: (self.settings.showYamlMarks ? ": " : " "), attributes: self.markAttributes)
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
                                ? NSAttributedString(string: " ", attributes: self.scalarAttributes)
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


    /** REMOVED 1.2.0
     Return a space-prefix NSAttributedString.
     DEPRECATED

     - Parameters:
        - baseString: The string to be indented.
        - indent:     The number of indent spaces to add.

     - Returns: The indented string as an NSAttributedString.

    func getIndentedString(_ baseString: String, _ indent: Int) -> NSAttributedString {
        
        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaceString = String(repeating: " ", count: indent)
        let indentedString: NSMutableAttributedString = NSMutableAttributedString.init()
        indentedString.append(NSAttributedString.init(string: spaceString))
        indentedString.append(NSAttributedString.init(string: trimmedString))
        return indentedString.attributedSubstring(from: NSMakeRange(0, indentedString.length))
    }
     */
    

    /**
     Return a space-prefix NSAttributedString.

     - Parameters:
        - baseString:    The string to be indented.
        - indent:        The number of indent spaces to add.
        - attributeType: The attribute to apply.

     - Returns: The indented string as an NSAttributedString.
     */
    func getIndentedAttributedString(_ baseString: String, _ indent: Int, _ attributeType: AttributeType) -> NSAttributedString {

        let trimmedString = baseString.trimmingCharacters(in: .whitespaces)
        let spaceString = String(repeating: " ", count: indent)
        let indentedString: NSMutableAttributedString = NSMutableAttributedString()
        indentedString.append(NSAttributedString(string: spaceString, attributes: getAttributes(.Scalar)))
        indentedString.append(NSAttributedString(string: trimmedString, attributes: getAttributes(attributeType)))
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


    // MARK: - New YAML Functions

    private func processYaml(_ yaml: String) -> NSAttributedString {

        guard let yamlDocs = YAMLParser(rawYaml: yaml).parse() else {
            // Send back the raw YAML on error
            return NSAttributedString(string: yaml, attributes: self.scalarAttributes)
        }

        guard !yamlDocs.isEmpty else {
            // Quickly send back an empty attributed string
            return NSAttributedString(string: "", attributes: self.scalarAttributes)
        }

        // Assemble the paragraphs (rows) to be rendered
        let previewParagraphs = NSMutableArray()
        for yamlDoc in yamlDocs {
            let docParagraphs = NSMutableArray()
            makeIndentParagraph(yamlDoc, 0, nil, docParagraphs)

            if docParagraphs.count > 0 {
                // Add the current doc's paragraphs to the main store
                previewParagraphs.addObjects(from: docParagraphs as! [Any])

                if docParagraphs.count > 1 {
                    // Add a spacer line
                    previewParagraphs.add(Paragraph(text: NSMutableAttributedString(string: "*", attributes: self.scalarAttributes)))
                }
            }
        }

        // Assemble the preview from the individual lines
        let renderedPreview = NSMutableAttributedString(string: "", attributes: self.scalarAttributes)
        for i in 0..<previewParagraphs.count {
            let paragraph = previewParagraphs.object(at: i) as! Paragraph
            if var paragraphText = paragraph.text {
                let leftMargin = CGFloat(paragraph.depth) * 20.0 * CGFloat(self.settings.indentSize)

                if paragraphText.length > 0 {
                    // Instantiate a generic paragraph style
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.paragraphSpacing = self.settings.fontSize * 0.5
                    paragraphStyle.firstLineHeadIndent = leftMargin
                    paragraphStyle.headIndent = leftMargin + paragraph.keyLength
                    paragraphStyle.alignment = .left
                    paragraphStyle.tabStops = [NSTextTab(type: .leftTabStopType, location: leftMargin + paragraph.keyLength)]
                    paragraphStyle.defaultTabInterval = leftMargin != 0 ? leftMargin : 100.0 //100.0 // JUST FOR DEBUGGING

                    if paragraphText.string.hasPrefix("*") {
                        // A spacer line
                        paragraphText = NSMutableAttributedString(string: BUFFOON_CONSTANTS.COLLECTION_SPACER, attributes: self.scalarAttributes)
                        paragraphStyle.paragraphSpacing = 0.0
                    } else {
                        // Add a paragraph terminator, then apply the text paragraph style
                        paragraphText.append(self.cr)
                    }

                    // Add the paragraph attributed string to the main store
                    paragraphText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: paragraphText.length))
                    renderedPreview.append(paragraphText)
                }
            }
        }

        return renderedPreview
    }


    private func makeIndentParagraph(_ yaml: YAMLValue2, _ depth: Int = 0, _ prefix: NSMutableAttributedString?, _ paragraphs: NSMutableArray) {

        let showMarks = self.settings.showYamlMarks
        var thePrefix: NSMutableAttributedString? = prefix
        let fromCollection = prefix != nil
        let prefixWidth = showMarks && prefix != nil ? prefix!.width : 0.0

        let spacer = NSMutableAttributedString(string: " ", attributes: self.markAttributes)
        while spacer.width < prefixWidth {
            spacer.append(NSAttributedString(string: " ", attributes: self.markAttributes))
        }

        // Match the YAML entity by type to generate paragraph styled text
        if yaml.mapping != nil {

#if DEBUG
            print(String(repeating: " ", count: depth) + "Mapping @ \(depth), \(yaml.mapping!.count) pairs, \(yaml.mapping!.description)")
#endif

            // For an object (dictionary), enumerate the keys and their values
            for (key, value) in yaml.mapping! {

#if DEBUG
                print(String(repeating: " ", count: depth) + "* \(key.description), \(value.description)")
#endif

                // Is the value a collection?
                let valueIsObject = value.mapping != nil
                let valueIsArray = value.sequence != nil

                // First, render the key plus a separator, as required
                let keyString = NSMutableAttributedString(string: key.description, attributes: self.keyAttributes)
                keyString.append(NSAttributedString(string: showMarks ? " : " : "  ", attributes: self.markAttributes))
                var keyLength = keyString.width

                if thePrefix != nil {
                    // There is a header from a parent collection
                    keyString.insert(thePrefix!, at: 0)
                    keyLength = keyString.width
                    thePrefix = nil
                } else if fromCollection && showMarks {
                    keyString.insert(spacer, at: 0)
                    keyLength = keyString.width
                }

                // Now render the value
                if valueIsObject || valueIsArray || self.settings.doIndentScalars {
                    // The value is a collection type or an indented scalar: so key on this line, value on the next
                    if let lineEndComment = value.lineComment {
                        keyString.append(renderComment(lineEndComment))
                    }

                    paragraphs.add(Paragraph(text: keyString, depth: depth, keyLength: keyLength))
                    makeIndentParagraph(value, depth + 1, nil, paragraphs)
                } else {
                    // The value is a scalar: on this line after key
                    keyString.append(renderScalarValue(value))

                    if let lineEndComment = yaml.lineComment {
                        keyString.append(renderComment(lineEndComment))
                    }

                    paragraphs.add(Paragraph(text: keyString, depth: depth, keyLength: keyLength))
                }
            }
        } else if yaml.sequence != nil {

#if DEBUG
            print(String(repeating: " ", count: depth) + "Sequence @ \(depth) \(yaml.sequence!.description)")
#endif

            // For an array, enumerate the values
            // NOTE Should be only one of each, but value may be an object or array
            for (index, value) in yaml.sequence!.enumerated() {

#if DEBUG
                print(String(repeating: " ", count: depth) + "  \(index) \(value.description)")
#endif

                // Is the value a collection?
                let valueIsObject: Bool = value.mapping != nil
                let valueIsArray: Bool = value.sequence != nil
                let header = NSMutableAttributedString(string: showMarks ? "● " : "", attributes: self.markAttributes)

                // Render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    if prefix != nil {
                        if let c = value.lineComment {
                            thePrefix!.append(renderComment(c))
                        }

                        paragraphs.add(Paragraph(text: thePrefix!, depth: depth))
                    }

                    makeIndentParagraph(value, depth, header, paragraphs)
                } else {
                    // The value is a scalar
                    header.append(renderScalarValue(value))
                    paragraphs.add(Paragraph(text: header, depth: depth, keyLength: 0.0))
                }

                // Add a narrow spacer line after all collections except the last one in the array
                if index < yaml.sequence!.count - 1 && (valueIsArray || valueIsObject) {
                    paragraphs.add(Paragraph(text: NSMutableAttributedString(string: "", attributes: self.scalarAttributes), depth: depth))
                }
            }
        } else {
            // Standalone scalars
            let attributedScalar = NSMutableAttributedString(attributedString: renderScalarValue(yaml))
            paragraphs.add(Paragraph(text: attributedScalar, depth: depth, keyLength: 0.0))
        }
    }


    /**
     Convert a single scalar value, in any context, into an attributed string.

     - Parameters:
        - scalar: The value to convert.

     - Returns: An attributed string.
     */
    private func renderScalarValue(_ scalar: YAMLValue2) -> NSAttributedString {

        switch scalar.type {
            case .null:
                // Attempt to load the `NULL` symbol, but use a text version as a fallback on error
                return renderValue(scalar, "NULL", self.specialAttributes)
            case .bool:
                // Attempt to load the `TRUE`/`FALSE` symbol, but use a text version as a fallback on error
                return renderValue(scalar, "\(scalar.description)", self.specialAttributes)
            case .int, .double:
                // Display the number as is
                return renderValue(scalar, "\(scalar.description)", self.scalarAttributes)
            case .string:
                var style: [NSAttributedString.Key: Any]
                var isStringStyle = true
                var base = scalar.description.trimmingCharacters(in: .newlines)
                base = base.replacingOccurrences(of: "\n", with: "\n\t")

                // Handle explicitly typed scalars here as they'll be YAML-ised as strings
                if base.hasPrefix("!!") {
                    isStringStyle = false

                    let valueParts = base.components(separatedBy: .whitespaces)
                    let explicitTag = valueParts[0]
                    switch explicitTag {
                        case "!!int", "!!integer", "!!float", "!!double", "!!number":
                            style = self.scalarAttributes
                        case "!!bool", "!!boolean", "!!null", "!!~":
                            style = self.specialAttributes
                        default:
                            style = self.stringAttributes
                            isStringStyle = true
                    }

                    base = valueParts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                } else {
                    style = self.stringAttributes
                }

                // Wrap quotes in delimiters if marks are to be shown
                if self.settings.showYamlMarks && isStringStyle {
                    //base = "“\(base)”"
                }

                // Handle values with end-of-line comments
                if let comment = scalar.lineComment {
                    let attributedScalar = NSMutableAttributedString(string: "\(base)", attributes: style)
                    attributedScalar.append(renderComment(comment))
                    return attributedScalar
                }

                return NSAttributedString(string: base, attributes: style)
            default:
                // Single-line comments and directives
                var base = scalar.description.trimmingCharacters(in: .newlines)
                base = base.replacingOccurrences(of: "\n", with: "\n\t")
                if !self.settings.showYamlMarks {
                    base = String(base.dropFirst()).trimmingCharacters(in: .whitespaces)
                }

                var style: [NSAttributedString.Key: Any]
                if base.hasPrefix("#") {
                    style = self.commentAttributes
                } else {
                    style = self.specialAttributes
                }

                // Handle values with end-of-line comments
                if let comment = scalar.lineComment {
                    let attributedScalar = NSMutableAttributedString(string: "\(base)", attributes: style)
                    attributedScalar.append(renderComment(comment))
                    return attributedScalar
                }

                return NSAttributedString(string: base, attributes: style)
        }
    }


    /**
     Render a supplied string in the specified string,
     optionally with an end-of-line comment afterwards.

     - Parameters:
        - scalar:    The source YAML value.
        - valueText: The string to render.
        - style:     The attributes to apply to the value string.

     - Returns: An attributed string.
     */
    private func renderValue(_ scalar: YAMLValue2, _ valueText: String, _ style: [NSAttributedString.Key: Any]) -> NSAttributedString {

        if let comment = scalar.lineComment {
            let attributedScalar = NSMutableAttributedString(string: valueText, attributes: style)
            attributedScalar.append(renderComment(comment))
            return attributedScalar
        }

        return NSAttributedString(string: valueText, attributes: style)
    }


    /**
     Render a supplied comment string, optionally with tab prefix.

     - Parameters:
        - rawComment: The comment to render.
        - addTab:     `true` if the returned string should be prefixed with a tab.
                      Default: `true`.

     - Returns: An attributed string.
     */
    private func renderComment(_ rawComment: String, _ addTab: Bool = true) -> NSAttributedString {

        let comment: String
        if self.settings.showYamlMarks {
            comment = rawComment.trimmingCharacters(in: .whitespaces)
        } else {
            comment = String(rawComment.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        return NSAttributedString(string: addTab ? "\t\(comment)" : comment, attributes: self.commentAttributes)
    }


    /**
     Determine the max. width of each column based. A column width is determined by what it contains.

     - Parameters:
        - yaml:   A YAML node object, array or value.
        - depth:  The column inset of the YAML.
        - length: A dictionary mapping column number to current max. column width.

     - Returns: An updated `length` dictionary.

    private func measureColumns(_ yaml: YAMLValue, _ depth: Int, _ lengths: [Int: CGFloat]) -> [Int: CGFloat] {

        var maxLengths = lengths
        var inset = depth

        // Record the furthest column number
        if inset > self.maxDepth {
            self.maxDepth = inset
        }

        // Match the YAML entity by type to generate paragraph styled text
        if yaml.mapping != nil {
            // YAML entity is an OBJECT
            // Iterate over the object's keys and values
            for (key, value) in yaml.mapping! {
                let keyString = NSMutableAttributedString(string: key.description, attributes: self.keyAttributes)
                let keyWidth = keyString.width
                if maxLengths[inset] == nil || keyWidth > maxLengths[inset]! {
                    maxLengths[inset] = keyWidth
                }

                // Get interior value column widths
                maxLengths = measureColumns(value, inset + 1, maxLengths)
            }
        } else if yaml.sequence != nil {
            // YAML entity is an ARRAY
            for value in yaml.sequence! {
                maxLengths = measureColumns(value, inset, maxLengths)
            }
        } else {
            // YAML entity is a SCALAR
            if yaml.string != nil {
                // For strings, match column width to the width of wordless text (eg. a UUID) or,
                // for worded text (ie. contains spaces) the max column with (400pt) or the text
                // width, whichever is shorter
                let value = yaml.string!
                let valString = NSMutableAttributedString(string: value.description, attributes: self.stringAttributes)
                let valWidth = valString.width
                if value.description.contains(" ") && valWidth > 400.0 {
                    maxLengths[depth] = 400.0
                } else if maxLengths[depth] == nil || valWidth > maxLengths[depth]! {
                    maxLengths[depth] = valWidth
                }
            } else if yaml.int != nil || yaml.float != nil {
                let value = yaml.string
                let valString = NSMutableAttributedString(string: value!.description, attributes: self.scalarAttributes)
                let valWidth = valString.width
                if maxLengths[depth] == nil || valWidth > maxLengths[depth]! {
                    maxLengths[depth] = valWidth
                }
            }
        }

        return maxLengths
    }


    private func prettify(_ yaml: YAMLValue, _ depth: Int, _ prefix: NSMutableAttributedString?, _ paragraphs: NSMutableArray) {

        let thePrefix = prefix ?? NSMutableAttributedString(string: "", attributes: self.scalarAttributes)

        if yaml.mapping != nil {
            // For an object (dictionary), enumerate the keys and their values
            for (key, value) in yaml.mapping! {
                // Is the value a collection?
                let valueIsObject: Bool = value.mapping != nil
                let valueIsArray: Bool = value.sequence != nil

                // First, render the key plus a separator
                let separator = self.settings.showYamlMarks ? ":" + BUFFOON_CONSTANTS.TAB : BUFFOON_CONSTANTS.TAB
                let keyString = NSMutableAttributedString(string: key.description, attributes: self.keyAttributes)
                keyString.append(NSAttributedString(string: separator, attributes: self.markAttributes))

                // Now render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    paragraphs.add(Paragraph(text: keyString, depth: depth, keyLength: keyString.width))
                    prettify(value, depth + 1, nil, paragraphs)
                } else {
                    // The value is a scalar
                    // NOTE The key has a trailing space, so no extra indent is required for the scalar value
                    prettify(value, depth, keyString, paragraphs)
                }
            }
        } else if yaml.sequence != nil {
            // For an array, enumerate the values
            // NOTE Should be only one of each, but value may be an object or array
            for (index, value) in yaml.sequence!.enumerated() {
                // Is the value a collection?
                let valueIsObject: Bool = value.mapping != nil
                let valueIsArray: Bool = value.sequence != nil

                // Render the value
                if valueIsObject || valueIsArray {
                    // The value is a collection type
                    if thePrefix.length > 0 {
                        paragraphs.add(Paragraph(text: thePrefix, depth: depth))
                    }

                    prettify(value, depth, nil, paragraphs)
                } else {
                    // The value is a scalar
                    prettify(value, depth, nil, paragraphs)
                }
                 
                // Add a narrow spacer line after all collections except the last one in the array
                if index < yaml.sequence!.count - 1 && (valueIsArray || valueIsObject) {
                    //paragraphs.add(Paragraph(text: NSMutableAttributedString(string: "*", attributes: self.scalarAttributes), depth: depth))
                }
            }
        } else {
            // Process the scalar value
            let keyLength = thePrefix.length > 0 ? thePrefix.width : 0.0
        }
    }
     */

}

