import SwiftUI

private let loaderFrames = ["·  ", "·· ", "···"]
private let loaderInterval = 0.4

struct TextLoader: View {
    let running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: loaderInterval, paused: !running)) { context in
            Text(loaderFrames.joined())
                .fixedSize()
                .offset(x: -CGFloat(Int(context.date.timeIntervalSinceReferenceDate / loaderInterval) % loaderFrames.count) * Mono.characterWidth * 3)
        }
        .foregroundStyle(Color.foreground)
        .frame(width: Mono.characterWidth * 3, height: Mono.lineHeight, alignment: .leading)
        .clipped()
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
