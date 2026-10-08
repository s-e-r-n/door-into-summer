import SwiftUI

private struct Field: Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

private func fields(of post: Post) -> [Field] {
    let job = post.job
    let parameter = { (name: String) in job?.parameters[name] ?? "unavailable" }
    return [
        Field(key: "Model", value: job?.model ?? "unavailable"),
        Field(key: "Variant", value: parameter("variant")),
        Field(key: "Aspect ratio", value: job?.aspect ?? "unavailable"),
        Field(key: "Size", value: parameter("size")),
        Field(key: "Resolution", value: parameter("resolution")),
        Field(key: "Quality", value: job?.quality ?? "unavailable"),
        Field(key: "Background", value: parameter("background")),
        Field(key: "Mode", value: parameter("mode")),
        Field(key: "Batch", value: job?.batch.map(String.init) ?? "unavailable"),
        Field(key: "Input", value: post.original == nil ? "none" : "original photo"),
        Field(key: "Style", value: parameter("style")),
        Field(key: "Options", value: parameter("options")),
        Field(key: "Job", value: job?.id ?? "unavailable"),
        Field(key: "Prompt", value: job?.prompt ?? "unavailable"),
    ]
}

struct MetadataPanel: View {
    let post: Post
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("@\(post.session)").font(.monoItalic)
                    Text("image generation \(post.attempt)").foregroundStyle(Color.tertiaryText)
                    Spacer()
                    Button("×", action: close).buttonStyle(.plain).foregroundStyle(Color.tertiaryText)
                }
                Grid(alignment: .topLeading, horizontalSpacing: 7, verticalSpacing: 6) {
                    ForEach(fields(of: post)) { field in
                        GridRow {
                            Text(field.key).foregroundStyle(Color.tertiaryText).lineLimit(1).frame(width: 100, alignment: .leading)
                            Text(field.value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(EdgeInsets(top: 20, leading: 24, bottom: 32, trailing: 24))
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
