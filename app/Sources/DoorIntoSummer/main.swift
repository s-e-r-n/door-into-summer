import AppKit
import CoreText
import Foundation

func registeredFonts() {
    let resources = Bundle.main.url(forResource: "DoorIntoSummer_DoorIntoSummer", withExtension: "bundle").flatMap(Bundle.init(url:))
    guard let fonts = resources?.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else { return }
    CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
}

registeredFonts()
_ = HexSprite.shared
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
