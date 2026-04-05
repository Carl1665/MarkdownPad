import Foundation

struct FormatInsertResult {
    let text: String
    let selectionOffset: Int
    let selectionLength: Int
}

enum FormatInserter {

    // MARK: - Toggle Wrap (bold, italic, inline code)

    /// Wrap or unwrap selection with a marker.
    /// If the selected text (or surrounding text) already has the wrapper, remove it (toggle off).
    /// Otherwise, add it (toggle on).
    static func wrapSelection(
        _ selection: String,
        with wrapper: String,
        fullText: String,
        selectedRange: NSRange
    ) -> FormatInsertResult {
        let nsFull = fullText as NSString

        // Case 1: Selected text itself is already wrapped
        if selection.hasPrefix(wrapper) && selection.hasSuffix(wrapper)
            && selection.count >= wrapper.count * 2 {
            let inner = String(selection.dropFirst(wrapper.count).dropLast(wrapper.count))
            return FormatInsertResult(
                text: inner,
                selectionOffset: 0,
                selectionLength: inner.count
            )
        }

        // Case 2: Check if surrounding text has the wrapper
        let loc = selectedRange.location
        let end = NSMaxRange(selectedRange)
        let wrapperLen = wrapper.count

        if loc >= wrapperLen && end + wrapperLen <= nsFull.length {
            let before = nsFull.substring(with: NSRange(location: loc - wrapperLen, length: wrapperLen))
            let after = nsFull.substring(with: NSRange(location: end, length: wrapperLen))
            if before == wrapper && after == wrapper {
                // Unwrap: remove surrounding wrappers
                let inner = nsFull.substring(with: NSRange(location: loc, length: selectedRange.length))
                return FormatInsertResult(
                    text: inner,
                    selectionOffset: -wrapperLen,
                    selectionLength: inner.count
                )
            }
        }

        // Case 3: Wrap
        let text = "\(wrapper)\(selection)\(wrapper)"
        return FormatInsertResult(
            text: text,
            selectionOffset: wrapper.count,
            selectionLength: selection.count
        )
    }

    // MARK: - Heading

    static func insertPrefix(_ prefix: String, forLine line: String) -> String {
        var cleanLine = line
        if prefix.hasPrefix("#") {
            cleanLine = line.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
        }
        return "\(prefix)\(cleanLine)"
    }

    // MARK: - List / Blockquote (multi-line toggle)

    /// Toggle a line prefix on/off for the selected range.
    /// If all selected lines already have the prefix, remove it. Otherwise, add it.
    static func toggleLinePrefix(
        _ prefix: String,
        in text: String,
        range: NSRange
    ) -> (newText: String, newRange: NSRange) {
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: range)
        let lineText = nsText.substring(with: lineRange)

        // Preserve trailing newline — lineRange includes it, but split/join would lose it
        let hasTrailingNewline = lineText.hasSuffix("\n")
        let workText = hasTrailingNewline ? String(lineText.dropLast()) : lineText
        let lines = workText.components(separatedBy: "\n")

        // Check if ALL non-empty lines already have this prefix
        let allHavePrefix = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .allSatisfy { $0.hasPrefix(prefix) }

        var resultLines: [String] = []
        if allHavePrefix {
            for line in lines {
                if line.hasPrefix(prefix) {
                    resultLines.append(String(line.dropFirst(prefix.count)))
                } else {
                    resultLines.append(line)
                }
            }
        } else {
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    resultLines.append(line)
                } else {
                    resultLines.append(prefix + line)
                }
            }
        }

        var result = resultLines.joined(separator: "\n")
        if hasTrailingNewline { result += "\n" }
        return (newText: result, newRange: lineRange)
    }

    /// Toggle ordered list: adds "1. ", "2. " etc. or removes existing numbering.
    static func toggleOrderedList(
        in text: String,
        range: NSRange
    ) -> (newText: String, newRange: NSRange) {
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: range)
        let lineText = nsText.substring(with: lineRange)

        let hasTrailingNewline = lineText.hasSuffix("\n")
        let workText = hasTrailingNewline ? String(lineText.dropLast()) : lineText
        let lines = workText.components(separatedBy: "\n")

        let numberedPattern = #"^\d+\.\s"#
        let allNumbered = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .allSatisfy { $0.range(of: numberedPattern, options: .regularExpression) != nil }

        var resultLines: [String] = []
        if allNumbered {
            for line in lines {
                if let range = line.range(of: numberedPattern, options: .regularExpression) {
                    resultLines.append(String(line[range.upperBound...]))
                } else {
                    resultLines.append(line)
                }
            }
        } else {
            var num = 1
            for line in lines {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    resultLines.append(line)
                } else {
                    resultLines.append("\(num). \(line)")
                    num += 1
                }
            }
        }

        var result = resultLines.joined(separator: "\n")
        if hasTrailingNewline { result += "\n" }
        return (newText: result, newRange: lineRange)
    }

    // MARK: - Insert helpers

    static func insertCodeBlock(language: String) -> String {
        "```\(language)\n\n```"
    }

    static func insertLink(text: String, url: String) -> String {
        "[\(text)](\(url))"
    }

    static func insertImage(alt: String, url: String) -> String {
        "![\(alt)](\(url))"
    }

    static func insertTable(rows: Int, cols: Int) -> String {
        let header = (1...cols).map { "Column \($0)" }.joined(separator: " | ")
        let separator = (1...cols).map { _ in "---" }.joined(separator: " | ")
        let emptyRow = (1...cols).map { _ in "" }.joined(separator: " | ")
        var lines = ["| \(header) |", "| \(separator) |"]
        for _ in 0..<rows {
            lines.append("| \(emptyRow) |")
        }
        return lines.joined(separator: "\n")
    }

    static func insertHorizontalRule() -> String {
        "\n---\n"
    }
}
