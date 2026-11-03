import Foundation
import Testing

@testable import RecallCore

private func lessonDeck() throws -> Deck {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    return try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Tests/Fixtures/v2-lessons-deck.json")))
}

@Test func legacyLessonDeckRemainsReadableWithAllFiguresAndReasoning() throws {
    let deck = try lessonDeck()
    try deck.validate()
    var figureIDs = Set<String>()
    var introductions = Set<String>()
    for card in deck.cards {
        let sections = try #require(card.explanationSections)
        #expect(sections.contains { $0.role == .derivation && ($0.steps?.count ?? 0) >= 2 })
        #expect(sections.contains { $0.role == .pitfall })
        let idea = try #require(sections.first { $0.role == .intuition })
        #expect(introductions.insert(idea.blocks.compactMap(\.text).joined()).inserted)
        #expect(sections != deck.concepts.first { $0.id == card.conceptID }?.sections)
        let figure = try #require(card.answerBlocks?.first { $0.kind == .diagram })
        #expect(figureIDs.insert(try #require(figure.assetID)).inserted)
        let asset = try #require(deck.assets?.first { $0.id == figure.assetID })
        #expect(asset.darkData != nil)
    }
    #expect(figureIDs.count == deck.cards.count)
}

@Test func cardLessonsRejectMissingFiguresAndUnsourcedHistory() throws {
    var deck = try lessonDeck()
    deck.cards[0].explanationSections = [
        .init(
            id: "lesson", role: .intuition, title: "Missing",
            blocks: [.init(id: "figure", kind: .diagram, assetID: "missing")])
    ]
    #expect(throws: RecallError.self) { try deck.validate() }
    deck.cards[0].explanationSections = [
        .init(
            id: "history", role: .history, title: "Claim",
            blocks: [.init(id: "text", kind: .text, text: "A historical claim")])
    ]
    #expect(throws: RecallError.self) { try deck.validate() }
}

@Test func cardLessonUpdatesKeepTheReviewedExplanationAndSchedule() throws {
    let original = try lessonDeck()
    let id = original.cards[0].id
    var library = Library(deck: original)
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: Date(timeIntervalSince1970: 1_800_000_000))
    let key = try #require(library.events.first?.contentID)
    let schedule = library.schedules[id]
    var incoming = original
    incoming.cards[0].revision += 1
    incoming.cards[0].explanationSections?[0].blocks[0].text = "A revised explanation."
    incoming.cards[0].change = .explanation
    try library.merge(incoming)
    #expect(library.schedules[id] == schedule)
    #expect(library.contentVersions?[key]?.card.explanationSections == original.cards[0].explanationSections)
    #expect(library.deck.cards[0].explanationSections != original.cards[0].explanationSections)
    let restored = try Codec.decode(Library.self, from: Codec.encode(library))
    try restored.validate()
    #expect(restored.contentVersions?[key]?.card.explanationSections == original.cards[0].explanationSections)
    #expect(restored.deck.cards[0].explanationSections == incoming.cards[0].explanationSections)
}
