import Foundation

@MainActor @Observable
final class ScrollSyncCoordinator {
    /// First visible source line from the editor side — drives preview scroll
    var editorFirstLine: Int = 1

    /// First visible source line from the preview side — drives editor scroll
    var previewFirstLine: Int = 1

    /// Which side initiated the last scroll (prevents feedback loops)
    enum ScrollSource { case editor, preview, none }
    var lastScrollSource: ScrollSource = .none

    /// Line number for cursor position tracking (status bar only)
    var editorLine: Int = 1

    /// Timestamp-based lock to avoid Timer overhead
    @ObservationIgnored private var lastScrollTime: Date = .distantPast
    private let lockInterval: TimeInterval = 0.3

    /// Check if the lock from the opposite source is still active
    private func isOppositeLockActive(_ source: ScrollSource) -> Bool {
        guard Date().timeIntervalSince(lastScrollTime) < lockInterval else {
            // Lock expired, reset
            lastScrollSource = .none
            return false
        }
        // Lock still active, check if it's from the opposite source
        return (source == .editor && lastScrollSource == .preview) ||
               (source == .preview && lastScrollSource == .editor)
    }

    /// Called when editor scrolls (real-time scroll event)
    func editorDidScroll(toLine line: Int) {
        guard !isOppositeLockActive(.editor) else { return }
        lastScrollSource = .editor
        lastScrollTime = Date()
        editorFirstLine = line
    }

    /// Called when preview reports scroll position
    func previewDidScroll(toLine line: Int) {
        guard !isOppositeLockActive(.preview) else { return }
        lastScrollSource = .preview
        lastScrollTime = Date()
        previewFirstLine = line
    }

    /// Called when editor cursor moves (for status bar, not scroll sync)
    func editorCursorMoved(toLine line: Int) {
        editorLine = line
    }

    /// Check if editor-initiated scroll should sync to preview
    func shouldSyncToPreview() -> Bool {
        return lastScrollSource == .editor
    }

    /// Check if preview-initiated scroll should sync to editor
    func shouldSyncToEditor() -> Bool {
        return lastScrollSource == .preview
    }
}
