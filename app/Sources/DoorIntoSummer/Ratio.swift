import Foundation

struct Ratio: Equatable, Hashable, Sendable {
    let width: Int
    let height: Int

    static let figureHeight: CGFloat = 810

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    init?(_ text: String) {
        let sides = text.split(separator: ":").compactMap { Int($0) }
        guard sides.count == 2, sides[0] > 0, sides[1] > 0 else { return nil }
        self.init(width: sides[0], height: sides[1])
    }

    var label: String {
        let divisor = gcd(width, height)
        return "\(width / divisor):\(height / divisor)"
    }

    var value: CGFloat { CGFloat(width) / CGFloat(height) }

    func box(in available: CGFloat) -> CGSize {
        let width = min((Self.figureHeight * value).rounded(), available)
        return CGSize(width: width, height: (width / value).rounded())
    }
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : gcd(b, a % b)
}
