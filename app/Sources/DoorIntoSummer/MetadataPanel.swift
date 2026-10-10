import SwiftUI

struct DetailsPanel: View {
    let chat: Chat

    var body: some View {
        if let post = chat.lastInspected {
            MetadataPanel(post: post).overlay(alignment: .leading) { Color.separator.frame(width: 1) }
        } else {
            Color.desk
        }
    }
}

struct MetadataPanel: View {
    let post: PostModel
    @Environment(Chat.self) private var chat
    @Environment(\.cursorOwner) private var cursor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("@\(post.session)").font(.monoItalic)
                    Text("image generation \(post.attempt)").foregroundStyle(Color.tertiaryText)
                    Spacer()
                    Button("×") { chat.inspect(nil) }.buttonStyle(.pointing).foregroundStyle(Color.tertiaryText)
                }
                Grid(alignment: .topLeading, horizontalSpacing: 7, verticalSpacing: 6) {
                    ForEach(fields(of: post)) { field in
                        GridRow {
                            Text(field.key).foregroundStyle(Color.tertiaryText).lineLimit(1).frame(width: 100, alignment: .leading)
                            Text(field.value).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: Layout.titleBarHeight, leading: 24, bottom: 32, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, _ in cursor?.refresh() }
        .foregroundStyle(Color.foreground)
        .shadow(color: .white.opacity(0.4), radius: 2)
        .shadow(color: .white.opacity(0.18), radius: 10)
        .background(Color.desk)
        .overlay { Scanlines() }
    }
}

private struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            for y in stride(from: 0, to: size.height, by: 3) {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.42)))
            }
        }
        .allowsHitTesting(false)
    }
}
