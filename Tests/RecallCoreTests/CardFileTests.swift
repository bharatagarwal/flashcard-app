import Foundation
import Testing

@testable import RecallCore

private func fileTestDeck() throws -> Deck {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    return try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/starter.json")))
}

@Test func typedCardFileDistinguishesDeckFromBackup() throws {
    let deck = try fileTestDeck()
    guard case .deck(let imported) = try Codec.decode(CardFile.self, from: Codec.encode(deck)) else {
        Issue.record("A deck was mistaken for a backup")
        return
    }
    #expect(imported == deck)
    var library = Library(deck: deck)
    library.session = ReviewSession(queue: [deck.cards[0].id])
    try library.rate(cardID: deck.cards[0].id, rating: .good, at: Date(timeIntervalSince1970: 1_800_000_000))
    guard case .backup(let restored) = try Codec.decode(CardFile.self, from: Codec.encode(library)) else {
        Issue.record("A backup was mistaken for a deck")
        return
    }
    #expect(restored.deck == deck)
    #expect(restored.schedules == library.schedules)
    #expect(restored.contentVersions == library.contentVersions)
}

@Test func typedCardFileRejectsInvalidFieldTypes() {
    for json in ["{}", "[]", "{\"deck\":null}", "{\"schemaVersion\":\"two\"}"] {
        #expect(throws: (any Error).self) { try Codec.decode(CardFile.self, from: Data(json.utf8)) }
    }
}
