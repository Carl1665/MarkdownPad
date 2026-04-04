import Testing
import Foundation
@testable import MarkdownPad

@Suite("TabManager Tests")
@MainActor
struct TabManagerTests {
    let manager = TabManager()

    @Test func testNewDocumentAddsTab() {
        manager.newDocument()
        #expect(manager.documents.count == 1)
        #expect(manager.activeDocument != nil)
    }

    @Test func testOpenDocumentAddsTab() {
        let doc = MarkdownDocument(text: "hello")
        manager.addDocument(doc)
        #expect(manager.documents.count == 1)
        #expect(manager.activeDocument?.id == doc.id)
    }

    @Test func testCloseDocument() {
        manager.newDocument()
        manager.newDocument()
        #expect(manager.documents.count == 2)
        let first = manager.documents[0]
        manager.closeDocument(first)
        #expect(manager.documents.count == 1)
    }

    @Test func testCloseActiveDocumentSelectsNeighbor() {
        manager.newDocument()
        manager.newDocument()
        manager.newDocument()
        let middle = manager.documents[1]
        manager.activeDocument = middle
        manager.closeDocument(middle)
        #expect(manager.activeDocument != nil)
        #expect(manager.activeDocument?.id != middle.id)
    }

    @Test func testNoDuplicateFileURL() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let doc1 = MarkdownDocument(text: "a", fileURL: url)
        let doc2 = MarkdownDocument(text: "b", fileURL: url)
        manager.addDocument(doc1)
        manager.addDocument(doc2)
        #expect(manager.documents.count == 1)
        #expect(manager.activeDocument?.id == doc1.id)
    }
}
