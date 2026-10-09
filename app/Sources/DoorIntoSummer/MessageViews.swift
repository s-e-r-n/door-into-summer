import AppKit
import SwiftUI

private let clock = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)

struct Stamp: View {
    let at: Date

    var body: some View {
        Text(at, format: clock).monospacedDigit().foregroundStyle(Color.tertiaryText)
    }
}

struct SessionName: View {
    let session: String
    let tag: (String) -> Void

    var body: some View {
        Button { tag(session) } label: {
            Text("@\(session)").font(.monoItalic).foregroundStyle(Color.secondaryText)
        }
        .buttonStyle(.plain)
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

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: reference.url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.reviewerRow
                }
            }
            .frame(width: thumbnail, height: thumbnail)
            .clipped()
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
    let message: ReviewerMessage

    var body: some View {
        Row(highlighted: true, inset: false) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("reviewer").font(.monoItalic).foregroundStyle(Color.white)
                Spacer()
                Stamp(at: message.at)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                styled(message.text)
                Ticks(mark: message.mark)
            }
            if let reference = message.reference {
                ReferenceLine(reference: reference, thumbnail: 32)
            }
        }
    }

    private func styled(_ text: String) -> Text {
        runs(in: text).reduce(Text("")) { joined, run in
            switch run.kind {
            case .plain: Text("\(joined)\(run.text)")
            case .mention: Text("\(joined)\(Text(run.text).font(.monoItalic).foregroundStyle(Color.mention))")
            case .command: Text("\(joined)\(Text(run.text).foregroundStyle(Color.command))")
            }
        }
    }
}

struct PostView: View {
    let post: Post
    let inspected: Bool
    let tag: (String) -> Void
    let reference: () -> Void
    let details: () -> Void
    let validate: () async -> String?
    @State private var validating = false
    @State private var refusal: String?

    var body: some View {
        Row(highlighted: false, inset: inspected) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                SessionName(session: post.session, tag: tag)
                Text("image generation \(post.attempt)").foregroundStyle(Color.tertiaryText)
                Spacer()
                Stamp(at: post.at)
            }
            SettingsLine(job: post.job)
            Text(post.subject)
            figures
            HStack(spacing: 20) {
                Button("copy prompt") { copyPrompt() }.disabled(post.job?.prompt == nil)
                Button("use as reference", action: reference).disabled(post.job == nil)
                Button("details", action: details).foregroundStyle(inspected ? Color.foreground : Color.tertiaryText)
                Button(post.validated ? "validated" : "validate") { Task { await validated() } }
                    .disabled(post.validated || validating)
                    .foregroundStyle(post.validated ? Color.lit : Color.tertiaryText)
                if let refusal {
                    Text(refusal).foregroundStyle(Color.alert)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.tertiaryText)
        }
    }

    private var figures: some View {
        HStack(alignment: .top, spacing: 10) {
            if let original = post.original {
                Figure(picture: original, ratio: nil, caption: original.label)
            }
            Figure(picture: post.generation, ratio: post.job?.ratio, caption: post.original == nil ? nil : post.generation.label)
        }
    }

    private func validated() async {
        validating = true
        refusal = await validate()
        validating = false
    }

    private func copyPrompt() {
        guard let prompt = post.job?.prompt else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }
}

struct WorkingPostView: View {
    let working: WorkingPost
    let running: Bool
    let tag: (String) -> Void
    @State private var shape = Shape3D.random()

    var body: some View {
        Row(highlighted: false, inset: false) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                SessionName(session: working.session, tag: tag)
                Spinner(running: running)
                Text("image generation \(working.attempt)").foregroundStyle(Color.tertiaryText)
                Spacer()
            }
            SettingsLine(job: working.job)
            Text(working.subject)
            Skeleton(ratio: working.ratio, shape: shape, running: running)
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
