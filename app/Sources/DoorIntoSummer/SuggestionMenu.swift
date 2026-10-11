import AppKit
import SwiftUI

private let markerColumn = "❯ "
private let columnGap: CGFloat = 14

struct SuggestionMenu: View {
    let kind: TokenKind
    let choices: [Choice]
    let chosen: Int
    let hovered: (Int) -> Void
    let picked: (Int) -> Void

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if choices.isEmpty {
                        Text(empty).foregroundStyle(Color.tertiaryText).frame(height: Layout.lineHeight)
                    }
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, choice in
                        row(choice, selected: index == chosen)
                            .id(choice.id)
                            .contentShape(Rectangle())
                            .onHover { inside in if inside { hovered(index) } }
                            .onTapGesture { picked(index) }
                            .pointerStyle(.link)
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.horizontalPadding)
            }
            .scrollTargetBehavior(.viewAligned)
            .onScrollGeometryChange(for: Int.self) { Int(($0.contentOffset.y / Layout.lineHeight).rounded(.down)) } action: { previous, row in
                guard previous != row else { return }
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            }
            .scrollIndicators(.hidden)
            .frame(height: Self.height(choices: choices.count))
            .background(Color.desk)
            .onChange(of: chosen, initial: true) { scrollToChosen(reader) }
            .onChange(of: choices.map(\.id)) { scrollToChosen(reader) }
        }
    }

    static func height(choices: Int) -> CGFloat {
        CGFloat(min(max(choices, 1), Layout.menuRows)) * Layout.lineHeight
    }

    private func scrollToChosen(_ reader: ScrollViewProxy) {
        if choices.indices.contains(chosen) {
            reader.scrollTo(choices[chosen].id)
        }
    }

    private var empty: String {
        switch kind {
        case .session: "No live image session to address."
        case .command: "No skill in ~/.hypnos/skills declares door-into-summer: command yet."
        }
    }

    private var nameColumnWidth: CGFloat {
        CGFloat(choices.map(\.value.count).max() ?? 0) * Mono.characterWidth
    }

    private func row(_ choice: Choice, selected: Bool) -> some View {
        HStack(spacing: 0) {
            Text(selected ? markerColumn : "").frame(width: CGFloat(markerColumn.count) * Mono.characterWidth, alignment: .leading)
            highlighted(choice).font(kind == .session ? .monoItalic : .mono).lineLimit(1)
                .frame(width: nameColumnWidth, alignment: .leading)
            Text(choice.about).lineLimit(1).truncationMode(.tail).padding(.leading, columnGap)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Layout.lineHeight)
        .foregroundStyle(selected ? Color.white : Color.tertiaryText)
    }

    private func highlighted(_ choice: Choice) -> Text {
        guard let matched = choice.matched else { return Text(choice.value) }
        return Text("\(String(choice.value[..<matched.lowerBound]))\(Text(String(choice.value[matched])).foregroundStyle(Color.mention))\(String(choice.value[matched.upperBound...]))")
    }
}
