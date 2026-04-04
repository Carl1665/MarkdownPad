import Testing
@testable import MarkdownPad

@Suite("MarkdownParser Tests")
struct MarkdownParserTests {
    let parser = MarkdownParser()

    @Test func testHeading() {
        let html = parser.parse("# Hello")
        #expect(html.contains("<h1 data-source-line=\"1\">Hello</h1>"))
    }

    @Test func testBoldAndItalic() {
        let html = parser.parse("**bold** and *italic*")
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
    }

    @Test func testUnorderedList() {
        let html = parser.parse("- item1\n- item2")
        #expect(html.contains("<ul data-source-line=\"1\">"))
        #expect(html.contains("<li>item1</li>"))
        #expect(html.contains("<li>item2</li>"))
    }

    @Test func testOrderedList() {
        let html = parser.parse("1. first\n2. second")
        #expect(html.contains("<ol data-source-line=\"1\">"))
        #expect(html.contains("<li>first</li>"))
    }

    @Test func testTaskList() {
        let html = parser.parse("- [ ] todo\n- [x] done")
        #expect(html.contains("type=\"checkbox\""))
        #expect(html.contains("checked"))
    }

    @Test func testCodeBlock() {
        let html = parser.parse("```\nlet x = 1\n```")
        #expect(html.contains("<pre data-source-line=\"1\"><code>"))
        #expect(html.contains("let x = 1"))
    }

    @Test func testBlockquote() {
        let html = parser.parse("> quote text")
        #expect(html.contains("<blockquote data-source-line=\"1\">"))
    }

    @Test func testLink() {
        let html = parser.parse("[text](https://example.com)")
        #expect(html.contains("<a href=\"https://example.com\">text</a>"))
    }

    @Test func testImage() {
        let html = parser.parse("![alt](image.png)")
        #expect(html.contains("<img src=\"image.png\" alt=\"alt\""))
    }

    @Test func testTable() {
        let md = "| A | B |\n|---|---|\n| 1 | 2 |"
        let html = parser.parse(md)
        #expect(html.contains("<table data-source-line=\"1\">"))
        #expect(html.contains("<th>A</th>"))
        #expect(html.contains("<td>1</td>"))
    }

    @Test func testHorizontalRule() {
        let html = parser.parse("---")
        #expect(html.contains("<hr data-source-line=\"1\""))
    }

    @Test func testParagraph() {
        let html = parser.parse("Hello world")
        #expect(html.contains("<p data-source-line=\"1\">Hello world</p>"))
    }

    @Test func testMultipleBlocks() {
        let md = "# Title\n\nParagraph\n\n- item"
        let html = parser.parse(md)
        #expect(html.contains("data-source-line=\"1\""))  // heading
        #expect(html.contains("data-source-line=\"3\""))  // paragraph
        #expect(html.contains("data-source-line=\"5\""))  // list
    }
}
