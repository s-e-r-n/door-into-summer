import SwiftUI

public struct window<content_view: View>: Scene {
  private let content: content_view

  public init(@ViewBuilder content: () -> content_view) {
    self.content = content()
  }

  public var body: some Scene {
    WindowGroup {
      ZStack { content }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .containerBackground(Color.black, for: .window)
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .preferredColorScheme(.dark)
    }
    .windowStyle(.hiddenTitleBar)
    .windowBackgroundDragBehavior(.disabled)
    .defaultWindowPlacement { _, context in
      let screen = context.defaultDisplay.visibleRect
      let size = CGSize(width: (screen.width * 2 / 3).rounded(), height: screen.height)
      return WindowPlacement(CGPoint(x: screen.midX - size.width / 2, y: screen.minY), size: size)
    }
    .restorationBehavior(.disabled)
  }
}
