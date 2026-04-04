import Foundation
import AppKit

/// Manages recently opened files
@MainActor @Observable
final class RecentFilesManager {
    static let shared = RecentFilesManager()

    private let maxRecentFiles = 10

    private(set) var recentFiles: [URL] = []

    private init() {
        loadRecentFiles()
    }

    private func loadRecentFiles() {
        guard let data = UserDefaults.standard.data(forKey: Constants.UserDefaultsKeys.recentFiles),
              let urls = try? JSONDecoder().decode([URL].self, from: data) else {
            recentFiles = []
            return
        }
        recentFiles = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func saveRecentFiles() {
        guard let data = try? JSONEncoder().encode(recentFiles) else { return }
        UserDefaults.standard.set(data, forKey: Constants.UserDefaultsKeys.recentFiles)
    }

    func addFile(_ url: URL) {
        // Remove if already exists
        recentFiles.removeAll { $0 == url }
        // Add to front
        recentFiles.insert(url, at: 0)
        // Trim to max
        if recentFiles.count > maxRecentFiles {
            recentFiles = Array(recentFiles.prefix(maxRecentFiles))
        }
        saveRecentFiles()
    }

    func clearRecentFiles() {
        recentFiles = []
        saveRecentFiles()
    }
}
