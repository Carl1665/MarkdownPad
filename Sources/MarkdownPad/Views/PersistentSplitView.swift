import SwiftUI
import AppKit

/// A split view that remembers its divider position
struct PersistentSplitView: NSViewRepresentable {
    var leftContent: AnyView
    var rightContent: AnyView
    var leftMinWidth: CGFloat
    var rightMinWidth: CGFloat

    // 使用 UserDefaults 直接存储，避免 @AppStorage 在 NSViewRepresentable 中的问题
    private let positionKey = Constants.UserDefaultsKeys.splitViewDividerPosition
    private var storedPosition: CGFloat {
        get { CGFloat(UserDefaults.standard.double(forKey: positionKey)) }
        set {
            UserDefaults.standard.set(Double(newValue), forKey: positionKey)
            UserDefaults.standard.synchronize()
        }
    }

    init(
        @ViewBuilder leftContent: () -> some View,
        @ViewBuilder rightContent: () -> some View,
        leftMinWidth: CGFloat = 300,
        rightMinWidth: CGFloat = 300
    ) {
        self.leftContent = AnyView(leftContent())
        self.rightContent = AnyView(rightContent())
        self.leftMinWidth = leftMinWidth
        self.rightMinWidth = rightMinWidth
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        // Create left hosting view
        let leftHost = NSHostingView(rootView: leftContent)
        splitView.addArrangedSubview(leftHost)

        // Create right hosting view
        let rightHost = NSHostingView(rootView: rightContent)
        splitView.addArrangedSubview(rightHost)

        // Set constraints
        leftHost.widthAnchor.constraint(greaterThanOrEqualToConstant: leftMinWidth).isActive = true
        rightHost.widthAnchor.constraint(greaterThanOrEqualToConstant: rightMinWidth).isActive = true

        // Restore saved position after layout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.restorePosition(in: splitView)
        }

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        // Update the hosted views
        if let leftHost = splitView.subviews.first as? NSHostingView<AnyView> {
            leftHost.rootView = leftContent
        }
        if let rightHost = splitView.subviews.last as? NSHostingView<AnyView> {
            rightHost.rootView = rightContent
        }
    }

    private func restorePosition(in splitView: NSSplitView) {
        splitView.layoutSubtreeIfNeeded()
        let totalWidth = splitView.bounds.width
        guard totalWidth > 0 else { return }

        let defaultPosition = totalWidth / 2
        let savedPosition = storedPosition > 0 ? storedPosition : defaultPosition
        let position = min(max(savedPosition, leftMinWidth), totalWidth - rightMinWidth)
        splitView.setPosition(position, ofDividerAt: 0)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: PersistentSplitView
        private var isDragging = false

        init(parent: PersistentSplitView) {
            self.parent = parent
        }

        func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
            return true
        }

        func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            // 保存位置
            isDragging = true
            return proposedPosition
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView,
                  splitView.subviews.count >= 2 else { return }

            // 只在用户拖动时保存
            if isDragging {
                let position = splitView.subviews[0].frame.width
                parent.storedPosition = position
                isDragging = false
            }
        }
    }
}
