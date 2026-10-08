import SwiftUI

enum Shape3D: CaseIterable, Sendable {
    case cube
    case helix
    case triangle

    static func random() -> Shape3D {
        allCases.randomElement() ?? .cube
    }
}

private struct Point3 {
    var x: Double
    var y: Double
    var z: Double
}

private let cubePoints: [Point3] = {
    let half = 0.57
    let steps = 8
    var points: [Point3] = []
    for i in 0...steps {
        for j in 0...steps {
            let u = -half + 2 * half * Double(i) / Double(steps)
            let v = -half + 2 * half * Double(j) / Double(steps)
            for side in [half, -half] {
                points += [Point3(x: side, y: u, z: v), Point3(x: u, y: side, z: v), Point3(x: u, y: v, z: side)]
            }
        }
    }
    return points
}()

private let helixPoints: [Point3] = {
    var points: [Point3] = []
    for along in stride(from: -1.0, through: 1.0, by: 0.035) {
        let angle = along * 2 * .pi
        for phase in [0.0, Double.pi] {
            points.append(Point3(x: 0.38 * cos(angle + phase), y: 0.38 * sin(angle + phase), z: 0.95 * along))
        }
    }
    for along in stride(from: -1.0, through: 1.0, by: 0.14) {
        let angle = along * 2 * .pi
        for across in stride(from: -0.38, through: 0.38, by: 0.095) {
            points.append(Point3(x: across * cos(angle), y: across * sin(angle), z: 0.95 * along))
        }
    }
    return points
}()

private let trianglePoints: [Point3] = {
    let corners = [Point3(x: 0, y: 1, z: 0), Point3(x: 0.943, y: -0.333, z: 0), Point3(x: -0.471, y: -0.333, z: 0.816), Point3(x: -0.471, y: -0.333, z: -0.816)]
    let mixed = { (weights: [(Int, Double)]) -> Point3 in
        weights.reduce(Point3(x: 0, y: 0, z: 0)) { sum, pair in
            let corner = corners[pair.0]
            return Point3(x: sum.x + corner.x * pair.1, y: sum.y + corner.y * pair.1, z: sum.z + corner.z * pair.1)
        }
    }
    var points: [Point3] = []
    for (a, b) in [(0, 1), (0, 2), (0, 3), (1, 2), (2, 3), (3, 1)] {
        for t in stride(from: 0.0, through: 1.0, by: 0.05) {
            points.append(mixed([(a, 1 - t), (b, t)]))
        }
    }
    for (a, b, c) in [(0, 1, 2), (0, 2, 3), (0, 3, 1), (1, 3, 2)] {
        for u in stride(from: 0.0, through: 1.0, by: 0.12) {
            for v in stride(from: 0.0, through: 1 - u, by: 0.12) {
                points.append(mixed([(a, u), (b, v), (c, 1 - u - v)]))
            }
        }
    }
    return points
}()

private func points(of shape: Shape3D) -> [Point3] {
    switch shape {
    case .cube: cubePoints
    case .helix: helixPoints
    case .triangle: trianglePoints
    }
}

private func turned(_ point: Point3, _ time: Double) -> Point3 {
    let spin = 0.5 * time
    let x0 = point.x * cos(spin) - point.y * sin(spin)
    let y0 = point.x * sin(spin) + point.y * cos(spin)
    let tilt = 0.3 * time
    let x1 = x0 * cos(tilt) - point.z * sin(tilt)
    let z1 = x0 * sin(tilt) + point.z * cos(tilt)
    let roll = 0.2 * time
    return Point3(x: x1, y: y0 * cos(roll) - z1 * sin(roll), z: y0 * sin(roll) + z1 * cos(roll))
}

private let glyphs = Array("░▒▓█▀▄▌▐│─┤├┴┬╭╮╰╯")
private let clockRate = 0.012 * 60
private let alphaLevels = 8

struct AsciiShape: View {
    let shape: Shape3D
    let running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !running)) { context in
            Canvas { graphics, size in
                draw(in: &graphics, size: size, time: context.date.timeIntervalSinceReferenceDate * clockRate)
            }
        }
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, time: Double) {
        let radius = 0.22 * min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var resolved: [Int: GraphicsContext.ResolvedText] = [:]
        for point in points(of: shape).map({ turned($0, time) }).sorted(by: { $0.z < $1.z }) {
            let depth = max(-1, min(1, point.z))
            let glyph = glyphs[Int(((depth + 1) / 2) * Double(glyphs.count - 1))]
            let level = Int(((depth + 1) / 2) * Double(alphaLevels - 1))
            let key = level * glyphs.count + glyphs.firstIndex(of: glyph)!
            let text = resolved[key] ?? graphics.resolve(Text(String(glyph)).font(.shapeGlyph).foregroundStyle(.white.opacity(0.2 + Double(level) / Double(alphaLevels - 1) * 0.8)))
            resolved[key] = text
            graphics.draw(text, at: CGPoint(x: center.x + point.x * radius, y: center.y + point.y * radius))
        }
    }
}

private let spinnerFrames = ["|", "/", "-", "\\"]
private let spinnerInterval = 0.12

struct Spinner: View {
    let running: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: spinnerInterval, paused: !running)) { context in
            Text(spinnerFrames[Int(context.date.timeIntervalSinceReferenceDate / spinnerInterval) % spinnerFrames.count])
                .foregroundStyle(Color.foreground)
        }
    }
}
