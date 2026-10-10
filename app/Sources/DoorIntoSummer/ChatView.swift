import SwiftUI

struct ChatView: View {
    let chat: Chat
    @State private var cursor = CursorOwner()

    private var open: Bool { chat.inspected != nil }

    var body: some View {
        PanelSlide(open: open, cursor: cursor, resized: { chat.thread.resize(window: $0) }) {
            hostingRoot(Feed(chat: chat, cursor: cursor))
        } panel: {
            hostingRoot(panel)
        }
        .background { WindowChrome().frame(width: 0, height: 0) }
        .task { await chat.start() }
    }

    @ViewBuilder private var panel: some View {
        if let post = chat.lastInspected {
            MetadataPanel(post: post).overlay(alignment: .leading) { Color.separator.frame(width: 1) }
        } else {
            Color.desk
        }
    }

    private func hostingRoot<Content: View>(_ content: Content) -> some View {
        content
            .overlay(alignment: .top) { TitleBar() }
            .font(.mono)
            .foregroundStyle(Color.foreground)
            .background(Color.desk)
            .environment(chat)
            .environment(\.images, chat.images)
            .environment(\.cursorOwner, cursor)
    }
}

private struct Feed: View {
    let chat: Chat
    let cursor: CursorOwner
    @State private var barHeight: CGFloat = 0

    var body: some View {
        FeedTable(chat: chat, cursor: cursor, revision: chat.thread.revision, status: status, summons: chat.summons,
                  running: chat.connection == .live, bottomInset: barHeight)
            .overlay(alignment: .bottom) {
                ChatBar(chat: chat).onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
            }
    }

    private var status: Status? {
        switch chat.connection {
        case .reading:
            Status(text: "Reading the live image sessions.", alert: false)
        case .live where chat.thread.sessions.isEmpty:
            Status(text: "No live image session.", alert: false)
        case .live:
            nil
        }
    }
}
