import AppKit
import CoreText
import QuartzCore
import SwiftUI

private let boxColumns: CGFloat = 17
private let boxLines: CGFloat = 6
private let stepsKey = "steps"

@MainActor
final class HexSprite {
    static let shared = HexSprite(frames: hexFrames, interval: hexFrameInterval)

    let side: CGFloat
    private let strip: CGImage?
    private let cells: [CGRect]
    private let steps: CAKeyframeAnimation

    private init(frames: [[String]], interval: CFTimeInterval) {
        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 1
        side = (boxColumns * Mono.characterWidth * scale).rounded(.up) / scale
        strip = Self.drawnStrip(frames, side: side, scale: scale)
        cells = frames.indices.map { CGRect(x: CGFloat($0) / CGFloat(frames.count), y: 0, width: 1 / CGFloat(frames.count), height: 1) }
        steps = Self.keyframes(cells, interval: interval)
    }

    func layer() -> CALayer {
        let layer = CALayer()
        layer.actions = ["position": NSNull(), "bounds": NSNull(), "contentsRect": NSNull()]
        layer.contents = strip
        if let first = cells.first {
            layer.contentsRect = first
        }
        return layer
    }

    func start(on layer: CALayer) {
        guard layer.animation(forKey: stepsKey) == nil else { return }
        layer.add(steps, forKey: stepsKey)
    }

    func stop(on layer: CALayer) {
        guard layer.animation(forKey: stepsKey) != nil else { return }
        layer.contentsRect = layer.presentation()?.contentsRect ?? layer.contentsRect
        layer.removeAnimation(forKey: stepsKey)
    }

    private static func drawnStrip(_ frames: [[String]], side: CGFloat, scale: CGFloat) -> CGImage? {
        let pixels = Int((side * scale).rounded())
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: pixels * frames.count, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.scaleBy(x: scale, y: scale)
        let font = Mono.font
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): NSColor(Color.foreground).cgColor,
        ]
        let lineHeight = side / boxLines
        let baseline = (lineHeight - font.ascender + font.descender) / 2 - font.descender
        for (index, frame) in frames.enumerated() {
            for (row, text) in frame.enumerated() {
                context.textPosition = CGPoint(x: CGFloat(index) * side, y: side - CGFloat(row + 1) * lineHeight + baseline)
                CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), context)
            }
        }
        return context.makeImage()
    }

    private static func keyframes(_ cells: [CGRect], interval: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "contentsRect")
        animation.values = cells.map { NSValue(rect: $0) }
        animation.keyTimes = (0...cells.count).map { NSNumber(value: Double($0) / Double(cells.count)) }
        animation.calculationMode = .discrete
        animation.duration = interval * CFTimeInterval(cells.count)
        animation.repeatCount = .infinity
        animation.beginTime = CACurrentMediaTime()
        return animation
    }
}
