import SwiftUI

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
                            onClose: { tabManager.closeDocument(doc) }
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
