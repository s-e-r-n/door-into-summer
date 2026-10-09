import AppKit
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
private let shapeRate: Float = 30

private struct Sprite {
    let contents: Any
    let size: CGSize
}

@MainActor
private func sprite(_ text: String, font: NSFont, color: NSColor, scale: CGFloat) -> Sprite {
    let drawn = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    let size = drawn.size()
    let image = NSImage(size: size, flipped: false) { _ in
        drawn.draw(at: .zero)
        return true
    }
    return Sprite(contents: image.layerContents(forContentsScale: scale), size: size)
}

@MainActor
private func shapeSprites(scale: CGFloat) -> [Sprite] {
    (0..<alphaLevels * glyphs.count).map { id in
        sprite(String(glyphs[id % glyphs.count]), font: .shapeGlyph,
               color: .white.withAlphaComponent(0.2 + CGFloat(id / glyphs.count) / CGFloat(alphaLevels - 1) * 0.8), scale: scale)
    }
}

struct AsciiShape: NSViewRepresentable {
    let shape: Shape3D
    let running: Bool

    func makeNSView(context: Context) -> AsciiShapeView {
        AsciiShapeView(shape: shape)
    }

    func updateNSView(_ view: AsciiShapeView, context: Context) {
        view.running = running
    }
}

final class AsciiShapeView: NSView {
    private let cloud: [Point3]
    private let stage = CALayer()
    private var sprites: [Sprite] = []
    private var link: CADisplayLink?

    var running = false {
        didSet {
            if running != oldValue { linked() }
        }
    }

    init(shape: Shape3D) {
        cloud = points(of: shape)
        super.init(frame: .zero)
        wantsLayer = true
        stage.isGeometryFlipped = true
        layer?.addSublayer(stage)
        for _ in cloud {
            stage.addSublayer(CALayer())
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        stage.frame = bounds
        placed()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        sprites = shapeSprites(scale: window?.backingScaleFactor ?? 2)
        placed()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        linked()
    }

    private func linked() {
        link?.invalidate()
        link = nil
        guard running, window != nil else { return }
        let link = displayLink(target: self, selector: #selector(stepped))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: shapeRate, maximum: shapeRate, preferred: shapeRate)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func stepped(_ link: CADisplayLink) {
        placed()
    }

    private func placed() {
        guard !sprites.isEmpty else { return }
        let time = Date.timeIntervalSinceReferenceDate * clockRate
        let radius = 0.22 * min(bounds.width, bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (layer, point) in zip(stage.sublayers ?? [], cloud.map { turned($0, time) }) {
            let nearness = (max(-1, min(1, point.z)) + 1) / 2
            let sprite = sprites[Int(nearness * Double(alphaLevels - 1)) * glyphs.count + Int(nearness * Double(glyphs.count - 1))]
            layer.contents = sprite.contents
            layer.bounds = CGRect(origin: .zero, size: sprite.size)
            layer.position = CGPoint(x: bounds.midX + point.x * radius, y: bounds.midY + point.y * radius)
            layer.zPosition = point.z
        }
        CATransaction.commit()
    }
}

private let spinnerFrames = ["|", "/", "-", "\\"]
private let spinnerInterval = 0.12

struct Spinner: View {
    let running: Bool

    var body: some View {
        Text(spinnerFrames[0])
            .hidden()
            .overlay { SpinnerGlyph(running: running) }
            .textSelection(.disabled)
    }
}

private struct SpinnerGlyph: NSViewRepresentable {
    let running: Bool

    func makeNSView(context: Context) -> SpinnerView {
        SpinnerView()
    }

    func updateNSView(_ view: SpinnerView, context: Context) {
        view.running = running
    }
}

final class SpinnerView: NSView {
    private var frames: [Any] = []

    var running = false {
        didSet {
            if running != oldValue { animated() }
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .center
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        frames = spinnerFrames.map { sprite($0, font: .mono, color: NSColor(Color.foreground), scale: scale).contents }
        layer?.contentsScale = scale
        animated()
    }

    private func animated() {
        guard let layer, let first = frames.first else { return }
        layer.removeAnimation(forKey: "frames")
        layer.contents = first
        guard running else { return }
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = frames
        animation.keyTimes = (0...frames.count).map { NSNumber(value: Double($0) / Double(frames.count)) }
        animation.calculationMode = .discrete
        animation.duration = spinnerInterval * Double(frames.count)
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "frames")
    }
}
