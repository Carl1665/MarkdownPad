import Testing
import AppKit
@testable import MarkdownPad

@Suite("SyntaxHighlighter Tests")
@MainActor
struct SyntaxHighlighterTests {
    let highlighter = SyntaxHighlighter(theme: ThemeManager.lightEditor)
    let textStorage = NSTextStorage(string: "")

    @Test func testHeadingHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "# Hello")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 7))
        let color = textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.lightEditor.heading)
    }

    @Test func testBoldHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "**bold**")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 8))
        let color = textStorage.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.lightEditor.bold)
    }

    @Test func testCodeInlineHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "use `code` here")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 15))
        let color = textStorage.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.lightEditor.code)
    }

    @Test func testLinkHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "[text](url)")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 11))
        let color = textStorage.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.lightEditor.link)
    }

    @Test func testParagraphRangeCalculation() {
        let text = "line1\n\nline3\n\nline5"
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        let range = highlighter.expandedParagraphRange(in: textStorage, around: NSRange(location: 7, length: 1))
        let substring = (textStorage.string as NSString).substring(with: range)
        #expect(substring.contains("line3"))
    }
}
