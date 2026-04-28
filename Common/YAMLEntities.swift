import Foundation


/*
 A Paragraph as extracted from a line of YAML.
 */
public class Paragraph {

    var text: NSMutableAttributedString? = nil      // The paragraph's styled text
    var depth: Int = 0                              // The paragraph's column number
    var keyLength: CGFloat = 0.0                    // If the paragraph is prefixed with a key, the key's length in points

    init(text: NSMutableAttributedString? = nil, depth: Int = 0, keyLength: CGFloat = 0.0) {

        self.text = text
        self.depth = depth
        self.keyLength = keyLength
    }
}


/*
 Indication of a comment’s location in the line.
 */
public enum YAMLCommentType {

    case line
    case lineEnd
    case none
}


/*
 Decoded representation of each line in the source YAML, including
 lookaheead information to assist in subsequent parsing.
 */
internal struct Line {

    // Properties
    let number: Int                                 // Line number in input order
    var indent: Int = 0                             // Number of spaces prefixing the line
    let text: String                                // The actual text of the line
    var comment: String? = nil
    var commentType: YAMLCommentType = .none        // Where the comment is: end of line or whole line

    // Accessors
    var isEmpty: Bool {
        text.isEmpty
    }

    var isDocStart: Bool {
        text == "---" || text.hasPrefix("--- ")
    }

    var isDocEnd: Bool {
        text == "..."
    }
}


/*
 Indication of a YAML entity's type.

 NOTE This is broader than the official list, in order to cater
      for special types relevant to how the output will be used.
 */
public enum YAMLType {

    // Official types
    case null
    case bool
    case int
    case double
    case string
    case sequence
    case mapping
    // Non-official types
    case special
    case directive
    case comment
}


/*
 A YAML value.
 */
public struct YAMLValue2 {

    // Properties
    var value: Any? = nil               // The raw value of the instance.
    var type: YAMLType = .null          // The type of value the instance represents.
    var lineComment: String? = nil      // A comment at the end of the declaring line, or `nil`.

    // Accessors for the instance's value
    public var string: String? {
        if self.type == .string {
            return value as? String
        }

        return nil
    }

    public var special: String? {
        if self.type == .special {
            return value as? String
        }

        return nil
    }

    public var directive: String? {
        if self.type == .directive {
            return value as? String
        }

        return nil
    }

    public var comment2: String? {
        if self.type == .comment {
            return value as? String
        }

        return nil
    }

    public var int: Int? {
        if self.type == .int {
            return value as? Int
        }

        return nil
    }

    public var float: Double? {
        if self.type == .double {
            return value as? Double
        }

        return nil
    }

    public var bool: Bool? {
        if self.type == .bool {
            return value as? Bool
        }

        return nil
    }

    public var isNull: Bool {
        return self.type == .null
    }

    public var sequence: [YAMLValue2]? {
        if self.type == .sequence {
            return value as? [YAMLValue2]
        }

        return nil
    }

    public var mapping: [(key: String, value: YAMLValue2)]? {
        if self.type == .mapping {
            return value as? [(key: String, value: YAMLValue2)]
        }

        return nil
    }
}


extension YAMLValue2: CustomStringConvertible {

    /**
     Get a textual rendition of the struct's `value` property.
     */
    public var description: String {
        
        switch self.type {
            case .string, .directive, .special, .comment:
                return self.value as! String
            case .int:
                return String(self.value as! Int)
            case .double:
                return String(self.value as! Double)
            case .bool:
                let boolValue = self.value as! Bool
                return boolValue ? "TRUE" : "FALSE"
            case .null:
                return "NULL"
            case .sequence:
                let arrayValue = self.value as! [YAMLValue2]
                return "[\(arrayValue.map(\.description).joined(separator: ", "))]"
            case .mapping:
                let objectValue = self.value as! [(key: String, value: YAMLValue2)]
                return "{\(objectValue.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", "))}"
        }
    }
}


/*

 */
internal final class YAMLParser {

    // MARK: - Public Properties

    var lines: [Line] = []
    var pos: Int = 0
    var emptyLinesLastSkipped: Int = 0
    var currentLineComment: String? = nil


    // MARK: - Lifecycle Methods

    init(rawYaml: String) {

        let rawLines = rawYaml.components(separatedBy: "\n")
        self.lines = rawLines.enumerated().map {
            Self.processLine($0.element, $0.offset)
        }
    }


