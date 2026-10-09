import SwiftUI

struct Guide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(verbatim: "Each image session posts every generation in the chat; the reviewer answers a generation with @<session>, and that session generates the next one. validate files the image of a generation in the gallery.")
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "chatbox").foregroundStyle(Color.tertiaryText)
                Shortcut(key: "@", about: "lists the live sessions; the one picked addresses the instruction after it, and each further @<session> in the message addresses another session")
                Shortcut(key: "/", about: "inside an instruction, lists the skills offered as commands; the one picked goes to the session with its instruction")
                Shortcut(key: "↑ ↓", about: "moves through the list")
                Shortcut(key: "Enter or Tab", about: "picks from the list")
                Shortcut(key: "Esc", about: "closes the list")
                Shortcut(key: "Enter", about: "with no list open, sends the message, which opens with @<session>")
                Shortcut(key: "×", about: "on the chip of a reference, drops it")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "generation").foregroundStyle(Color.tertiaryText)
                Shortcut(key: "@<session>", about: "click: the message in the chatbox then opens with @<session>")
                Shortcut(key: "use as reference", about: "the next message sent carries this image's job and URL to every session it addresses; until then its chip, @<session> · image generation <n>, waits in the chatbox")
                Shortcut(key: "details", about: "opens and closes the details of this generation")
                Shortcut(key: "validate", about: "files this image in the gallery; the generation then reads validated")
                Shortcut(key: "Cmd+B", about: "opens and closes the details of the last generation opened")
            }
        }
        .frame(width: 560, alignment: .leading)
        .padding(28)
        .font(.mono)
        .foregroundStyle(Color.foreground)
        .containerBackground(Color.desk, for: .window)
        .preferredColorScheme(.dark)
    }
}

private struct Shortcut: View {
    let key: String
    let about: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(key).frame(width: 130, alignment: .leading)
            Text(about).foregroundStyle(Color.secondaryText).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
