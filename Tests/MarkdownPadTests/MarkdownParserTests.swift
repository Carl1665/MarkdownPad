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
        #expect(html.contains("data-source-line=\"1\">item1</li>"))
        #expect(html.contains("data-source-line=\"2\">item2</li>"))
    }

    @Test func testOrderedList() {
        let html = parser.parse("1. first\n2. second")
        #expect(html.contains("<ol data-source-line=\"1\">"))
        #expect(html.contains("data-source-line=\"1\">first</li>"))
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

    // Debug: test nested list indentation
    @Test func testNestedOrderedList2Spaces() {
        let md = "1. first\n  2. second"
        let html = parser.parse(md)
        print("[DEBUG 2-space] html=\(html)")
        // Should be separate list items or nested
    }

    @Test func testNestedOrderedList3Spaces() {
        let md = "1. first\n   2. second"
        let html = parser.parse(md)
        print("[DEBUG 3-space] html=\(html)")
    }

    @Test func testNestedOrderedList4Spaces() {
        // Comprehensive test: what does swift-markdown accept for nested ordered lists?
        let testCases: [(String, String)] = [
            // Same number marker with different indents
            ("3-space + 1.", "1. first\n   1. second"),
            ("3-space + 2.", "1. first\n   2. second"),
            ("4-space + 1.", "1. first\n    1. second"),
            ("4-space + 2.", "1. first\n    2. second"),
            ("2-space + 1.", "1. first\n  1. second"),
            // With blank line
            ("blank + 3-space + 1.", "1. first\n\n   1. second"),
            ("blank + 3-space + 2.", "1. first\n\n   2. second"),
            // Mixed
            ("mixed 3-space -", "1. first\n   - second"),
            // Unordered parent
            ("ul 2-space -", "- first\n  - second"),
            ("ul 4-space -", "- first\n    - second"),
        ]
        for (name, md) in testCases {
            let html = parser.parse(md)
            let olCount = html.components(separatedBy: "<ol").count - 1
            let ulCount = html.components(separatedBy: "<ul").count - 1
            let isNested = olCount + ulCount >= 2
            print("[\(name)] nested=\(isNested) ol=\(olCount) ul=\(ulCount)")
        }
    }

    @Test func testNestedUnorderedList4Spaces() {
        let md = "- first\n    - second"
        let html = parser.parse(md)
        print("[DEBUG unordered 4-space] html=\(html)")
    }
}