    // MARK: - Line processing

    /**
     Convert a single line of the YAML string source.

     - Parameters:
        - rawLine: The line read from the input file.

     - Returns: The input as a Line entity, to be parsed later.
     */
    private static func processLine(_ rawLine: String, _ lineNumber: Int) -> Line {

        let indent = rawLine.prefix(while: { $0 == " " }).count
        let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.hasPrefix("#") {
            // A whole-line comment
            return Line(number: lineNumber, indent: indent, text: trimmedLine, commentType: .line)
        }

        if trimmedLine.hasPrefix("%") {
            // YAML directive
            return Line(number: lineNumber, indent: indent, text: trimmedLine)
        }

        // Get the line text and any EOL comment
        let (lineText, lineEndComment) = stripInlineComment(trimmedLine)
        let commentType: YAMLCommentType = lineEndComment != nil ? .lineEnd : .none
        return Line(number: lineNumber, indent: indent, text: lineText, comment: lineEndComment, commentType: commentType)
    }


    /**
     Remove an inline comment that is not inside quotes.

     - Parameters:
        - lineText: The input string.

     - Returns: The stripped string.
     */
    private static func stripInlineComment(_ lineText: String) -> (String, String?) {

        var inSingle = false
        var inDouble = false
        var prev: Character = "\0"
        var index = lineText.startIndex
        while index < lineText.endIndex {
            let c = lineText[index]
            if c == "'" && !inDouble {
                inSingle.toggle()
            } else if c == "\"" && !inSingle {
                inDouble.toggle()
            } else if c == "#" && !inSingle && !inDouble && (prev == " " || prev == "\t" || prev == "\0") {
                // Hand back text + comment as tuple
                return (String(lineText[lineText.startIndex..<index]).trimmingCharacters(in: .whitespaces), // line
                        String(lineText[index...]).trimmingCharacters(in: .whitespaces))                    // end-of-line comment
            }

            prev = c
            index  = lineText.index(after: index)
        }

        return (lineText, nil)
    }


    // MARK: - Document parsing

    /**
     Convert the object's lines to a sequence of YAML values.

     - Returns: An array of YAML values, or `nil` on error.
     */
    public func parse() -> [YAMLValue2]? {

        // Bail if there's nothing to process
        guard !lines.isEmpty else { return nil }

        var yamlDocs: [YAMLValue2] = []
        while pos < lines.count {
            guard skipEmptyLines() else { break }

            let line = lines[pos]
            if line.isDocEnd {
                // Consume end-of-doc marker, and continue in case there's
                // another doc after this one
                pos += 1
                continue
            }

            if line.isDocStart {
                // Consume the start-of-doc marker
                pos += 1
                if skipEmptyLines(), !lines[pos].isDocStart, !lines[pos].isDocEnd {
                    // Parse the doc's body
                    yamlDocs.append(parseNode(0))
                } else {
                    yamlDocs.append(YAMLValue2())
                }
            } else {
                // Parse the file body when doc markers are not used
                yamlDocs.append(parseNode(0))
            }
        }

        return yamlDocs
    }


    // MARK: - Node dispatch

    /**
     Parse the next YAML node in the file.

     - Parameters:
        - minIndent: The level of indentation the entity must meet.

     - Returns:A YAML value.
     */
    func parseNode(_ minIndent: Int) -> YAMLValue2 {

        // Go to next full line, or return null if there are no lines left
        guard skipEmptyLines() else { return YAMLValue2() }

        // Check for a valid line (indented to the same or greater than base)
        let line = lines[pos]
        guard !line.isDocStart, !line.isDocEnd, line.indent >= minIndent else { return YAMLValue2() }

        // Check the line's content
        let text = line.text
        if text.hasPrefix("%") || text.hasPrefix("#") {
            // Line starts with a directive or a comment
            pos += 1
            return YAMLValue2(value: text, type: text.hasPrefix("%") ? .directive : .comment)
        }

        if text.hasPrefix("- ") || text == "-" {
            // Minus sign indicates the start of a sequence
            return parseSequence(line.indent)
        }

       if findColonIndex(in: text) != nil {
           // Colon indicates a key
           return parseMapping(line.indent, nil)
        }

        if isBlockScalarHeader(text) {
            // Found a block marker
            return parseBlockScalar()
        }

        // Treat remaining text as a scalar value
        return parsePlainScalar(line.indent)
    }


