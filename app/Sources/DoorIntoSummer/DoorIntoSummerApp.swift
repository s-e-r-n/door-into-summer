import NativeWindow
import SwiftUI

struct DoorIntoSummerApp: App {
    @State private var chat = Chat()

    var body: some Scene {
        window {
            ChatView(chat: chat)
        }
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Details") { chat.toggleInspector() }.keyboardShortcut("b")
            }
        }
    }
}
