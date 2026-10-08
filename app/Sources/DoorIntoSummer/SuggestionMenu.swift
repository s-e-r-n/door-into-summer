import SwiftUI

struct SuggestionMenu: View {
    let kind: TokenKind
    let choices: [Choice]
    let chosen: Int
    let hovered: (Int) -> Void
    let picked: (Int) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if choices.isEmpty {
                        Text(empty).foregroundStyle(Color.tertiaryText)
                    }
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        row(choice, selected: index == chosen)
                            .id(choice.id)
                            .contentShape(Rectangle())
                            .onHover { inside in if inside { hovered(index) } }
                            .onTapGesture { picked(index) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, Layout.horizontalPadding)
            }
            .scrollIndicators(.hidden)
            .frame(height: Layout.menuHeight)
            .background(Color.desk)
            .onChange(of: chosen, initial: true) {
                if choices.indices.contains(chosen) {
                    reader.scrollTo(choices[chosen].id)
                }
            }
        }
    }

    private var empty: String {
        switch kind {
        case .session: "No live image session to address."
        case .command: "No skill in ~/.hypnos/skills declares door-into-summer: command yet."
        }
    }

    private func row(_ choice: Choice, selected: Bool) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 0) {
                    Text(selected ? "❯ " : "  ")
                    highlighted(choice).font(kind == .session ? .monoItalic : .mono).lineLimit(1)
                }
                .frame(width: geometry.size.width * 0.4, alignment: .leading)
                Text(choice.about).lineLimit(2).truncationMode(.tail).padding(.leading, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(selected ? Color.white : Color.tertiaryText)
        }
        .frame(height: Layout.lineHeight * 2)
    }

    private func highlighted(_ choice: Choice) -> Text {
        guard let matched = choice.matched else { return Text(choice.value) }
        return Text("\(String(choice.value[..<matched.lowerBound]))\(Text(String(choice.value[matched])).foregroundStyle(Color.mention))\(String(choice.value[matched.upperBound...]))")
    }
}
