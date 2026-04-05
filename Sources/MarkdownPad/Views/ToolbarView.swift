import SwiftUI

struct ToolbarView: View {
    var onAction: (ToolbarAction) -> Void
    @State private var hoveredID: String? = nil
    @State private var showHeadingMenu = false

    enum ToolbarAction {
        case bold, italic
        case heading(Int)
        case unorderedList, orderedList, taskList
        case blockquote, codeBlock
        case horizontalRule
        case link, image
        case table
        case inlineCode
        case increaseIndent, decreaseIndent
    }

    var body: some View {
        HStack(spacing: 2) {
            // 文本格式
            toolbarButton("B", id: "bold", font: .system(size: 14, weight: .bold), tooltip: "加粗  ⌘B") { onAction(.bold) }
            toolbarButton("I", id: "italic", font: .system(size: 14).italic(), tooltip: "斜体  ⌘I") { onAction(.italic) }
            iconButton("text.and.command.macwindow", id: "inlineCode", tooltip: "行内代码  ⌘E") { onAction(.inlineCode) }

            groupDivider()

            // 标题
            headingButton

            groupDivider()

            // 列表
            iconButton("list.bullet", id: "ul", tooltip: "无序列表  ⌘⇧8") { onAction(.unorderedList) }
            iconButton("list.number", id: "ol", tooltip: "有序列表  ⌘⇧7") { onAction(.orderedList) }
            iconButton("checklist", id: "task", tooltip: "任务列表") { onAction(.taskList) }

            groupDivider()

            // 块元素
            iconButton("text.quote", id: "quote", tooltip: "引用  ⌘⇧.") { onAction(.blockquote) }
            iconButton("chevron.left.forwardslash.chevron.right", id: "code", tooltip: "代码块  ⌥⌘C") { onAction(.codeBlock) }
            iconButton("minus", id: "hr", tooltip: "分隔线") { onAction(.horizontalRule) }

            groupDivider()

            // 插入
            iconButton("link", id: "link", tooltip: "链接  ⌘K") { onAction(.link) }
            iconButton("photo", id: "image", tooltip: "图片") { onAction(.image) }
            iconButton("tablecells", id: "table", tooltip: "插入表格") { onAction(.table) }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(height: 40)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Color(NSColor.separatorColor).frame(height: 0.5)
        }
    }

    // MARK: - Heading Button (custom popover)

    private var headingButton: some View {
        Button(action: { showHeadingMenu.toggle() }) {
            HStack(spacing: 2) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 12))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .rotationEffect(.degrees(showHeadingMenu ? 180 : 0))
                    .animation(.easeInOut(duration: 0.15), value: showHeadingMenu)
            }
            .foregroundStyle(hoveredID == "heading" ? .primary : .secondary)
            .frame(width: 42, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hoveredID == "heading" ? Color.primary.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(NoHighlightButtonStyle())
        .focusable(false)
        .popover(isPresented: $showHeadingMenu, arrowEdge: .bottom) {
            HeadingPopoverContent { level in
                onAction(.heading(level))
                showHeadingMenu = false
            }
            .onAppear {
                TooltipManager.shared.hide()
            }
        }
        .onHover { hovering in
            hoveredID = hovering ? "heading" : nil
            if hovering {
                TooltipManager.shared.show("标题  ⌥⌘1~4")
            } else {
                TooltipManager.shared.hide()
            }
        }
    }

    // MARK: - Button Builders

    private func toolbarButton(_ label: String, id: String, font: Font, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .foregroundStyle(hoveredID == id ? .primary : .secondary)
                .frame(width: 30, height: 28)
                .background(hoverBackground(for: id))
        }
        .buttonStyle(NoHighlightButtonStyle())
        .focusable(false)
        .onHover { hovering in
            hoveredID = hovering ? id : nil
            if hovering {
                TooltipManager.shared.show(tooltip)
            } else {
                TooltipManager.shared.hide()
            }
        }
    }

    private func iconButton(_ systemName: String, id: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundStyle(hoveredID == id ? .primary : .secondary)
                .frame(width: 30, height: 28)
                .background(hoverBackground(for: id))
        }
        .buttonStyle(NoHighlightButtonStyle())
        .focusable(false)
        .onHover { hovering in
            hoveredID = hovering ? id : nil
            if hovering {
                TooltipManager.shared.show(tooltip)
            } else {
                TooltipManager.shared.hide()
            }
        }
    }

    // MARK: - Shared Styles

    private func hoverBackground(for id: String) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(hoveredID == id ? Color.primary.opacity(0.08) : .clear)
    }

    private func groupDivider() -> some View {
        Rectangle()
            .fill(Color(NSColor.separatorColor))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 5)
            .accessibilityHidden(true)
    }
}

// MARK: - Heading Popover Content

struct HeadingPopoverContent: View {
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headingRow("标题 1", font: .system(size: 18, weight: .bold), level: 1)
            Divider()
            headingRow("标题 2", font: .system(size: 15, weight: .semibold), level: 2)
            Divider()
            headingRow("标题 3", font: .system(size: 13, weight: .medium), level: 3)
            Divider()
            headingRow("标题 4", font: .system(size: 12, weight: .regular), level: 4)
        }
        .frame(width: 140)
        .padding(.vertical, 4)
    }

    private func headingRow(_ text: String, font: Font, level: Int) -> some View {
        Button(action: { onSelect(level) }) {
            HStack {
                Text(text)
                    .font(font)
                    .foregroundStyle(.primary)
                Spacer()
                Text("⌥⌘\(level)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoHighlightButtonStyle())
        .focusable(false)
    }
}

// MARK: - Tooltip Manager

@MainActor
final class TooltipManager {
    static let shared = TooltipManager()
    private weak var tooltipView: NSView?

    private init() {}

    func show(_ text: String) {
        hide()

        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else { return }

        let mouseLocation = NSEvent.mouseLocation
        let windowPoint = window.convertPoint(fromScreen: mouseLocation)
        let viewPoint = contentView.convert(windowPoint, from: nil)

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .windowFrameTextColor
        label.backgroundColor = .controlBackgroundColor
        label.drawsBackground = true
        label.isBezeled = false
        label.sizeToFit()

        let padding: CGFloat = 5
        let width = label.frame.width + padding * 2
        let height = label.frame.height + padding * 2
        let x = viewPoint.x - width / 2
        let y = viewPoint.y - height - 8

        let container = NSView(frame: NSRect(x: x, y: y, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 4
        container.layer?.borderColor = NSColor.separatorColor.cgColor
        container.layer?.borderWidth = 0.5

        label.frame.origin = NSPoint(x: padding, y: padding)
        container.addSubview(label)
        contentView.addSubview(container)

        tooltipView = container
    }

    func hide() {
        tooltipView?.removeFromSuperview()
        tooltipView = nil
    }
}

// MARK: - No Highlight Button Style

struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
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

        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
