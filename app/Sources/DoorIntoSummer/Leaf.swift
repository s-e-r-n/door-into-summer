import AppKit
import SwiftUI

struct Leaf<Content: View>: View {
    let chat: Chat
    let content: Content

    var body: some View {
        content
            .font(.mono)
            .foregroundStyle(Color.foreground)
            .environment(chat)
            .environment(\.images, chat.images)
    }
}

@MainActor
func leafView<Content: View>(_ content: Content, chat: Chat) -> NSHostingView<Leaf<Content>> {
    let hosting = NSHostingView(rootView: Leaf(chat: chat, content: content))
    hosting.sizingOptions = []
    hosting.safeAreaRegions = []
    hosting.wantsLayer = true
    return hosting
}
