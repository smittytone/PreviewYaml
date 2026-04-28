import Foundation


public class Paragraph2 {

    var text: NSMutableAttributedString? = nil      // The paragraph's styled text
    var depth: Int = 0                              // The paragraph's column number
    var keyLength: CGFloat = 0.0                    // If the paragraph is prefixed with a key, the key's length in points

    init(text: NSMutableAttributedString? = nil, depth: Int = 0, keyLength: CGFloat = 0.0) {

        self.text = text
        self.depth = depth
        self.keyLength = keyLength
    }
}


public enum LineType {

    case comment
    case directive
    case mappingKey
    case sequenceItem
}


internal struct Line2 {

    let number: Int                                 // Line number in input order
    var indent: Int = 0                             // Number of spaces prefixing the line
    let text: String                                // The actual text of the line

    var comment: String? = nil
    var commentType: YAMLCommentType = .none        // Where the comment is
    var startDepth: Int = 0                         // Collections ONLY -- debut indent, to help check end
    var depth: Int = 0

    var isEmpty: Bool {
        text.isEmpty
    }

    var isDocStart: Bool {
        text == "---" || text.hasPrefix("--- ")
    }

    var isDocEnd: Bool {
        text == "..."
    }

    var isComment: Bool {
        text.hasPrefix("#")
    }

    var isDirective: Bool {
        text.hasPrefix("%")
    }
}


internal final class YAMLParser2 {

    // We keep the source/raw lines so that block-scalar bodies
    // can be read without comment-stripping.
    private var lines: [Line2] = []
    private var pos = 0
    private var emptyLinesLastSkipped = 0
    private var anchors: [String:String] = [:]


    // MARK: - Lifecycle Methods

    init(yamlText: String) {

        let raws = yamlText.components(separatedBy: "\n")
        self.lines = raws.enumerated().map {
            Self.processLine($0.element, $0.offset)
        }
    }


    // MARK: - Line processing

    /**
     Convert a single line of the YAML string source.

     - Parameters:
     - raw: The input string.

     - Returns The input as a Line entity, to be parsed later.
     */
    private static func processLine(_ rawLine: String, _ lineNumber: Int) -> Line2 {

        let indent = rawLine.prefix(while: { $0 == " " }).count
        let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return Line2(number: lineNumber, indent: indent, text: trimmedLine)
    }


    /**
     Remove an inline comment that is not inside quotes.

     - Parameters:
     s: The input string.

     - Returns: The stripped string.
     */
    private func stripInlineComment(_ lineText: String) -> (String, String?) {

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
                return (String(lineText[lineText.startIndex..<index]).trimmingCharacters(in: .whitespaces), String(lineText[index...]).trimmingCharacters(in: .whitespaces))
            }

