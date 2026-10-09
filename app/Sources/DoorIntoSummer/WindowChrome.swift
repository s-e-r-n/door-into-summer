import AppKit
import SwiftUI

struct TitleBar: View {
    var body: some View {
        Color.clear
            .frame(height: Layout.titleBarHeight)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents()
    }
}

struct WindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> ChromeView {
        ChromeView()
    }

    func updateNSView(_ view: ChromeView, context: Context) {}
}

final class ChromeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }
}
