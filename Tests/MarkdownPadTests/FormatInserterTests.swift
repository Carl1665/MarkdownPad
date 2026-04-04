import Testing
@testable import MarkdownPad

@Suite("FormatInserter Tests")
struct FormatInserterTests {

    @Test func testWrapBold() {
        let result = FormatInserter.wrapSelection("hello", with: "**")
        #expect(result.text == "**hello**")
        #expect(result.selectionOffset == 2)
        #expect(result.selectionLength == 5)
    }

    @Test func testWrapBoldNoSelection() {
        let result = FormatInserter.wrapSelection("", with: "**")
        #expect(result.text == "****")
        #expect(result.selectionOffset == 2)
        #expect(result.selectionLength == 0)
    }

    @Test func testWrapItalic() {
        let result = FormatInserter.wrapSelection("text", with: "*")
        #expect(result.text == "*text*")
    }

    @Test func testWrapInlineCode() {
        let result = FormatInserter.wrapSelection("code", with: "`")
        #expect(result.text == "`code`")
    }

    @Test func testInsertHeading() {
        let result = FormatInserter.insertPrefix("# ", forLine: "Hello")
        #expect(result == "# Hello")
    }

    @Test func testInsertHeadingAlreadyHasPrefix() {
        let result = FormatInserter.insertPrefix("## ", forLine: "# Hello")
        #expect(result == "## Hello")
    }

    @Test func testInsertUnorderedList() {
        let result = FormatInserter.insertPrefix("- ", forLine: "item")
        #expect(result == "- item")
    }

    @Test func testInsertOrderedList() {
        let result = FormatInserter.insertPrefix("1. ", forLine: "item")
        #expect(result == "1. item")
    }

    @Test func testInsertTaskList() {
        let result = FormatInserter.insertPrefix("- [ ] ", forLine: "task")
        #expect(result == "- [ ] task")
    }

    @Test func testInsertBlockquote() {
        let result = FormatInserter.insertPrefix("> ", forLine: "quote")
        #expect(result == "> quote")
    }

    @Test func testInsertCodeBlock() {
        let result = FormatInserter.insertCodeBlock(language: "")
        #expect(result == "```\n\n```")
    }

    @Test func testInsertLink() {
        let result = FormatInserter.insertLink(text: "title", url: "https://example.com")
        #expect(result == "[title](https://example.com)")
    }

    @Test func testInsertImage() {
        let result = FormatInserter.insertImage(alt: "photo", url: "image.png")
        #expect(result == "![photo](image.png)")
    }

    @Test func testInsertTable() {
        let result = FormatInserter.insertTable(rows: 2, cols: 2)
        let expected = "| Column 1 | Column 2 |\n| --- | --- |\n|  |  |\n|  |  |"
        #expect(result == expected)
    }

    @Test func testInsertHorizontalRule() {
        let result = FormatInserter.insertHorizontalRule()
        #expect(result == "\n---\n")
    }
}
