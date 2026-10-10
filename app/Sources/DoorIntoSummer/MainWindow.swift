import AppKit
import SwiftUI

@MainActor
func mainWindow(content: NSView) -> NSWindow {
    let window = NSWindow(contentRect: placement(on: NSScreen.main ?? NSScreen.screens.first),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
    window.title = "Door into Summer"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
        window.standardWindowButton(button)?.isHidden = true
    }
    window.backgroundColor = NSColor(Color.desk)
    window.appearance = NSAppearance(named: .darkAqua)
    window.isMovableByWindowBackground = false
    window.isRestorable = false
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed
    window.contentView = content
    window.initialFirstResponder = content
    return window
}

private func placement(on screen: NSScreen?) -> CGRect {
    guard let visible = screen?.visibleFrame else { return .zero }
    let size = CGSize(width: (visible.width * 2 / 3).rounded(), height: visible.height)
    return CGRect(origin: CGPoint(x: visible.midX - size.width / 2, y: visible.minY), size: size)
}
