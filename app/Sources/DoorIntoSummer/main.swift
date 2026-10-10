import CoreText
import Foundation

func registeredFonts() {
    guard let fonts = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else { return }
    CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
}

registeredFonts()
_ = HexSprite.shared
DoorIntoSummerApp.main()
