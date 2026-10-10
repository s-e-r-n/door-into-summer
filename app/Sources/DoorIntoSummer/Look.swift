import AppKit
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
}

@MainActor
enum Mono {
    static let font = NSFont(name: "JetBrainsMono-Thin", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .thin)
    static let italic = NSFont(name: "JetBrainsMono-ThinItalic", size: 11) ?? font
    static let characterWidth = font.maximumAdvancement.width
    static let lineHeight = font.ascender - font.descender + font.leading
    static let ascender = font.ascender
}

struct TextStyle: Hashable {
    let font: NSFont
    let color: NSColor

    @MainActor static let text = TextStyle(font: Mono.font, color: NSColor(Color.foreground))
    @MainActor static let faint = TextStyle(font: Mono.font, color: NSColor(Color.tertiaryText))
    @MainActor static let session = TextStyle(font: Mono.italic, color: NSColor(Color.secondaryText))
    @MainActor static let reviewer = TextStyle(font: Mono.italic, color: .white)
    @MainActor static let reference = TextStyle(font: Mono.italic, color: NSColor(Color.tertiaryText))
    @MainActor static let mention = TextStyle(font: Mono.italic, color: NSColor(Color.mention))
    @MainActor static let command = TextStyle(font: Mono.font, color: NSColor(Color.command))
    @MainActor static let lit = TextStyle(font: Mono.font, color: NSColor(Color.lit))
    @MainActor static let alert = TextStyle(font: Mono.font, color: NSColor(Color.alert))
}

enum Layout {
    static let horizontalPadding: CGFloat = 32
    static let panelWidth: CGFloat = 400
    static let barWidth: CGFloat = 847
    static let barHeight: CGFloat = 32
    static let barInset: CGFloat = 11
    static let barBottomPadding: CGFloat = 20
    static let menuHeight: CGFloat = 80
    static let lineHeight: CGFloat = 11 * 1.6
    static let titleBarHeight: CGFloat = 20
}
