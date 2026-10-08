import AppKit
import SwiftUI

private let clock = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)

struct Stamp: View {
    let at: Date?

    var body: some View {
        Group {
            if let at {
                Text(at, format: clock).monospacedDigit()
            } else {
                Text("time unavailable")
            }
        }
        .foregroundStyle(Color.tertiaryText)
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
        .background(highlighted ? Color.grayRow : Color.clear)
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

struct GrayMessageView: View {
    let message: GrayMessage

    var body: some View {
        Row(highlighted: true, inset: false) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("Gray").font(.monoItalic).foregroundStyle(Color.white)
                Spacer()
                Stamp(at: message.at)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                styled(message.text)
                Ticks(mark: message.mark)
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
    let details: () -> Void
    let validate: () -> Void
    @State private var validating = false

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
                Button("details", action: details).foregroundStyle(inspected ? Color.foreground : Color.tertiaryText)
                Button(post.validated || validating ? "validated" : "validate") {
                    validating = true
                    validate()
                }
                .disabled(post.validated || validating)
                .foregroundStyle(post.validated || validating ? Color.lit : Color.tertiaryText)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.tertiaryText)
        }
        .onChange(of: post.validated) { validating = false }
    }

    @ViewBuilder private var figures: some View {
        if post.generation == nil && post.original == nil {
            Text("image unavailable").foregroundStyle(Color.tertiaryText)
        } else {
            HStack(alignment: .top, spacing: 10) {
                if let original = post.original {
                    Figure(picture: original, ratio: nil, caption: original.label)
                }
                if let generation = post.generation {
                    Figure(picture: generation, ratio: post.job?.ratio, caption: post.original == nil ? nil : generation.label)
                }
            }
        }
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
                Stamp(at: nil)
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
