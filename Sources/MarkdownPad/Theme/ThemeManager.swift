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
    let linkUrl: NSColor
    let listMarker: NSColor
    let blockquoteMarker: NSColor
    let horizontalRule: NSColor
    let tablePipe: NSColor
    let comment: NSColor

    let font: NSFont
    let codeFont: NSFont
    let lineHeight: CGFloat
}

@MainActor @Observable
final class ThemeManager {
    static let shared = ThemeManager()

    // 编辑器始终使用深色主题（印象笔记风格）
    var editorTheme: EditorTheme { Self.evernoteDarkEditor }

    private init() {}
}

// MARK: - 印象笔记风格深色主题

extension ThemeManager {
    /// 印象笔记 Markdown 编辑器深色主题
    /// 基于 https://evernote.com 截图逆向提取
    static let evernoteDarkEditor = EditorTheme(
        background: NSColor(hex: "#2B2D30")!,      // 深炭灰
        text: NSColor(hex: "#D4D4D4")!,            // 浅灰白
        heading: NSColor(hex: "#8EC86A")!,         // 亮草绿
        bold: NSColor(hex: "#D7BA7D")!,            // 金黄色
        italic: NSColor(hex: "#D4D4D4")!,          // 默认色
        code: NSColor(hex: "#CE9178")!,            // 暖橙色
        codeBackground: NSColor(hex: "#1E1E1E")!,  // 更深灰
        link: NSColor(hex: "#569CD6")!,            // 蓝色
        linkUrl: NSColor(hex: "#CE9178")!,         // 暖橙色
        listMarker: NSColor(hex: "#D4D4D4")!,      // 默认色
        blockquoteMarker: NSColor(hex: "#6A9955")!, // 暗绿色
        horizontalRule: NSColor(hex: "#E8853D")!,  // 橙红色
        tablePipe: NSColor(hex: "#808080")!,       // 灰色
        comment: NSColor(hex: "#6A9955")!,         // 暗绿色
        font: NSFont(name: "Menlo", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular),
        codeFont: NSFont(name: "Menlo", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular),
        lineHeight: 1.6
    )
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            return nil
        }

        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
