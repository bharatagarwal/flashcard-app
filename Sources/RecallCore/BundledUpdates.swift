import Foundation

extension Library {
    /// Apply newer shipped lessons without resetting schedules or replacing local edits
    /// at the same or a higher revision. Review snapshots remain immutable.
    public func refreshingBundledContent(from bundled: Deck) throws -> Library {
        try bundled.validate()
        var result = self
        for concept in bundled.concepts {
            if let index = result.deck.concepts.firstIndex(where: { $0.id == concept.id }) {
                if concept.effectiveRevision > result.deck.concepts[index].effectiveRevision {
                    result.deck.concepts[index] = concept
                }
            } else {
                result.deck.concepts.append(concept)
            }
        }
        for card in bundled.cards {
            if let index = result.deck.cards.firstIndex(where: { $0.id == card.id }) {
                let old = result.deck.cards[index]
                guard card.revision > old.revision,
                    card.effectiveObjective == old.effectiveObjective,
                    card.conceptID == old.conceptID, card.kind == old.kind,
                    card.prompt == old.prompt || card.change == .wording
                else { continue }
                result.deck.cards[index] = card
            } else {
                result.deck.cards.append(card)
            }
        }
        var assets = result.deck.assets ?? []
        for asset in bundled.assets ?? [] where !assets.contains(where: { $0.id == asset.id }) {
            assets.append(asset)
        }
        if !assets.isEmpty { result.deck.assets = assets }
        result.deck.schemaVersion = max(result.deck.schemaVersion, bundled.schemaVersion)
        result.removeArchivedCardsFromSession()
        try result.validate()
        return result
    }
}