    /**
     Convert a YAML sequence.

     - Parameters:
        - indent: The level of indentation of the parent entity.

     - Returns:A YAML entity.
     */
    func parseSequence(_ indent: Int) -> YAMLValue2 {

        var sequenceItems: [YAMLValue2] = []

        while pos < lines.count {
            guard skipEmptyLines() else {
                break
            }

            let line = lines[pos]
            if line.isDocStart || line.isDocEnd {
                break
            }

            if line.indent != indent {
                // This is where nesting breaks down because
                // line.indent < indent (which can be valid)
                // but in our special case, it is not!
                // So question is: how to end a nested sequence
                // when it is NOT indented below the parent mapping's
                // key???
                break
            }

            guard line.text.hasPrefix("- ") || line.text == "-" else {
                break
            }

            pos += 1

            // Get line content: usually what's after the `- `
            let rest = line.text == "-" ? "" : String(line.text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if rest.isEmpty {
                if skipEmptyLines(), lines[pos].indent > indent, !lines[pos].isDocStart, !lines[pos].isDocEnd {
                    sequenceItems.append(parseNode(indent + 1))
                } else {
                    sequenceItems.append(YAMLValue2())
                }
            } else if isBlockScalarHeader(rest) {
                sequenceItems.append(parseBlockScalarBody(indent + 1, rest))
            } else if findColonIndex(in: rest) != nil {
                // Pass the sequence's own indent as valueThreshold so that content
                // sitting at (seq_indent + 2) is correctly found as the key's value
                // rather than failing the "indent > mapping_indent" check.
                sequenceItems.append(parseMapping(indent + 1, rest, indent))
            } else if rest.hasPrefix("- ") || rest == "-" {
                sequenceItems.append(parseScalar(rest))   // best-effort for a sequence marker immediately after a sequence marker
            } else {
                // Scalar
                var val = parseScalar(rest)
                val.lineComment = line.comment
                sequenceItems.append(val)
            }
        }

        return YAMLValue2(value: sequenceItems, type: .sequence)
    }


    /**
     Convert a YAML mapping.

     - Parameters:
        - indent:         The level of indentation of the parent entity.
        - injectFirst:    Optionally, a string to process ahead of the rest.
        - valueThreshold: Optionally, an additional indent value.

     - Returns: A YAML entity.
     */
    func parseMapping(_ indent: Int, _ injectFirst: String?, _ valueThreshold: Int? = nil) -> YAMLValue2 {

        var pairs: [(key: String, value: YAMLValue2)] = []
        var threshold = valueThreshold ?? indent

        func absorb(_ text: String, _ comment: String? = nil) {

            guard let i = findColonIndex(in: text) else {
                return
            }

            // Get the key...
            let rawKey = String(text[text.startIndex..<i]).trimmingCharacters(in: .whitespaces)
            let key = unquoteScalar(rawKey)

            // ...and its value
            let rawVal = String(text[text.index(after: i)...]).trimmingCharacters(in: .whitespaces)
            if rawVal.hasPrefix("#") || rawVal.isEmpty {
                // Value is on subsequent lines.
                // NOTE When a mapping is injected from a sequence item (`- key:`)
                //      the content indent equals the mapping's own indent, so we use
                //      the sequence's indent (valueThreshold) as the lookahead floor
                //      instead of the mapping's indent, which would make > fail.
                threshold = valueThreshold ?? indent
                guard skipEmptyLines(), !lines[pos].isDocStart, !lines[pos].isDocEnd else {
                    pairs.append((key: key, value: YAMLValue2(type: .null)))
                    return
                }

                let nextLine = lines[pos]
                let seqAtSameIndent = nextLine.indent == indent && (nextLine.text.hasPrefix("- ") || nextLine.text == "-")
                if nextLine.indent > threshold || seqAtSameIndent {
                    let minIndent = seqAtSameIndent ? indent : threshold + 1
                    var val = parseNode(minIndent)
                    val.lineComment = comment
                    pairs.append((key: key, value: val))
                } else {
                    pairs.append((key: key, value: YAMLValue2(type: .null)))
                }
            } else if isBlockScalarHeader(rawVal) {
                pairs.append((key: key, value: parseBlockScalarBody(indent + 2, rawVal)))
            } else {
                var val = parseScalar(rawVal)
                val.lineComment = comment
                pairs.append((key: key, value: val))
            }
        }

        // An injected first line is used when we encounter "- key: value"
        // inside a sequence; we already consumed that line.
        if let first = injectFirst {
            absorb(first)
        }

        while pos < lines.count {
            guard skipEmptyLines() else {
                break
            }

            let line = lines[pos]
            if line.isDocStart || line.isDocEnd || line.indent < indent {
                break
            }

            guard findColonIndex(in: line.text) != nil else {
                break
            }

            // Consume the key line before absorbing it
            pos += 1
            absorb(line.text, line.comment)
        }

        return YAMLValue2(value: pairs, type: .mapping)
    }


    // MARK: - Block scalars  (| and >)

    /**
     Does the input string contain a YAML block marker?

     - Parameters:
        - s: The input string.

     - Returns: `true` if there’s any kind of block marker, otherwise `false`.
     */
    private func isBlockScalarHeader(_ s: String) -> Bool {

        let stripped = s.trimmingCharacters(in: .whitespaces)
        return stripped == "|"  || stripped == "|-" || stripped == "|+" || stripped == ">"  ||
               stripped == ">-" || stripped == ">+" || stripped.hasPrefix("| ") || stripped.hasPrefix("> ")
    }


    /**
     Does the input string contain a YAML block marker?

     - Returns: A YAML entity.
     */
    func parseBlockScalar() -> YAMLValue2 {

        let style = lines[pos].text
        pos += 1
        return parseBlockScalarBody(-1, style)
    }

    /**

     - Parameters:
        - bodyIndentHint: The expected indentation of the body. Pass -1 to auto-detect from the first content line.
        - style:          The block marker, ie. what type it is.

     - Returns: A YAML node.
     */
    func parseBlockScalarBody(_ bodyIndentHint: Int, _ style: String) -> YAMLValue2 {

        let isLiteral = style.hasPrefix("|")
        let chomping: Character = {
            let last = style.last
            if last == "-" { return "-" }
            if last == "+" { return "+" }
            // Clip
            return " "
        }()

        // Determine the effective indent from the first non-empty body line.
        var bodyIndent = bodyIndentHint
        if bodyIndent < 0 {
            var i = pos
            while i < lines.count && lines[i].isEmpty {
                i += 1
            }

            bodyIndent = i < lines.count ? lines[i].indent : 0
        }

        var collected: [String] = []
        while pos < lines.count {
            let line = lines[pos]
            if line.isDocStart || line.isDocEnd || (!line.isEmpty && line.indent < bodyIndent) {
                break
            }

            collected.append(line.text)
            pos += 1
        }

        // Apply chomping.
        switch chomping {
            case "-":
                // Strip – remove all trailing newlines
                while let last = collected.last, last.isEmpty {
                    collected.removeLast()
                }
            case "+":
                // Keep – preserve all trailing newlines (nothing to do)
                break
            default:
                // Clip – one trailing newline
                while collected.count > 1, let last = collected.last, last.isEmpty {
                    collected.removeLast()
                }
        }

        let result: String
        if isLiteral {
            result = collected.joined(separator: "\n") + (chomping == " " ? "\n" : "")
        } else {
            // Folded: blank lines stay as literal newlines;
            // non-blank lines are joined with a space.
            var out = ""
            var first = true
            var i = 0
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

            if chomping == " " {
                out += "\n"
            }

            result = out
        }

        return YAMLValue2(value: result, type: .string)
    }


    // MARK: - Scalar parsing

    func parsePlainScalar(_ bodyIndent: Int) -> YAMLValue2 {

        var parts: [String] = []
        while pos < lines.count {
            let line = lines[pos]
            if line.isEmpty || line.isDocStart || line.isDocEnd || line.indent != bodyIndent {
                // A blank line or an indentation change ends scalar
                break
            }

            if findColonIndex(in: line.text) != nil {
                // A new key:value pair ends scalar
                break
            }

            if line.text.hasPrefix("- ") || line.text == "-" {
                // A new sequence ends scalar
                break
            }

            if isBlockScalarHeader(line.text) {
                // A block marker ends scalar
                break
            }

            parts.append(line.text)
            pos += 1
        }

        return parseScalar(parts.joined(separator: " "))
    }


    func parseScalar(_ scalar: String) -> YAMLValue2 {

        let text = scalar.trimmingCharacters(in: .whitespaces)

        // Handle special values
        if text == "null" || text == "~" || text.isEmpty {
            return YAMLValue2()
        }

        switch text.lowercased() {
            case "true", "yes", "on":
                return YAMLValue2(value: true, type: .bool)
            case "false", "no", "off":
                return YAMLValue2(value: false, type: .bool)
            default:
                break
        }

        switch text {
            case ".inf", "+.inf", ".Inf", "+.Inf", ".INF", "+.INF":
                return YAMLValue2(value: Double.infinity, type: .double)
            case "-.inf", "-.Inf", "-.INF":
                return YAMLValue2(value: Double.infinity, type: .double)
            case ".nan",  ".NaN",  ".NAN":
                return YAMLValue2(value: Double.nan, type: .double)
            default:
                break
        }

        // Handle Integer literals (decimal, hex, octal, binary)
        if text.hasPrefix("0x") || text.hasPrefix("0X"), let i = Int(text.dropFirst(2), radix: 16) {
            return YAMLValue2(value: i, type: .int)
        }

        if text.hasPrefix("0o") || text.hasPrefix("0O"), let i = Int(text.dropFirst(2), radix: 8) {
            return YAMLValue2(value: i, type: .int)
        }

        if text.hasPrefix("0b") || text.hasPrefix("0B"), let i = Int(text.dropFirst(2), radix: 2) {
            return YAMLValue2(value: i, type: .int)
        }

        if let i = Int(text) {
            return YAMLValue2(value: i, type: .int)
        }

        if let d = Double(text) {
            return YAMLValue2(value: d, type: .double)
        }

        // Handle double-quoted strings
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count >= 2 {
            return YAMLValue2(value: unescapeDouble(String(text.dropFirst().dropLast())), type: .string)
        }

        // Handle single-quoted strings
        if text.hasPrefix("'") && text.hasSuffix("'") && text.count >= 2 {
            let inner = String(text.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
            return YAMLValue2(value: inner, type: .string)
        }

        // Handle flow sequence or mapping, failing to a string representation
        if text.hasPrefix("[") {
            return parseFlowSequence(text) ?? YAMLValue2(value: text, type: .string)
        }

        if text.hasPrefix("{") {
            return parseFlowMapping(text) ?? YAMLValue2(value: text, type: .string)
        }

        // Fallback - represent as a string
        return YAMLValue2(value: text, type: .string)
    }


    /**
     Remove single- or double-quote marks from a scalar value.

     - Parameters:
        - s: The input string.

     - Returns: The inner string content.
     */
    private func unquoteScalar(_ s: String) -> String {

        if (s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2) ||
           (s.hasPrefix("'")  && s.hasSuffix("'")  && s.count >= 2) {
            return String(s.dropFirst().dropLast())
        }

        return s
    }


    /**
     Handle unescaped double-quote marks.

     - Parameters:
        - s: The input string.

     - Returns: The updated string.
     */
    private func unescapeDouble(_ s: String) -> String {
        
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            // Check for escaped escape
            if c == "\\" {
                let next = s.index(after: i)
                guard next < s.endIndex else {
                    result.append(c)
                    break
                }

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
                        result.append("\\")
                        result.append(s[next])
                }

                i = s.index(after: next)
            } else {
                result.append(c)
                i = s.index(after: i)
            }
        }

        return result
    }


