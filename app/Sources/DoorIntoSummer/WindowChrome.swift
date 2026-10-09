import SwiftUI

struct TitleBar: View {
    var body: some View {
        Color.clear
            .frame(height: Layout.titleBarHeight)
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents()
    }
}
