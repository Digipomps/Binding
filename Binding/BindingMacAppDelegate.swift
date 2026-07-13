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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task(priority: .userInitiated) {
            await BindingLaunchWarmup.preloadLocalRuntime()
        }
        scheduleEnsureMainWindowPresent()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag || sender.windows.isEmpty {
            ensureMainWindowPresent()
            return true
        }
        return false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let targetWindowNumber = automationTargetWindowNumber(in: application)
        urls.forEach { url in
            BindingIncomingURLBridge.submit(url: url, targetWindowNumber: targetWindowNumber)
        }
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

    private func scheduleEnsureMainWindowPresent() {
        DispatchQueue.main.async { [weak self] in
            self?.ensureMainWindowPresent()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.ensureMainWindowPresent()
        }
    }

    private func ensureMainWindowPresent() {
        if let existingWindow = NSApp.windows.first {
            NSApp.activate(ignoringOtherApps: true)
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        guard
            let fileMenuItem = NSApp.mainMenu?.items.first(where: { $0.title == "File" }),
            let newWindowItem = fileMenuItem.submenu?.items.first(where: { item in
                item.title == "New Window" || item.title == "Nytt vindu"
            }),
            let action = newWindowItem.action
        else {
            return
        }

        NSApp.sendAction(action, to: newWindowItem.target, from: newWindowItem)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    private func automationTargetWindowNumber(in application: NSApplication) -> Int? {
        application.keyWindow?.windowNumber
            ?? application.mainWindow?.windowNumber
            ?? application.orderedWindows.first(where: \.isVisible)?.windowNumber
    }
}
#endif
