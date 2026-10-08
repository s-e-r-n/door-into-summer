import SwiftUI
import WebKit

struct ReviewPageView: View {
    @State private var reviewPage = ReviewPage()

    var body: some View {
        ZStack {
            WebView(reviewPage.page)
                .webViewContentBackground(.hidden)
                .opacity(reviewPage.availability == .shown ? 1 : 0)
            if reviewPage.availability == .unanswered {
                Text("The review server at 127.0.0.1:8765 does not answer, retrying.")
                    .foregroundStyle(.secondary)
            }
        }
        .task { await reviewPage.open() }
    }
}
