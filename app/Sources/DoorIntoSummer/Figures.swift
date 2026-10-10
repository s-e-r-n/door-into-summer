import AppKit
import SwiftUI

enum TickMark: Equatable, Hashable, Sendable {
    case sent
    case delivered
    case read
}

struct Ticks: View {
    let mark: TickMark

    var body: some View {
        HStack(spacing: -4) {
            Text("✓").foregroundStyle(mark == .sent ? Color.tertiaryText : Color.lit)
            Text("✓").foregroundStyle(mark == .read ? Color.lit : Color.tertiaryText)
        }
        .padding(.leading, 8)
    }
}

private enum Loaded {
    case loading
    case image(NSImage)
    case unavailable
}

struct Figure: View {
    let picture: Picture
    let ratio: Ratio?
    let caption: String?
    @Environment(\.images) private var images
    @State private var loaded = Loaded.loading

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            box
            if let caption {
                Text(caption).foregroundStyle(Color.tertiaryText)
            }
        }
        .task(id: picture.url) {
            loaded = await images.image(for: picture.url).map(Loaded.image) ?? .unavailable
        }
    }

    @ViewBuilder private var box: some View {
        if let ratio {
            Color.clear
                .aspectRatio(ratio.value, contentMode: .fit)
                .frame(maxWidth: ratio.figureWidth)
                .overlay { boxed }
        } else {
            free
        }
    }

    @ViewBuilder private var boxed: some View {
        switch loaded {
        case .image(let image): Image(nsImage: image).resizable().scaledToFit()
        case .unavailable: Text("image unavailable").foregroundStyle(Color.tertiaryText).padding(12)
        case .loading: Color.clear
        }
    }

    @ViewBuilder private var free: some View {
        switch loaded {
        case .image(let image): Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: Ratio.figureHeight)
        case .unavailable: Text("image unavailable").foregroundStyle(Color.tertiaryText)
        case .loading: Text("loading image").foregroundStyle(Color.tertiaryText)
        }
    }
}

struct Skeleton: View {
    let ratio: Ratio
    let running: Bool

    var body: some View {
        Color.desk
            .overlay { HexLoader(running: running) }
            .overlay(alignment: .bottomTrailing) {
                Text(ratio.label)
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
            }
            .aspectRatio(ratio.value, contentMode: .fit)
            .frame(maxWidth: ratio.figureWidth)
    }
}
