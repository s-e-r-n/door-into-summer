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
        .preferredColorScheme(.dark)
    }
    .windowStyle(.hiddenTitleBar)
    .defaultWindowPlacement { _, context in
      WindowPlacement(context.defaultDisplay.visibleRect.origin, size: context.defaultDisplay.visibleRect.size)
    }
    .restorationBehavior(.disabled)
  }
}
