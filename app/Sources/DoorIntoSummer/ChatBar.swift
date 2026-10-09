import SwiftUI

struct ChatBar: View {
    let chat: Chat
    @State private var text = ""
    @State private var selection: TextSelection?
    @State private var chosen = 0
    @State private var dismissed: Token?
    @State private var refusal: String?
    @FocusState private var focused: Bool

    private var caret: String.Index {
        if case .selection(let range)? = selection?.indices, range.upperBound <= text.endIndex {
            return range.upperBound
        }
        return text.endIndex
    }

    private var currentToken: Token? {
        let found = token(in: text, caret: caret)
        return found == dismissed ? nil : found
    }

    private var currentChoices: [Choice] {
        currentToken.map { choices(for: $0, sessions: chat.sessions, commands: chat.commands) } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            if let currentToken {
                SuggestionMenu(kind: currentToken.kind, choices: currentChoices, chosen: chosen,
                               hovered: { chosen = $0 }, picked: { pick($0) })
                    .padding(.bottom, 32)
            }
            field
            if let refusal {
                Text(refusal).foregroundStyle(Color.alert).padding(.top, 6)
            }
        }
        .padding(.bottom, 20)
        .onChange(of: text) {
            chosen = 0
            refusal = nil
            if token(in: text, caret: caret) != dismissed {
                dismissed = nil
            }
        }
        .onChange(of: chat.tagging) {
            guard let session = chat.tagging else { return }
            let composed = tagged(text, with: session)
            text = composed.text
            selection = TextSelection(insertionPoint: composed.caret)
            focused = true
            chat.tagging = nil
        }
        .onAppear {
            focused = true
            chat.refreshCommands()
        }
    }

    private var field: some View {
        HStack(spacing: 12) {
            if let attached = chat.attached {
                HStack(spacing: 8) {
                    ReferenceLine(reference: attached, thumbnail: 20)
                    Button("×") { chat.detach() }.buttonStyle(.plain).foregroundStyle(Color.tertiaryText)
                }
                .frame(maxWidth: Layout.barWidth / 2, alignment: .leading)
            }
            TextField("", text: $text, selection: $selection)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.foreground)
                .focused($focused)
        }
            .padding(.horizontal, Layout.barInset)
            .frame(maxWidth: Layout.barWidth)
            .frame(height: Layout.barHeight)
            .glassEffect(.regular.interactive(), in: Capsule())
            .padding(.horizontal, Layout.horizontalPadding)
            .onSubmit { send() }
            .onKeyPress(.upArrow) { move(-1) }
            .onKeyPress(.downArrow) { move(1) }
            .onKeyPress(.tab) { pickChosen() }
            .onKeyPress(.return) { pickChosen() }
            .onKeyPress(.escape) { dismiss() }
            .onChange(of: currentToken) { if currentToken != nil { chat.refreshCommands() } }
    }

    private func move(_ step: Int) -> KeyPress.Result {
        let count = currentChoices.count
        guard currentToken != nil, count > 0 else { return .ignored }
        chosen = (chosen + step + count) % count
        return .handled
    }

    private func pickChosen() -> KeyPress.Result {
        guard currentToken != nil else { return .ignored }
        if currentChoices.indices.contains(chosen) {
            pick(chosen)
        }
        return .handled
    }

    private func dismiss() -> KeyPress.Result {
        guard let currentToken else { return .ignored }
        dismissed = currentToken
        return .handled
    }

    private func pick(_ index: Int) {
        guard let currentToken, currentChoices.indices.contains(index) else { return }
        let done = completed(currentChoices[index], in: text, replacing: currentToken)
        text = done.text
        selection = TextSelection(insertionPoint: done.caret)
        chosen = 0
        focused = true
    }

    private func send() {
        let message = text
        guard !message.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            refusal = await chat.send(message)
            if refusal == nil, text == message {
                text = ""
            }
        }
    }
}
