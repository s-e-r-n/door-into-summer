import Foundation

struct Ratio: Equatable, Hashable, Sendable {
    let width: Int
    let height: Int

    static let figureHeight: CGFloat = 810

    init?(_ text: String) {
        let sides = text.split(separator: ":").compactMap { Int($0) }
        guard sides.count == 2, sides[0] > 0, sides[1] > 0 else { return nil }
        width = sides[0]
        height = sides[1]
    }

    var label: String { "\(width):\(height)" }

    var value: CGFloat { CGFloat(width) / CGFloat(height) }

    var figureWidth: CGFloat { (Self.figureHeight * value).rounded() }
}
