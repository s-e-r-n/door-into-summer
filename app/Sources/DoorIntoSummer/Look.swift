import SwiftUI

extension Color {
    static let desk = Color.black
    static let foreground = Color(.sRGB, red: 0.902, green: 0.902, blue: 0.902)
    static let separator = Color.white.opacity(0.09)
    static let reviewerRow = Color.white.opacity(0.055)
    static let secondaryText = Color(.sRGB, red: 0.922, green: 0.922, blue: 0.961).opacity(0.6)
    static let tertiaryText = Color(.sRGB, red: 0.922, green: 0.922, blue: 0.961).opacity(0.3)
    static let mention = Color(.sRGB, red: 0.769, green: 0.655, blue: 0.906)
    static let command = Color(.sRGB, red: 0.612, green: 0.812, blue: 0.847)
    static let lit = command
    static let alert = Color(.sRGB, red: 0.922, green: 0.435, blue: 0.573)
}

extension Font {
    static let mono = Font.custom("JetBrainsMono-Thin", size: 11)
    static let monoItalic = Font.custom("JetBrainsMono-ThinItalic", size: 11)
    static let shapeGlyph = Font.custom("JetBrainsMono-Thin", size: 7)
}

enum Layout {
    static let horizontalPadding: CGFloat = 32
    static let panelWidth: CGFloat = 400
    static let panelMotion = Animation.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.22)
    static let barWidth: CGFloat = 847
    static let barHeight: CGFloat = 32
    static let barInset: CGFloat = 11
    static let menuHeight: CGFloat = 80
    static let lineHeight: CGFloat = 11 * 1.6
}
