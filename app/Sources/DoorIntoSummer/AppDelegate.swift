import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let chat = Chat()
    private let cursor = CursorOwner()
    private var window: NSWindow?
    private var guide: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        installMainMenu(details: #selector(toggleDetails(_:)), guide: #selector(showGuide(_:)), target: self)
        let window = mainWindow(content: ShellView(chat: chat, cursor: cursor))
        window.makeKeyAndOrderFront(nil)
        self.window = window
        Task { await chat.start() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ application: NSApplication) -> Bool {
        true
    }

    @objc private func toggleDetails(_ sender: Any?) {
        chat.toggleInspector()
    }

    @objc private func showGuide(_ sender: Any?) {
        let guide = self.guide ?? guideWindow()
        self.guide = guide
        guide.makeKeyAndOrderFront(nil)
    }
}
