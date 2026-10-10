import AppKit
import SwiftUI

struct PointingButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PointingButton(configuration: configuration)
    }
}

extension PrimitiveButtonStyle where Self == PointingButtonStyle {
    static var pointing: PointingButtonStyle { PointingButtonStyle() }
}

private struct PointingButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        PlainButtonStyle().makeBody(configuration: configuration)
            .cursor(enabled ? .pointingHand : nil)
    }
}
