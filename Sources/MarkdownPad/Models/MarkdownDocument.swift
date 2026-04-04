import SwiftUI
import Combine

@MainActor @Observable
final class MarkdownDocument: Identifiable {
    let id = UUID()
    var text: String
    var fileURL: URL?
    var isDirty: Bool = false
    var encoding: String.Encoding = .utf8
    var autoSaveError: ((Error) -> Void)?

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
                do {
                    try self.save()
                } catch {
                    self.autoSaveError?(error)
                }
            }
        }
    }

    // MARK: - File I/O

    static func open(url: URL) throws -> MarkdownDocument {
        let data = try Data(contentsOf: url)

        // Detect encoding: try UTF-8 first, then fall back to common encodings
        var detectedEncoding: String.Encoding = .utf8

        if String(data: data, encoding: .utf8) != nil {
            detectedEncoding = .utf8
        } else {
            // Try common encodings
            for enc in [String.Encoding.isoLatin1, String.Encoding.windowsCP1252, String.Encoding.macOSRoman] {
                if String(data: data, encoding: enc) != nil {
                    detectedEncoding = enc
                    break
                }
            }
        }

        let text = String(data: data, encoding: detectedEncoding) ?? ""
        let doc = MarkdownDocument(text: text, fileURL: url)
        doc.encoding = detectedEncoding
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
