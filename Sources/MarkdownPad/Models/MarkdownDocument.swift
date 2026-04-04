import SwiftUI
import Combine

@MainActor @Observable
final class MarkdownDocument: Identifiable {
    let id = UUID()
    var text: String
    var fileURL: URL?
    var isDirty: Bool = false
    var encoding: String.Encoding = .utf8

    @ObservationIgnored nonisolated(unsafe) private var autoSaveTimer: Timer?

    var displayName: String {
        if let url = fileURL {
            return url.lastPathComponent
        }
        return "Untitled"
    }

    init(text: String = "", fileURL: URL? = nil) {
        self.text = text
        self.fileURL = fileURL
        startAutoSave()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Auto Save

    private func startAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isDirty, self.fileURL != nil else { return }
                try? self.save()
            }
        }
    }

    // MARK: - File I/O

    static func open(url: URL) throws -> MarkdownDocument {
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
        let doc = MarkdownDocument(text: text, fileURL: url)
        doc.isDirty = false
        return doc
    }

    func save() throws {
        guard let url = fileURL else { return }
        try text.write(to: url, atomically: true, encoding: encoding)
        isDirty = false
    }

    func save(to url: URL) throws {
        fileURL = url
        try save()
    }
}
