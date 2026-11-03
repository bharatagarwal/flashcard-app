import Foundation

extension Library {
    /// Archiving changes review eligibility, never schedules or historical content snapshots.
    public mutating func setArchived(cardID: String, archived: Bool) throws {
        guard let index = deck.cards.firstIndex(where: { $0.id == cardID }) else {
            throw RecallError.invalid("This card is no longer in your library.")
        }
        guard deck.cards[index].isArchived != archived else { return }
        guard deck.cards[index].revision < Int.max else {
            throw RecallError.invalid("This card’s revision cannot be increased.")
        }
        deck.cards[index].archived = archived
        deck.cards[index].revision += 1
        removeArchivedCardsFromSession()
    }
}