    /**
     Parse a flow sequence (array).

     - Parameters:
        - s: The input string.

     - Returns: The array as a YAML entity, or `nil`.
     */
    private func parseFlowSequence(_ s: String) -> YAMLValue2? {

        // Verify the markers
        guard s.hasPrefix("["), s.hasSuffix("]") else {
            return nil
        }

        let innerContent = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if innerContent.isEmpty {
            // Hand back an empty array
            return YAMLValue2(value: [], type: .sequence)
        }

        // Assemble and return an array of parsed elementss
        let val = splitFlowItems(innerContent).map {
            parseScalar($0.trimmingCharacters(in: .whitespaces))
        }

        return YAMLValue2(value: val, type: .sequence)
    }


    /**
     Parse a flow mapping (object).

     Remember, mappings are stored as arrays of key:value pairs to
     preserve representation order.

     - Parameters:
        - s: The input string.

     - Returns: The object as a YAML entity, or `nil`.
     */
    private func parseFlowMapping(_ s: String) -> YAMLValue2? {

        // Verify the markers
        guard s.hasPrefix("{"), s.hasSuffix("}") else {
            return nil
        }

        let innerContent = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if innerContent.isEmpty {
            // Hand back an empty mapping
            return YAMLValue2(value: [], type: .mapping)
        }

        // Segment into a key value pairs to preserve the order
        var pairs: [(key: String, value: YAMLValue2)] = []
        for item in splitFlowItems(innerContent) {
            let itemText = item.trimmingCharacters(in: .whitespaces)
            guard let i = findColonIndex(in: itemText) else {
                continue
            }

            let key = String(itemText[itemText.startIndex..<i]).trimmingCharacters(in: .whitespaces)
            let val = String(itemText[itemText.index(after: i)...]).trimmingCharacters(in: .whitespaces)
            pairs.append((key: unquoteScalar(key), value: parseScalar(val)))
        }

        return YAMLValue2(value: pairs, type: .mapping)
    }


