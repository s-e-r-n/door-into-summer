import AppKit
import SwiftUI

struct HexLoader: NSViewRepresentable {
    let running: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.layer = HexSprite.shared.layer()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let layer = view.layer else { return }
        if running {
            HexSprite.shared.start(on: layer)
        } else {
            HexSprite.shared.stop(on: layer)
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: ()) {
        guard let layer = view.layer else { return }
        HexSprite.shared.stop(on: layer)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
        CGSize(width: HexSprite.shared.side, height: HexSprite.shared.side)
    }
}

private let spinnerFrames = "|/-\\"
private let spinnerInterval = 0.12

struct Spinner: View {
    let running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: spinnerInterval, paused: !running)) { context in
            Text(spinnerFrames)
                .fixedSize()
                .offset(x: -CGFloat(Int(context.date.timeIntervalSinceReferenceDate / spinnerInterval) % spinnerFrames.count) * Mono.characterWidth)
        }
        .foregroundStyle(Color.foreground)
        .frame(width: Mono.characterWidth, height: Mono.lineHeight, alignment: .leading)
        .clipped()
    }
}
