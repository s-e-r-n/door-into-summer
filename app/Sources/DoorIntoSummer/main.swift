import AppKit
import CoreText
import Foundation

func registeredFonts() {
    guard let fonts = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else { return }
    CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
}

registeredFonts()
_ = HexSprite.shared
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
