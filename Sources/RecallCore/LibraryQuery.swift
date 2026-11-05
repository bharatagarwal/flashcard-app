import Foundation

public struct LibraryQuery: Hashable, Sendable {
    public let archived: Bool
    public let needsUnderstandingOnly: Bool
    public let search: String
    public init(archived: Bool = false, needsUnderstandingOnly: Bool = false, search: String = "") {
        self.archived = archived
        self.needsUnderstandingOnly = needsUnderstandingOnly
        self.search = search
    }
}

public struct LibraryGroup: Identifiable, Equatable, Sendable {
    public let concept: Concept
    public let cards: [Flashcard]
    public var id: String { concept.id }
}

extension Library {
    /// Canvas and list consume the same ordered results and cannot disagree about personal marks.
    public func groups(matching query: LibraryQuery) -> [LibraryGroup] {
        let titles = Dictionary(uniqueKeysWithValues: deck.concepts.map { ($0.id, $0.title) })
        let cards = deck.cards.filter {
            $0.isArchived == query.archived
                && (!query.needsUnderstandingOnly || needsUnderstanding($0.id))
                && (query.search.isEmpty
                    || ($0.prompt + " " + $0.answer + " " + (titles[$0.conceptID] ?? ""))
                        .localizedCaseInsensitiveContains(query.search))
        }
        let byTopic = Dictionary(grouping: cards, by: \.conceptID)
        return deck.concepts.compactMap { concept in
            guard let cards = byTopic[concept.id], !cards.isEmpty else { return nil }
            return LibraryGroup(concept: concept, cards: cards)
        }
    }
}
