import SwiftUI

struct ChatView: View {
    @Bindable var chat: Chat

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
        .task { await chat.start() }
    }

    @ViewBuilder private var panel: some View {
        Group {
            if let post = chat.lastInspected {
                MetadataPanel(post: post) { chat.inspect(nil) }
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
                ForEach(chat.messages) { message in
                    row(message)
                }
                status
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
    }

    @ViewBuilder private func row(_ message: Message) -> some View {
        switch message {
        case .reviewer(let message):
            ReviewerMessageView(message: message)
        case .post(let post):
            PostView(post: post, inspected: chat.inspected?.id == post.id,
                     tag: { chat.compose(tagging: $0) },
                     reference: { chat.attach(post) },
                     details: { chat.inspect(chat.inspected?.id == post.id ? nil : post) },
                     validate: { await chat.validate(post) })
        case .working(let working):
            WorkingPostView(working: working, running: chat.connection == .live, tag: { chat.compose(tagging: $0) })
        }
    }

    @ViewBuilder private var status: some View {
        switch chat.connection {
        case .connecting:
            StatusLine(text: "Connecting to the review server at \(chat.serverAddress).", alert: false)
        case .lost:
            StatusLine(text: "The server stopped answering. The chat reconnects on its own.", alert: true)
        case .live where chat.cards.isEmpty:
            StatusLine(text: "No live image session.", alert: false)
        case .live:
            EmptyView()
        }
    }
}
