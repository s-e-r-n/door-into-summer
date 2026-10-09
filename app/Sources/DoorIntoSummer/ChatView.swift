import SwiftUI

struct ChatView: View {
    let chat: Chat

    private var open: Bool { chat.inspected != nil }

    var body: some View {
        HStack(spacing: 0) {
            feed
                .safeAreaInset(edge: .bottom, spacing: 0) { ChatBar(chat: chat) }
            if open {
                Color.separator.frame(width: 1).transition(.identity)
            }
            panel
        }
        .animation(Layout.panelMotion, value: open)
        .overlay(alignment: .top) { TitleBar() }
        .background { WindowChrome().frame(width: 0, height: 0) }
        .font(.mono)
        .foregroundStyle(Color.foreground)
        .background(Color.desk)
        .environment(chat)
        .task { await chat.start() }
    }

    @ViewBuilder private var panel: some View {
        Group {
            if let post = chat.lastInspected {
                MetadataPanel(post: post)
            } else {
                Color.desk
            }
        }
        .frame(width: Layout.panelWidth)
        .frame(width: open ? Layout.panelWidth : 0, alignment: .leading)
        .clipped()
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(chat.thread.ids, id: \.self) { id in
                    row(id)
                }
                status
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }

    @ViewBuilder private func row(_ id: String) -> some View {
        switch chat.thread.models[id] {
        case .reviewer(let message):
            ReviewerMessageView(message: message)
        case .post(let post):
            PostView(post: post)
        case .working(let working):
            WorkingPostView(working: working)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder private var status: some View {
        switch chat.connection {
        case .connecting:
            StatusLine(text: "Connecting to the review server at \(chat.serverAddress).", alert: false)
        case .lost:
            StatusLine(text: "The server stopped answering. The chat reconnects on its own.", alert: true)
        case .live where chat.thread.sessions.isEmpty:
            StatusLine(text: "No live image session.", alert: false)
        case .live:
            EmptyView()
        }
    }
}
