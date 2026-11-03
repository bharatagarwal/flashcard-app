import RecallCore
import SwiftUI

/// Topics occupy stable positions, so panning does not change their order or a card’s schedule.
struct LibraryCanvasView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let cardIDs: [String]
    var archived = false

    private var groups: [(topic: Concept, cards: [Flashcard])] {
        let included = Set(cardIDs)
        let cards = (model.library?.deck.cards ?? []).filter {
            included.contains($0.id) && $0.isArchived == archived
        }
        return (model.library?.deck.concepts ?? []).compactMap { topic in
            let group = cards.filter { $0.conceptID == topic.id }
            return group.isEmpty ? nil : (topic, group)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(264), spacing: 32), count: 3),
                    alignment: .leading, spacing: 36
                ) {
                    ForEach(groups, id: \.topic.id) { group in
                        if let first = group.cards.first {
                            NavigationLink {
                                CardDetailView(cardID: first.id, cardIDs: group.cards.map(\.id))
                            } label: {
                                topicStack(group.topic, cards: group.cards, first: first)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(group.topic.title), \(group.cards.count) cards")
                            .accessibilityHint("Browse this topic")
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 48)
            }
            .background(Palette.paper)
            .navigationTitle("Library canvas").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Pan to explore · Tap a topic to browse")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(12).background(.bar)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func topicStack(_ topic: Concept, cards: [Flashcard], first: Flashcard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(topic.title).font(.headline)
                Spacer(minLength: 4)
                Text("\(cards.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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
        }
        .frame(width: 264, alignment: .leading)
        .contentShape(Rectangle())
    }
}