    /**
     Splits a comma-separated flow string, respecting nested brackets and quotes.

     - Parameters:
        - s: The Input string

     - Returns: An array of string elements
     */
    private func splitFlowItems(_ s: String) -> [String] {

        var items: [String] = []
        var depth = 0
        var inSingle = false
        var inDouble = false
        var current = ""

        for c in s {
            if c == "'" && !inDouble {
                inSingle.toggle()
            } else if c == "\"" && !inSingle {
                inDouble.toggle()
            } else if !inSingle && !inDouble {
                if c == "[" || c == "{" {
                    depth += 1
                } else if c == "]" || c == "}" {
                    depth -= 1
                } else if c == "," && depth == 0 {
                    items.append(current)
                    current = ""
                    continue
                }
            }

            current.append(c)
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(current)
        }

        return items
    }


    // MARK: - Utility Methods

    /**
     Step over blank lines at the current cursor position.
     */
    func skipEmptyLines() -> Bool {

        let oldPos = pos
        while pos < lines.count && lines[pos].isEmpty {
            pos += 1
        }

        self.emptyLinesLastSkipped = pos - oldPos
        return pos < lines.count
    }


    /**
     Locate the index of the `:` that introduces a mapping value.
     Skips colons between quotes.

     - Parameters:
        - line: The line to check.

     - Returns: The string index of the colon, or `nil`.
     */
    func findColonIndex(in line: String) -> String.Index? {

        var inSingle = false
        var inDouble = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "'" && !inDouble {
                inSingle.toggle()
            } else if c == "\"" && !inSingle {
                inDouble.toggle()
            } else if c == ":" && !inSingle && !inDouble {
                let next = line.index(after: i)
                // YAML specification: mapping colons MUST be followed by a space, tab or end-of-string.
                if next == line.endIndex || line[next] == " " || line[next] == "\t" {
                    // Hand back the index
                    return i
                }
            }

            i = line.index(after: i)
        }

