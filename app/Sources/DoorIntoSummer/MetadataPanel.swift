import SwiftUI

private struct Field: Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

private func fields(of post: Post) -> [Field] {
    let job = post.job
    let shown = { (value: String?) in value ?? "unavailable" }
    return [
        Field(key: "Model", value: shown(job?.model)),
        Field(key: "Aspect ratio", value: shown(job?.aspect)),
        Field(key: "Size", value: shown(job?.size)),
        Field(key: "Resolution", value: shown(job?.resolution)),
        Field(key: "Quality", value: shown(job?.quality)),
        Field(key: "Mode", value: shown(job?.mode)),
        Field(key: "Batch", value: shown(job?.batch.map(String.init))),
        Field(key: "Input", value: post.generation == nil ? "unavailable" : post.original == nil ? "none" : "original photo"),
        Field(key: "Job", value: shown(job?.id)),
        Field(key: "Created", value: shown(job?.createdAt)),
        Field(key: "Prompt", value: shown(job?.prompt)),
    ]
}

struct MetadataPanel: View {
    let post: Post
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("@\(post.session)").font(.monoItalic).textSelection(.enabled)
                    Text("image generation \(post.attempt)").foregroundStyle(Color.tertiaryText).textSelection(.enabled)
                    Spacer()
                    Button("×", action: close).buttonStyle(.plain).foregroundStyle(Color.tertiaryText)
                }
                Grid(alignment: .topLeading, horizontalSpacing: 7, verticalSpacing: 6) {
                    ForEach(fields(of: post)) { field in
                        GridRow {
                            Text(field.key).foregroundStyle(Color.tertiaryText).lineLimit(1).textSelection(.enabled).frame(width: 100, alignment: .leading)
                            Text(field.value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: Layout.titleBarHeight, leading: 24, bottom: 32, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
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
