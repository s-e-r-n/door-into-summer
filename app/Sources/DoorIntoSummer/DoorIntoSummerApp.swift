import NativeWindow
import SwiftUI

struct DoorIntoSummerApp: App {
    static var address = ReviewServer.defaultAddress
    @State private var chat = Chat(server: ReviewServer(address: address))

    var body: some Scene {
        window {
            ChatView(chat: chat)
        }
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Details") { chat.toggleInspector() }.keyboardShortcut("b")
            }
            CommandGroup(replacing: .help) {
                GuideButton()
            }
        }
        Window("Door into Summer Help", id: "guide") {
            Guide()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commandsRemoved()
    }
}

private struct GuideButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Door into Summer Help") { openWindow(id: "guide") }
    }
}
