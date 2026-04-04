import SwiftUI

struct ToolbarView: View {
    var onAction: (ToolbarAction) -> Void

    enum ToolbarAction {
        case bold, italic
        case heading(Int)
        case unorderedList, orderedList, taskList
        case blockquote, codeBlock
        case horizontalRule
        case link, image
        case table
    }

    var body: some View {
        HStack(spacing: 2) {
            toolbarButton("bold", icon: "bold", tooltip: "加粗 ⌘B") { onAction(.bold) }
            toolbarButton("italic", icon: "italic", tooltip: "斜体 ⌘I") { onAction(.italic) }

            Divider().frame(height: 20).padding(.horizontal, 6)

            Menu {
                Button("H1") { onAction(.heading(1)) }
                Button("H2") { onAction(.heading(2)) }
                Button("H3") { onAction(.heading(3)) }
                Button("H4") { onAction(.heading(4)) }
            } label: {
                Image(systemName: "textformat.size")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 36)
            .help("标题")

            Divider().frame(height: 20).padding(.horizontal, 6)

            toolbarButton("ul", icon: "list.bullet", tooltip: "无序列表") { onAction(.unorderedList) }
            toolbarButton("ol", icon: "list.number", tooltip: "有序列表") { onAction(.orderedList) }
            toolbarButton("task", icon: "checklist", tooltip: "任务列表") { onAction(.taskList) }

            Divider().frame(height: 20).padding(.horizontal, 6)

            toolbarButton("quote", icon: "text.quote", tooltip: "引用") { onAction(.blockquote) }
            toolbarButton("code", icon: "chevron.left.forwardslash.chevron.right", tooltip: "代码块") { onAction(.codeBlock) }
            toolbarButton("hr", icon: "minus", tooltip: "分隔线") { onAction(.horizontalRule) }

            Divider().frame(height: 20).padding(.horizontal, 6)

            toolbarButton("link", icon: "link", tooltip: "链接 ⌘K") { onAction(.link) }
            toolbarButton("image", icon: "photo", tooltip: "图片") { onAction(.image) }

            Divider().frame(height: 20).padding(.horizontal, 6)

            toolbarButton("table", icon: "tablecells", tooltip: "插入表格") { onAction(.table) }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(height: 44)
        .background(Color(hex: "#F5F5F5"))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#E0E0E0")),
            alignment: .bottom
        )
    }

    private func toolbarButton(_ id: String, icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#666666"))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help(tooltip)
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
