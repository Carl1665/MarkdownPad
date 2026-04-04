import Foundation
import UniformTypeIdentifiers

/// 共享常量
enum Constants {
    /// 窗口最小尺寸
    enum Window {
        static let minWidth: CGFloat = 800
        static let minHeight: CGFloat = 500
    }

    /// 空状态界面
    enum EmptyState {
        static let iconSize: CGFloat = 48
    }

    /// 状态栏
    enum StatusBar {
        static let fontSize: CGFloat = 11
    }

    /// UserDefaults 键
    enum UserDefaultsKeys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let recentFiles = "recentFiles"
        static let splitViewDividerPosition = "splitViewDividerPosition"
    }

    /// 支持的 Markdown 文件类型
    static let markdownContentTypes: [UTType] = {
        [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown")].compactMap { $0 }
    }()
}

/// 错误消息帮助器
enum ErrorMessage {
    static func cannotOpenFile(_ filename: String, error: Error) -> String {
        "无法打开文件 \"\(filename)\": \(error.localizedDescription)"
    }

    static func saveFailed(_ error: Error) -> String {
        "保存失败: \(error.localizedDescription)"
    }
}