            prev = c
            index  = lineText.index(after: index)
        }

        return (lineText, nil)
    }


    public func parse() -> String {

        var output = ""
        pos = 0
        var col = 0

        while pos < lines.count {
            guard skipEmptyLines() else { break }

            let line = lines[pos]
            let text = line.text
            if line.isComment {
                output += "<comment>\(text)<\\comment>\n"
                pos += 1
                continue
            }

            if line.isDirective {
                output += "<directive>\(text)<\\directive>\n"
                pos += 1
                continue
            }

            if line.isDocStart || line.isDocEnd {
                output += "<break>\n"
                pos += 1
                continue
            }

            var i = findColonIndex(in: text)
            if i != nil {
                let rawKey = String(text[text.startIndex..<i!]).trimmingCharacters(in: .whitespaces)
                let key = unquoteScalar(rawKey)
                output += "<key>\(key)<\\key>"

                var rawVal = String(text[text.index(after: i!)...]).trimmingCharacters(in: .whitespaces)
                if rawVal.hasPrefix("#") {
                    // Post-key comment
                    output += "<comment>\(rawVal)<\\comment>\n"
                    rawVal = ""
                }

                if rawVal.isEmpty {
                    output += "\n"
                    continue
                }

                let (lineText, comment) = stripInlineComment(text)
                output += parseValue(lineText)
                if let c = comment {
                    output += " <comment>\(c)<\\comment>\n"
                }

                pos += 1
                continue
            }

            if text.hasPrefix("- ") || text == "-" {
                output += "<item>"
                let rest = text == "-" ? "" : String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if rest.hasPrefix("#") {
                    // Post-key comment
                    output += "NULL<//item> <comment>\(rest)<\\comment>\n"
                    pos += 1
                    continue
                }

                if rest.isEmpty {
                    output += "NULL<//item>\n"
                    pos += 1
                    continue
                }

                i = findColonIndex(in: rest)
                if i != nil {
                    // mapping item
                    output += "<//item>\n"
                    pos += 1
                    continue
                }

                let (lineText, comment) = stripInlineComment(text)
                output += parseValue(lineText)
                if let c = comment {
                    output += "<//item> <comment>\(c)<\\comment>\n"
                } else {
                    output += "<//item>"
                }

                pos += 1
                continue
            }
        }

        return output
    }


    private func parseValue(_ text: String) -> String {

        let parts = text.components(separatedBy: " ")
        var output = ""

        if text.hasPrefix("&") {
            let anchor = parts[0]
            anchors[anchor] = ""
        }

        let rawValue = parts.dropFirst().joined(separator: " ")
        output += parseScalar(rawValue)
        return output
    }

    func parseScalar(_ scalar: String) -> String {

        let text = scalar.trimmingCharacters(in: .whitespaces)

        // Handle special values
        if text == "null" || text == "~" || text.isEmpty {
            return "<special>NULL<\\special>"
        }

        switch text.lowercased() {
            case "true", "yes", "on":
                return "<special>TRUE<\\special>"
            case "false", "no", "off":
                return "<special>FALSE<\\special>"
            default:
                break
        }

        switch text {
            case ".inf", "+.inf", ".Inf", "+.Inf", ".INF", "+.INF":
                return "<scalar>+INFINITY<\\special>"
            case "-.inf", "-.Inf", "-.INF":
                return "<scalar>-INFINITY<\\special>"
            case ".nan",  ".NaN",  ".NAN":
                return "<scalar>NaN<\\special>"
            default:
                break
        }

        // Handle Integer literals (decimal, hex, octal, binary)
        if text.hasPrefix("0x") || text.hasPrefix("0X"), let i = Int(text.dropFirst(2), radix: 16) {
            return "<scalar>\(i)<\\scalar"
        }

        if text.hasPrefix("0o") || text.hasPrefix("0O"), let i = Int(text.dropFirst(2), radix: 8) {
            return "<scalar>\(i)<\\scalar"
        }

        if text.hasPrefix("0b") || text.hasPrefix("0B"), let i = Int(text.dropFirst(2), radix: 2) {
            return "<scalar>\(i)<\\scalar"
        }

        if let i = Int(text) {
            return "<scalar>\(i)<\\scalar"
        }

        if let d = Double(text) {
            return "<scalar>\(d)<\\scalar"
        }

        // Handle double-quoted strings
        if text.hasPrefix("\"") && text.hasSuffix("\"") && text.count >= 2 {
            return "<string>\(unescapeDouble(String(text.dropFirst().dropLast())))<\\string>"
        }

        // Handle single-quoted strings
        if text.hasPrefix("'") && text.hasSuffix("'") && text.count >= 2 {
            let inner = String(text.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
            return "<string>\(inner)<\\string>"
        }

        // Handle flow sequence (array) or mapping (object)
        if text.hasPrefix("[") {
            return parseFlowSequence(text) ?? "<string>\(text)<\\string>"
        }

        if text.hasPrefix("{") {
            return parseFlowMapping(text) ?? "<string>\(text)<\\string>"
        }

        return "<string>\(text)<\\string>"
    }


    private func unquoteScalar(_ s: String) -> String {

        if (s.hasPrefix("\"") && s.hasSuffix("\"") && s.count >= 2) || (s.hasPrefix("'")  && s.hasSuffix("'")  && s.count >= 2) {
            return String(s.dropFirst().dropLast())
        }

        return s
    }


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


    func parseFlowSequence(_ text: String) -> String? {

        // Check for markers IS THIS NECESSARY? WOULDN'T BE HERE WITHOUT THEM
        guard text.hasPrefix("["), text.hasSuffix("]") else {
            return nil
        }

        let innerContent = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)

        // Is it an empty array?
        if innerContent.isEmpty {
            return ""
        }

        // Assemble and return an array of parsed elements
        return splitFlowItems(innerContent)
    }


    func parseFlowMapping(_ text: String) -> String? {

        // Check for markers IS THIS NECESSARY? WOULDN'T BE HERE WITHOUT THEM
        guard text.hasPrefix("{"), text.hasSuffix("}") else {
            return nil
        }

        let innerContent = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)

        // Is it an empty object?
        if innerContent.isEmpty {
            return ""
        }

        // Segment into a key value pairs to preserve the order
        return splitFlowItems(innerContent)
    }


    func splitFlowItems(_ text: String) -> String {

        var items = ""
        var depth = 0
        var inSingle = false
        var inDouble = false
        var current = ""

        for c in text {
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


    func skipEmptyLines() -> Bool {

        let oldPos = pos
        while pos < lines.count && lines[pos].isEmpty {
            pos += 1
        }

        emptyLinesLastSkipped = pos - oldPos
        return pos < lines.count
    }


    func findColonIndex(in s: String) -> String.Index? {

        var inSingle = false
        var inDouble = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "'" && !inDouble {
                inSingle.toggle()
            } else if c == "\"" && !inSingle {
                inDouble.toggle()
            } else if c == ":" && !inSingle && !inDouble {
                let next = s.index(after: i)
                // YAML specification: mapping colons must be followed by a space, tab or end-of-string.
                if next == s.endIndex || s[next] == " " || s[next] == "\t" {
                    return i
                }
            }

            i = s.index(after: i)
        }

        // No colon found
        return nil
    }
}
