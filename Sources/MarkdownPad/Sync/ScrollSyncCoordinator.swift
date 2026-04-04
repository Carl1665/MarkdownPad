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

    @ObservationIgnored nonisolated(unsafe) private var lockTimer: Timer?

    /// Called when editor scrolls (real-time scroll event)
    func editorDidScroll(toLine line: Int) {
        guard lastScrollSource != .preview else { return }
        lastScrollSource = .editor
        editorFirstLine = line
        resetLock()
    }

    /// Called when preview reports scroll position
    func previewDidScroll(toLine line: Int) {
        guard lastScrollSource != .editor else { return }
        lastScrollSource = .preview
        previewFirstLine = line
        resetLock()
    }

    /// Called when editor cursor moves (for status bar, not scroll sync)
    func editorCursorMoved(toLine line: Int) {
        editorLine = line
    }

    private func resetLock() {
        lockTimer?.invalidate()
        lockTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.lastScrollSource = .none
            }
        }
    }
}
