import SwiftUI
import AppKit

struct TabBarView: View {
    @Bindable var tabManager: TabManager

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabManager.documents) { doc in
                        TabItemView(
                            title: doc.displayName,
                            isDirty: doc.isDirty,
                            isActive: tabManager.activeDocument?.id == doc.id,
                            onSelect: { tabManager.activeDocument = doc },
                            onClose: { requestClose(doc) }
                        )
                    }
                }
            }

            Spacer()

            Button(action: { tabManager.newDocument() }) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("新建文档 ⌘N")
            .padding(.trailing, 8)
        }
        .frame(height: 36)
        .background(.bar)
    }

    private func requestClose(_ doc: MarkdownDocument) {
        if doc.isDirty {
            showCloseConfirmation(for: doc)
        } else {
            tabManager.closeDocument(doc)
        }
    }

    private func showCloseConfirmation(for doc: MarkdownDocument) {
        let alert = NSAlert()
        alert.messageText = "是否保存更改？"
        alert.informativeText = "文档 \"\(doc.displayName)\" 有未保存的更改。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:  // 保存
            if doc.fileURL != nil {
                do {
                    try doc.save()
                    tabManager.closeDocument(doc)
                } catch {
                    tabManager.showError("保存失败：\(error.localizedDescription)")
                }
            } else {
                // 显示保存面板
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.init(filenameExtension: "md")!]
                panel.nameFieldStringValue = doc.displayName + ".md"
                if panel.runModal() == .OK, let url = panel.url {
                    do {
                        try doc.save(to: url)
                        tabManager.closeDocument(doc)
                    } catch {
                        tabManager.showError("保存失败：\(error.localizedDescription)")
                    }
                }
            }
        case .alertSecondButtonReturn:  // 不保存
            tabManager.closeDocument(doc)
        default:  // 取消
            break
        }
    }
}

private struct TabItemView: View {
    let title: String
    let isDirty: Bool
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if isDirty {
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
            }

            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(isHovering || isActive ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovering = $0 }
        .onTapGesture { onSelect() }
    }
}
