import SwiftUI

@MainActor @Observable
final class TabManager {
    var documents: [MarkdownDocument] = []
    var activeDocument: MarkdownDocument?
    var errorMessage: String?

    // 用于保存确认的文档引用
    var documentToClose: MarkdownDocument?

    func newDocument() {
        let doc = MarkdownDocument()
        documents.append(doc)
        activeDocument = doc
    }

    func addDocument(_ document: MarkdownDocument) {
        if let url = document.fileURL,
           let existing = documents.first(where: { $0.fileURL == url }) {
            activeDocument = existing
            return
        }
        documents.append(document)
        activeDocument = document
    }

    func closeDocument(_ document: MarkdownDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        let wasActive = activeDocument?.id == document.id
        documents.remove(at: index)
        if wasActive {
            if documents.isEmpty {
                activeDocument = nil
            } else {
                let newIndex = min(index, documents.count - 1)
                activeDocument = documents[newIndex]
            }
        }
    }

    func moveDocument(from source: IndexSet, to destination: Int) {
        documents.move(fromOffsets: source, toOffset: destination)
    }

    func showError(_ message: String) {
        errorMessage = message
    }

    func dismissError() {
        errorMessage = nil
    }
}
