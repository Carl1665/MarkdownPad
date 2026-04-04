import SwiftUI
import AppKit

struct EditorTheme {
    let background: NSColor
    let text: NSColor
    let heading: NSColor
    let bold: NSColor
    let italic: NSColor
    let code: NSColor
    let codeBackground: NSColor
    let link: NSColor
    let listMarker: NSColor
    let blockquoteMarker: NSColor
    let horizontalRule: NSColor

    let font: NSFont
    let codeFont: NSFont
    let lineHeight: CGFloat
}

@MainActor @Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var isDarkMode: Bool = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

    var editorTheme: EditorTheme {
        isDarkMode ? Self.darkEditor : Self.lightEditor
    }

    @ObservationIgnored nonisolated(unsafe) private var appearanceObserver: NSObjectProtocol?

    private init() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            }
        }
    }

    deinit {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }

    // MARK: - Light Theme

    static let lightEditor = EditorTheme(
        background: .white,
        text: NSColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1),
        heading: NSColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1),
        bold: NSColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1),
        italic: NSColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
        code: NSColor(red: 0.78, green: 0.36, blue: 0.15, alpha: 1),
        codeBackground: NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
        link: NSColor(red: 0.20, green: 0.45, blue: 0.75, alpha: 1),
        listMarker: NSColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1),
        blockquoteMarker: NSColor(red: 0.60, green: 0.60, blue: 0.60, alpha: 1),
        horizontalRule: NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1),
        font: NSFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15),
        codeFont: NSFont(name: "Menlo", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular),
        lineHeight: 1.6
    )

    // MARK: - Dark Theme

    static let darkEditor = EditorTheme(
        background: NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1),
        text: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1),
        heading: NSColor(red: 0.45, green: 0.65, blue: 0.90, alpha: 1),
        bold: NSColor(red: 0.90, green: 0.90, blue: 0.90, alpha: 1),
        italic: NSColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1),
        code: NSColor(red: 0.90, green: 0.55, blue: 0.30, alpha: 1),
        codeBackground: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),
        link: NSColor(red: 0.40, green: 0.65, blue: 0.95, alpha: 1),
        listMarker: NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1),
        blockquoteMarker: NSColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1),
        horizontalRule: NSColor(red: 0.35, green: 0.35, blue: 0.35, alpha: 1),
        font: NSFont(name: "PingFangSC-Regular", size: 15) ?? .systemFont(ofSize: 15),
        codeFont: NSFont(name: "Menlo", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular),
        lineHeight: 1.6
    )
}
