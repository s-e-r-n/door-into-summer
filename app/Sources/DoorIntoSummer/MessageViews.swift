import AppKit
import SwiftUI

struct Stamp: View {
    let text: String

    var body: some View {
        Text(text).monospacedDigit().foregroundStyle(Color.tertiaryText)
    }
}

struct SessionName: View {
    let session: String
    let tag: (String) -> Void

    var body: some View {
        Button { tag(session) } label: {
            Text("@\(session)").font(.monoItalic).foregroundStyle(Color.secondaryText)
        }
        .buttonStyle(.pointing)
    }
}

struct SettingsLine: View {
    let job: Job?

    var body: some View {
        Text("└ \(job?.model ?? "model unavailable") · \(job?.aspect ?? "ratio unavailable") · \(job?.quality ?? "quality unavailable") · batch \(job?.batch.map(String.init) ?? "unavailable")")
            .foregroundStyle(Color.tertiaryText)
            .padding(.leading, 7)
            .padding(.top, -8)
    }
}

struct ReferenceLine: View {
    let reference: ShownReference
    let thumbnail: CGFloat
    @Environment(\.images) private var images
    @State private var image: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Color.reviewerRow
                }
            }
            .frame(width: thumbnail, height: thumbnail)
            .clipped()
            .task(id: reference.url) {
                image = await images.image(for: reference.url)
            }
            if let session = reference.session, let attempt = reference.attempt {
                Text("\(Text("@\(session)").font(.monoItalic)) · image generation \(attempt)").lineLimit(1)
            } else {
                Text("job \(reference.job)").lineLimit(1)
            }
        }
        .foregroundStyle(Color.tertiaryText)
    }
}

struct Row<Content: View>: View {
    let highlighted: Bool
    let inset: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, Layout.horizontalPadding)
        .background(highlighted ? Color.reviewerRow : Color.clear)
        .overlay(alignment: .leading) {
            if inset {
                Color.secondaryText.frame(width: 2)
            }
        }
        .overlay(alignment: .top) {
            Color.separator.frame(height: 1)
        }
    }
}

struct ReviewerMessageView: View {
    let message: ReviewerModel

    var body: some View {
        Row(highlighted: true, inset: false) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("reviewer").font(.monoItalic).foregroundStyle(Color.white)
                Spacer()
                Stamp(text: message.stamp)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(message.text)
                Ticks(mark: message.mark)
            }
            if let reference = message.reference {
                ReferenceLine(reference: reference, thumbnail: 32)
            }
        }
    }
}

struct PostView: View {
    let post: PostModel
    @Environment(Chat.self) private var chat
    @State private var validating = false
    @State private var refusal: String?

    var body: some View {
        Row(highlighted: false, inset: post.isInspected) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                SessionName(session: post.session) { chat.compose(tagging: $0) }
                Text("image generation \(post.attempt)").foregroundStyle(Color.tertiaryText)
                Spacer()
                Stamp(text: post.stamp)
            }
            SettingsLine(job: post.job)
            Text(post.subject)
            figures
            HStack(spacing: 20) {
                Button("copy prompt") { copyPrompt() }.disabled(post.job?.prompt == nil)
                Button("use as reference") { chat.attach(post) }.disabled(post.job == nil)
                Button("details") { chat.inspect(post.isInspected ? nil : post) }.foregroundStyle(post.isInspected ? Color.foreground : Color.tertiaryText)
                Button(post.validated ? "validated" : "validate") { Task { await validated() } }
                    .disabled(post.validated || validating)
                    .foregroundStyle(post.validated ? Color.lit : Color.tertiaryText)
                if let refusal {
                    Text(refusal).foregroundStyle(Color.alert)
                }
            }
            .buttonStyle(.pointing)
            .foregroundStyle(Color.tertiaryText)
        }
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: 10) {
            if let original = post.original {
                Figure(picture: original, ratio: original.pixels?.ratio, caption: original.label)
            }
            if let generation = post.generation {
                Figure(picture: generation, ratio: generation.pixels?.ratio ?? post.job?.ratio, caption: post.original == nil ? nil : generation.label)
            } else {
                Text("image unavailable").foregroundStyle(Color.tertiaryText)
            }
        }
    }

    private func validated() async {
        validating = true
        refusal = await chat.validate(post)
        validating = false
    }

    private func copyPrompt() {
        guard let prompt = post.job?.prompt else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }
}

struct WorkingPostView: View {
    let working: WorkingModel
    @Environment(Chat.self) private var chat

    private var running: Bool { chat.connection == .live }

    var body: some View {
        Row(highlighted: false, inset: false) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                SessionName(session: working.session) { chat.compose(tagging: $0) }
                Text("image generation \(working.attempt)").foregroundStyle(Color.tertiaryText)
                Spacer()
            }
            SettingsLine(job: working.job)
            Text(working.subject)
            Skeleton(ratio: working.ratio, running: running)
        }
    }
}

struct StatusLine: View {
    let text: String
    let alert: Bool

    var body: some View {
        Row(highlighted: false, inset: false) {
            Text(text).foregroundStyle(alert ? Color.alert : Color.tertiaryText)
        }
    }
}
