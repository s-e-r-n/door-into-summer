import AppKit

@MainActor
final class RefusalView: NSView {
    private let chat: Chat
    private let lineLayer = stillLayer()
    private var shown: Line?
    private lazy var observer = Observer(read: { [unowned self] in chat.refusal }, apply: { [unowned self] in render($0) },
                                         invalidate: { [unowned self] in needsLayout = true })

    init(chat: Chat) {
        self.chat = chat
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.addSublayer(lineLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {}

    override func layout() {
        super.layout()
        observer.read()
        place()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    private func render(_ refusal: String?) {
        shown = refusal.map { line(of: [Span($0, .alert)]) }
        place()
    }

    private func place() {
        guard let shown else { return lineLayer.isHidden = true }
        let x = ((bounds.width - shown.width) / 2).rounded()
        let bottom = ((Layout.lineHeight - Mono.lineHeight) / 2).rounded()
        guard let raster = TextRasters.shared.raster(of: shown, x: x, bottom: bottom, scale: scale) else { return lineLayer.isHidden = true }
        lineLayer.frame = raster.frame
        lineLayer.contents = raster.image
        lineLayer.contentsScale = scale
        lineLayer.isHidden = false
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