        // No colon found
        return nil
    }

}


/*
 A YAML entity which preserves the order of keys in mappings (objects),
 and elements in sequences (arrays).

public indirect enum YAMLValue {

    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case special(String)
    case sequence([YAMLValue])
    case mapping([(key: String, value: YAMLValue)])

    // Accessors
    public var string: String? {
        if case .string(let v) = self {
            return v
        }

        return nil
    }

    public var special: String? {
        if case .special(let v) = self {
            return v
        }

        return nil
    }

    public var int: Int? {
        if case .int(let v) = self {
            return v
        }

        return nil
    }

    public var float: Double? {
        if case .double(let v) = self {
            return v
        }

        return nil
    }

    public var bool: Bool? {
        if case .bool(let v) = self {
            return v
        }

        return nil
    }

    public var isNull: Bool {
        if case .null = self {
            return true
        }

        return false
    }

    public var sequence: [YAMLValue]? {
        if case .sequence(let v) = self {
            return v
        }

        return nil
    }

    public var mapping: [(key: String, value: YAMLValue)]? {
        if case .mapping(let v) = self {
            return v
        }

        return nil
    }
}


extension YAMLValue: CustomStringConvertible {

    public var description: String {

        switch self {
            case .string(let s):
                return s
            case .special(let s):
                return s
            case .int(let n):
                return String(n)
            case .double(let n):
                return String(n)
            case .bool(let b):
                return b ? "TRUE" : "FALSE"
            case .null:
                return "NULL"
            case .sequence(let array):
                return "[\(array.map(\.description).joined(separator: ", "))]"
            case .mapping(let object):
                return "{\(object.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", "))}"

        }
    }
}
*/
