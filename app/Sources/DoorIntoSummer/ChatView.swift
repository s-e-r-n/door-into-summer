import SwiftUI

struct ChatView: View {
    let chat: Chat
    @State private var position = ScrollPosition()
    @State private var window = PageWindow()

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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(chat.thread.shownIDs, id: \.self) { id in
                    row(id)
                }
                status
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom)
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { before, now in
            paged(from: before, to: now)
        }
    }

    private func paged(from before: ScrollGeometry, to now: ScrollGeometry) {
        let thread = chat.thread
        switch window.scrolled(from: before, to: now, hasEarlierPage: thread.hasEarlierPage, showsEarlierPages: thread.earlierPages > 0) {
        case .showEarlierPage:
            thread.showEarlierPage()
        case .showLastPage:
            thread.showLastPage()
        case .scrollTo(let offset):
            position.scrollTo(y: offset)
        case nil:
            break
        }
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
