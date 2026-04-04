import Foundation

struct FormatInsertResult {
    let text: String
    let selectionOffset: Int
    let selectionLength: Int
}

enum FormatInserter {

    static func wrapSelection(_ selection: String, with wrapper: String) -> FormatInsertResult {
        let text = "\(wrapper)\(selection)\(wrapper)"
        return FormatInsertResult(
            text: text,
            selectionOffset: wrapper.count,
            selectionLength: selection.count
        )
    }

    static func insertPrefix(_ prefix: String, forLine line: String) -> String {
        var cleanLine = line
        if prefix.hasPrefix("#") {
            cleanLine = line.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "", options: .regularExpression)
        }
        return "\(prefix)\(cleanLine)"
    }

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
