import AppKit
import CoreText

struct TextRaster {
    let image: CGImage
    let frame: CGRect
}

private let rasterBudget = 64 << 20
private let phaseSteps: CGFloat = 16

@MainActor
final class TextRasters {
    static let shared = TextRasters()

    private let rasters = rasterCache(costing: rasterBudget)

    func raster(of line: Line, x: CGFloat, bottom: CGFloat, scale: CGFloat) -> TextRaster? {
        guard line.width > 0 else { return nil }
        let origin = CGPoint(x: (x * scale).rounded(.down) / scale, y: (bottom * scale).rounded(.down) / scale)
        let key = RasterKey(line: line, phaseX: steps(x - origin.x, scale: scale), phaseY: steps(bottom - origin.y, scale: scale), scale: scale)
        guard let image = rasters.object(forKey: key) ?? drawn(key) else { return nil }
        return TextRaster(image: image, frame: CGRect(origin: origin, size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)))
    }

    private func drawn(_ key: RasterKey) -> CGImage? {
        guard let image = rasterized(key) else { return nil }
        rasters.setObject(image, forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}

private func steps(_ phase: CGFloat, scale: CGFloat) -> Int {
    Int((phase * scale * phaseSteps).rounded())
}

private func rasterCache(costing budget: Int) -> NSCache<RasterKey, CGImage> {
    let cache = NSCache<RasterKey, CGImage>()
    cache.totalCostLimit = budget
    return cache
}

private final class RasterKey: NSObject {
    let line: Line
    let phaseX: Int
    let phaseY: Int
    let scale: CGFloat

    init(line: Line, phaseX: Int, phaseY: Int, scale: CGFloat) {
        self.line = line
        self.phaseX = phaseX
        self.phaseY = phaseY
        self.scale = scale
    }

    var phase: CGPoint {
        CGPoint(x: CGFloat(phaseX) / (scale * phaseSteps), y: CGFloat(phaseY) / (scale * phaseSteps))
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(line)
        hasher.combine(phaseX)
        hasher.combine(phaseY)
        hasher.combine(scale)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? RasterKey else { return false }
        return line == other.line && phaseX == other.phaseX && phaseY == other.phaseY && scale == other.scale
    }
}

@MainActor
private func rasterized(_ key: RasterKey) -> CGImage? {
    let phase = key.phase
    let scale = key.scale
    let width = Int(((phase.x + key.line.width) * scale).rounded(.up))
    let height = Int(((phase.y + Mono.lineHeight) * scale).rounded(.up))
    guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
    context.scaleBy(x: scale, y: scale)
    context.textPosition = CGPoint(x: phase.x, y: phase.y + Mono.lineHeight - Mono.ascender)
    CTLineDraw(CTLineCreateWithAttributedString(attributed(key.line)), context)
    return context.makeImage()
}

@MainActor
private func attributed(_ line: Line) -> NSAttributedString {
    let text = NSMutableAttributedString()
    for span in line.spans {
        text.append(NSAttributedString(string: span.text, attributes: [
            .font: span.style.font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): span.style.color.cgColor,
        ]))
    }
    return text
}
