import Testing
import AppKit
@testable import MarkdownPad

@Suite("SyntaxHighlighter Tests")
@MainActor
struct SyntaxHighlighterTests {
    let highlighter = SyntaxHighlighter(theme: ThemeManager.evernoteDarkEditor)
    let textStorage = NSTextStorage(string: "")

    @Test func testHeadingHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "# Hello")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 7))
        let color = textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.evernoteDarkEditor.heading)
    }

    @Test func testBoldHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "**bold**")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 8))
        let color = textStorage.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.evernoteDarkEditor.bold)
    }

    @Test func testCodeInlineHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "use `code` here")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 15))
        let color = textStorage.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.evernoteDarkEditor.code)
    }

    @Test func testLinkHighlight() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "[text](url)")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 11))
        let color = textStorage.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.evernoteDarkEditor.link)
    }

    @Test func testPlainTextDefaultColor() {
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "plain text")
        highlighter.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: 10))
        let color = textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        #expect(color == ThemeManager.evernoteDarkEditor.text)
    }
}
