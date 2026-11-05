import Foundation

/// Personal understanding is independent of card content, archiving, and FSRS memory estimates.
public enum CardUnderstanding: String, Codable, Equatable, Sendable {
    case needsUnderstanding
    case understood
}

extension Library {
    public func needsUnderstanding(_ cardID: String) -> Bool {
        understanding?[cardID] == .needsUnderstanding
    }
    public func isEligibleForReview(_ card: Flashcard) -> Bool {
        !card.isArchived && !needsUnderstanding(card.id)
    }
    public var needsUnderstandingCount: Int {
        deck.cards.filter { !$0.isArchived && needsUnderstanding($0.id) }.count
    }
    public mutating func setUnderstanding(_ status: CardUnderstanding, cardID: String) throws {
        guard deck.cards.contains(where: { $0.id == cardID }) else {
            throw RecallError.invalid("This card is no longer in your library.")
        }
        guard understanding?[cardID] != status else { return }
        if understanding == nil { understanding = [:] }
        understanding?[cardID] = status
        // Becoming understood restores eligibility, but never inserts cards into a running session.
        removeUnavailableCardsFromSession()
    }
}
