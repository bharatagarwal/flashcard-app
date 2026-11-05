import RecallCore
import SwiftUI

/// A shared query supplies these topic stacks; switching to the list preserves the same scope.
struct LibraryCanvasView: View {
    @EnvironmentObject var model: AppModel
    let groups: [LibraryGroup]
    let needsUnderstandingOnly: Bool

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(264), spacing: 32), count: 3),
                alignment: .leading, spacing: 36
            ) {
                ForEach(groups) { group in
                    if let first = group.cards.first {
                        NavigationLink {
                            CardDetailView(
                                cardID: first.id, cardIDs: group.cards.map(\.id),
                                needsUnderstandingOnly: needsUnderstandingOnly)
                        } label: {
                            topicStack(group, first: first)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(group.concept.title), \(group.cards.count) \(group.cards.count == 1 ? "card" : "cards")"
                        )
                        .accessibilityHint("Browse this topic")
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 48)
        }
        .safeAreaInset(edge: .bottom) {
            if !groups.isEmpty {
                Text("Pan to explore · Tap a topic to browse")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(12).background(.bar)
            }
        }
    }

    private func topicStack(_ group: LibraryGroup, first: Flashcard) -> some View {
        let paused = group.cards.filter { model.library?.needsUnderstanding($0.id) == true }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.concept.title).font(.headline)
                Spacer(minLength: 4)
                Text("\(group.cards.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Palette.surface)
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)) }
                    .rotationEffect(.degrees(3)).offset(x: 3, y: 9)
                RoundedRectangle(cornerRadius: 20).fill(Palette.surface)
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)) }
                    .rotationEffect(.degrees(-2)).offset(x: -3, y: 5)
                MathText(first.prompt, pointSize: 19)
                    .padding(22).frame(maxWidth: .infinity).frame(height: 208)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)) }
            }
            .frame(height: 208).padding(.bottom, 10)
            .allowsHitTesting(false)
            if paused > 0 {
                Label(
                    needsUnderstandingOnly ? "Memory reviews paused" : "\(paused) need understanding",
                    systemImage: "questionmark.circle"
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 264, alignment: .leading)
        .contentShape(Rectangle())
    }
}
