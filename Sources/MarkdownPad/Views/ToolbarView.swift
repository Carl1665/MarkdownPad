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

            Divider().frame(height: 20).padding(.horizontal, 4)

            Menu {
                Button("H1") { onAction(.heading(1)) }
                Button("H2") { onAction(.heading(2)) }
                Button("H3") { onAction(.heading(3)) }
            } label: {
                Label("标题", systemImage: "textformat.size")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32)
            .help("标题")

            Divider().frame(height: 20).padding(.horizontal, 4)

            toolbarButton("ul", icon: "list.bullet", tooltip: "无序列表") { onAction(.unorderedList) }
            toolbarButton("ol", icon: "list.number", tooltip: "有序列表") { onAction(.orderedList) }
            toolbarButton("task", icon: "checklist", tooltip: "任务列表") { onAction(.taskList) }

            Divider().frame(height: 20).padding(.horizontal, 4)

            toolbarButton("quote", icon: "text.quote", tooltip: "引用") { onAction(.blockquote) }
            toolbarButton("code", icon: "chevron.left.forwardslash.chevron.right", tooltip: "代码块") { onAction(.codeBlock) }
            toolbarButton("hr", icon: "minus", tooltip: "分隔线") { onAction(.horizontalRule) }

            Divider().frame(height: 20).padding(.horizontal, 4)

            toolbarButton("link", icon: "link", tooltip: "链接 ⌘K") { onAction(.link) }
            toolbarButton("image", icon: "photo", tooltip: "图片") { onAction(.image) }

            Divider().frame(height: 20).padding(.horizontal, 4)

            toolbarButton("table", icon: "tablecells", tooltip: "插入表格") { onAction(.table) }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    private func toolbarButton(_ id: String, icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help(tooltip)
    }
}
