import AppKit
import SwiftUI

struct Leaf<Content: View>: View {
    let chat: Chat
    let cursor: CursorOwner
    let content: Content

    var body: some View {
        content
            .font(.mono)
            .foregroundStyle(Color.foreground)
            .environment(chat)
            .environment(\.images, chat.images)
            .environment(\.cursorOwner, cursor)
    }
}

@MainActor
func leafView<Content: View>(_ content: Content, chat: Chat, cursor: CursorOwner) -> NSHostingView<Leaf<Content>> {
    let hosting = NSHostingView(rootView: Leaf(chat: chat, cursor: cursor, content: content))
    hosting.sizingOptions = []
    hosting.safeAreaRegions = []
    hosting.wantsLayer = true
    return hosting
}
