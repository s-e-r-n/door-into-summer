import AppKit
import SwiftUI

@MainActor
func guideWindow() -> NSWindow {
    let guide = NSHostingController(rootView: Guide())
    guide.sizingOptions = .preferredContentSize
    let window = NSWindow(contentViewController: guide)
    window.title = "Door into Summer Help"
    window.styleMask = [.titled, .closable]
    window.backgroundColor = NSColor(Color.desk)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isRestorable = false
    window.isReleasedWhenClosed = false
    window.center()
    return window
}
