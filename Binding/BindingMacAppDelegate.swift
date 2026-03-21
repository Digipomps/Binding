import Foundation

#if os(macOS)
import AppKit

final class BindingMacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        clearLegacyWindowFrames(from: defaults)
        clearSavedWindowState()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    private func clearSavedWindowState() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let fileManager = FileManager.default
        let userLibraryURL = fileManager.homeDirectoryForCurrentUser.appending(path: "Library")
        let sandboxLibraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
        let sandboxDataURL = sandboxLibraryURL?.deletingLastPathComponent()

        let candidateDirectories = [
            userLibraryURL.appending(path: "Saved Application State/\(bundleIdentifier).savedState"),
            sandboxLibraryURL?.appending(path: "Saved Application State/\(bundleIdentifier).savedState"),
            sandboxDataURL?.appending(path: "tmp/\(bundleIdentifier).savedState")
        ].compactMap { $0 }

        for directoryURL in candidateDirectories where fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.removeItem(at: directoryURL)
            } catch {
                NSLog("Failed to remove saved window state at %@: %@", directoryURL.path, error.localizedDescription)
            }
        }
    }

    private func clearLegacyWindowFrames(from defaults: UserDefaults) {
        let legacyKeys = defaults.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix("NSWindow Frame Binding.")
                || key.contains("BootstrapView<Binding.RootView>")
        }

        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
#endif
