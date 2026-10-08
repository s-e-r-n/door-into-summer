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

struct Figure: View {
    let picture: Picture
    let ratio: Ratio?
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            loaded
            if let caption {
                Text(caption).foregroundStyle(Color.tertiaryText)
            }
        }
    }

    @ViewBuilder private var loaded: some View {
        if let ratio {
            AsyncImage(url: picture.url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                case .failure: Text("image unavailable").foregroundStyle(Color.tertiaryText).padding(12)
                default: Color.clear
                }
            }
            .aspectRatio(ratio.value, contentMode: .fit)
            .frame(maxWidth: ratio.figureWidth)
        } else {
            AsyncImage(url: picture.url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit().frame(maxHeight: Ratio.figureHeight)
                case .failure: Text("image unavailable").foregroundStyle(Color.tertiaryText)
                default: Text("loading image").foregroundStyle(Color.tertiaryText)
                }
            }
        }
    }
}

struct Skeleton: View {
    let ratio: Ratio
    let shape: Shape3D
    let running: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.desk
            AsciiShape(shape: shape, running: running)
            Text(ratio.label)
                .foregroundStyle(Color.tertiaryText)
                .padding(.trailing, 12)
                .padding(.bottom, 10)
        }
        .aspectRatio(ratio.value, contentMode: .fit)
        .frame(maxWidth: ratio.figureWidth)
    }
}
