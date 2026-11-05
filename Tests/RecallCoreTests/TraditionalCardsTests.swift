import Foundation
import Testing

@testable import RecallCore

private let traditionalRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
private func traditionalDeck(_ path: String = "App/Resources/starter.json") throws -> Deck {
    try Codec.decode(Deck.self, from: Data(contentsOf: traditionalRoot.appendingPathComponent(path)))
}

@Test func traditionalCardsHaveShortBacksWithoutLessonsHintsOrDecorations() throws {
    let deck = try traditionalDeck()
    try deck.validate()
    let active = deck.cards.filter { !$0.isArchived }
    #expect(active.count == 70)
    #expect(deck.cards.filter(\.isArchived).count == 15)
    #expect(deck.assets?.isEmpty != false)
    for card in active {
        #expect(card.hint.isEmpty)
        #expect(card.explanationSections?.isEmpty != false)
        #expect(card.answerBlocks?.isEmpty != false)
        #expect(card.answer.count < 200)
        #expect(!card.prompt.lowercased().contains("derive"))
        #expect(!card.prompt.lowercased().contains("explain"))
    }
}

@Test func retirementKeepsHistoryAndSchedulesButRemovesPendingReviews() throws {
    var old = Library(deck: try traditionalDeck("Tests/Fixtures/v2-lessons-deck.json"))
    old.session = ReviewSession(queue: ["angles.rotation", "angles.double", "angles.sin"])
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    try old.rate(cardID: "angles.rotation", rating: .good, at: now)
    let updated = try old.refreshingBundledContent(from: traditionalDeck())
    #expect(updated.schedules == old.schedules)
    #expect(updated.events.map(\.id) == old.events.map(\.id))
    #expect(updated.contentVersions == old.contentVersions)
    #expect(updated.session?.queue == ["angles.sin"])
    #expect(updated.session?.completed == 1)
    #expect(updated.session?.total == 2)
    #expect(!updated.dueCards(at: now.addingTimeInterval(86400 * 365)).contains { $0.isArchived })
    #expect(updated.deck.cards.first { $0.id == "angles.rotation" }?.isArchived == true)
    let restored = try Codec.decode(Library.self, from: Codec.encode(updated))
    try restored.validate()
    #expect(restored.deck == updated.deck)
    #expect(restored.contentVersions == old.contentVersions)
    #expect(restored.schedules == old.schedules)
}

@Test func anArchivedCardCannotBeGradedOrSetTheNextReviewDate() throws {
    var library = Library(deck: try traditionalDeck())
    let archived = try #require(library.deck.cards.first { $0.isArchived })
    let active = try #require(library.deck.cards.first { !$0.isArchived })
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var retiredSchedule = try library.preview(cardID: archived.id, rating: .good, at: now)
    var activeSchedule = try library.preview(cardID: active.id, rating: .good, at: now)
    retiredSchedule.due = now.addingTimeInterval(60)
    activeSchedule.due = now.addingTimeInterval(86400)
    library.schedules[archived.id] = retiredSchedule
    library.schedules[active.id] = activeSchedule
    #expect(library.nextReviewDate == activeSchedule.due)
    library.session = ReviewSession(queue: [archived.id])
    #expect(throws: RecallError.self) { try library.rate(cardID: archived.id, rating: .good, at: now) }
    #expect(library.events.isEmpty)
    library.removeUnavailableCardsFromSession()
    #expect(library.session?.queue.isEmpty == true)
    #expect(library.session?.total == 0)
}

@Test func importingRetirementPreservesExistingGrades() throws {
    var old = Library(deck: try traditionalDeck("Tests/Fixtures/v2-lessons-deck.json"))
    old.session = ReviewSession(queue: ["angles.sin", "angles.rotation"])
    try old.rate(cardID: "angles.sin", rating: .good, at: Date(timeIntervalSince1970: 1_800_000_000))
    let before = old.schedules
    try old.merge(traditionalDeck())
    #expect(old.schedules == before)
    #expect(old.session?.queue.isEmpty == true)
    #expect(old.events.count == 1)
    #expect(old.contentVersions?.values.first?.card.explanationSections?.isEmpty == false)
}

@Test func restoringAnArchivedCardPersistsAndSurvivesTheBundledRefresh() throws {
    let starter = try traditionalDeck()
    var library = Library(deck: starter)
    let card = try #require(starter.cards.first { $0.isArchived })
    try library.setArchived(cardID: card.id, archived: false)
    #expect(library.deck.cards.first { $0.id == card.id }?.revision == card.revision + 1)
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DatabaseStore(url: folder.appendingPathComponent("library.sqlite"))
    try store.save(library)
    let saved = try store.load()
    let loaded = try #require(saved)
    let updated = try loaded.refreshingBundledContent(from: starter)
    #expect(updated.deck.cards.first { $0.id == card.id }?.isArchived == false)
    #expect(updated.dueCards(at: Date()).contains { $0.id == card.id })
}

@Test func archiveAndRestoreKeepGradesSchedulesAndSnapshots() throws {
    var library = Library(deck: try traditionalDeck())
    let card = try #require(library.deck.cards.first { !$0.isArchived })
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    library.session = ReviewSession(queue: [card.id])
    try library.rate(cardID: card.id, rating: .good, at: now)
    let schedules = library.schedules
    let history = library.events.map(\.id)
    let snapshots = library.contentVersions
    try library.setArchived(cardID: card.id, archived: true)
    #expect(!library.dueCards(at: now.addingTimeInterval(86400 * 365)).contains { $0.id == card.id })
    try library.setArchived(cardID: card.id, archived: false)
    #expect(library.schedules == schedules)
    #expect(library.events.map(\.id) == history)
    #expect(library.contentVersions == snapshots)
    #expect(library.dueCards(at: now.addingTimeInterval(86400 * 365)).contains { $0.id == card.id })
    let revision = library.deck.cards.first { $0.id == card.id }?.revision
    try library.setArchived(cardID: card.id, archived: false)
    #expect(library.deck.cards.first { $0.id == card.id }?.revision == revision)
    try library.validate()
}

@Test func archivingRemovesPendingReviewsAndRestoringDoesNotChangeASessionInProgress() throws {
    var library = Library(deck: try traditionalDeck())
    let active = Array(library.deck.cards.filter { !$0.isArchived }.prefix(2))
    library.session = ReviewSession(queue: active.map(\.id))
    try library.rate(cardID: active[0].id, rating: .good, at: Date())
    try library.setArchived(cardID: active[1].id, archived: true)
    #expect(library.session?.queue == [])
    #expect(library.session?.completed == 1)
    #expect(library.session?.total == 1)
    try library.setArchived(cardID: active[1].id, archived: false)
    #expect(library.session?.queue == [])
    #expect(library.session?.completed == 1)
    #expect(library.dueCards(at: Date()).contains { $0.id == active[1].id })
}
