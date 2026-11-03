import CSQLite
import Foundation
import Testing

@testable import RecallCore

private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()
private func currentDeck() throws -> Deck {
    try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Examples/math-foundations.json")))
}
private let instant = Date(timeIntervalSince1970: 1_800_000_000)
private func folder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func legacyJSONMigratesWithoutLosingOrDeletingAnything() throws {
    let location = try folder()
    defer { try? FileManager.default.removeItem(at: location) }
    let oldDeck = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Tests/Fixtures/v1-deck.json")))
    var legacy = Library(deck: oldDeck)
    legacy.schemaVersion = 1
    legacy.session = ReviewSession(queue: [oldDeck.cards[0].id])
    try legacy.rate(cardID: oldDeck.cards[0].id, rating: .good, at: instant)
    // Simulate a genuine v1 review, which did not keep content snapshots.
    legacy.events[0].contentID = nil
    legacy.contentVersions = nil
    let json = DiskStore(url: location.appendingPathComponent("library.json"))
    try json.save(legacy)
    let untouched = try Data(contentsOf: json.url)
    let database = DatabaseStore(url: location.appendingPathComponent("library.sqlite"))
    let migrated = try #require(try database.loadOrMigrateLegacy(at: json.url))
    #expect(migrated.deck == legacy.deck)
    #expect(migrated.schedules == legacy.schedules)
    #expect(migrated.events.count == 1)
    #expect(migrated.events[0].contentID == nil)
    #expect(try Data(contentsOf: json.url) == untouched)
    let plan = try currentDeck().plan(against: migrated.deck)
    #expect(plan.updated == 46)
    #expect(plan.updates.allSatisfy { !$0.suggestedReset })
}

@Test func oldContentSurvivesRewordingAndAnswerEdits() throws {
    var library = Library(deck: try currentDeck())
    let oldCard = library.deck.cards[0]
    let id = oldCard.id
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: instant)
    let previous = library.schedules[id]
    let hash = try #require(library.events.first?.contentID)
    var incoming = library.deck
    incoming.cards[0].revision += 1
    incoming.cards[0].prompt += " Use the standard identity."
    incoming.cards[0].change = .wording
    let plan = try incoming.plan(against: library.deck)
    #expect(plan.updated == 1)
    try library.merge(incoming)
    #expect(library.schedules[id] == previous)
    #expect(library.contentVersions?[hash]?.card.prompt == oldCard.prompt)
    incoming.cards[0].revision += 1
    incoming.cards[0].answer += " Corrected answer."
    incoming.cards[0].change = .correction
    incoming.cards[0].answerBlocks = nil
    #expect(try incoming.plan(against: library.deck).updates[0].suggestedReset)
    try library.merge(incoming, resetting: [id])
    #expect(library.schedules[id] == nil)
    #expect(library.events.count == 1)
    #expect(library.contentVersions?[hash]?.card.answer == oldCard.answer)
    try library.validate()
}

@Test func objectiveChangesAndUnversionedConceptChangesAreRejected() throws {
    let deck = try currentDeck()
    var incoming = deck
    incoming.cards[0].objectiveID = "a.different.skill"
    incoming.cards[0].revision += 1
    incoming.cards[0].change = .wording
    #expect(throws: RecallError.self) { try incoming.plan(against: deck) }
    incoming = deck
    incoming.concepts[0].explanation += " Edited."
    #expect(throws: RecallError.self) { try incoming.plan(against: deck) }
    incoming.concepts[0].revision = incoming.concepts[0].effectiveRevision + 1
    _ = try incoming.plan(against: deck)
}

@Test func databaseRoundTripAndNoOpSave() throws {
    let location = try folder()
    defer { try? FileManager.default.removeItem(at: location) }
    let database = DatabaseStore(url: location.appendingPathComponent("library.sqlite"))
    var library = Library(deck: try currentDeck())
    let id = library.deck.cards[0].id
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: instant)
    try database.save(library)
    let result = try #require(try database.load())
    #expect(result.deck == library.deck)
    #expect(result.schedules == library.schedules)
    #expect(result.contentVersions == library.contentVersions)
    #expect(result.session == library.session)
    let bytes = try Data(contentsOf: database.url)
    try database.save(result)
    #expect(try Data(contentsOf: database.url) == bytes)
}

@Test func databaseRollsBackAllChangesWhenAnEventCannotSave() throws {
    let location = try folder()
    defer { try? FileManager.default.removeItem(at: location) }
    let database = DatabaseStore(url: location.appendingPathComponent("library.sqlite"))
    var library = Library(deck: try currentDeck())
    try database.save(library)
    var db: OpaquePointer?
    #expect(sqlite3_open(database.url.path, &db) == SQLITE_OK)
    #expect(
        sqlite3_exec(
            db,
            "CREATE TRIGGER reject_review BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'test failure'); END;",
            nil, nil, nil) == SQLITE_OK)
    sqlite3_close(db)
    let id = library.deck.cards[0].id
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: instant)
    #expect(throws: (any Error).self) { try database.save(library) }
    let saved = try #require(try database.load())
    #expect(saved.events.isEmpty)
    #expect(saved.schedules.isEmpty)
    #expect(saved.contentVersions == nil)
    #expect(saved.session == nil)
}

@Test func corruptDatabaseCanBeReplacedFromABackup() throws {
    let location = try folder()
    defer { try? FileManager.default.removeItem(at: location) }
    let database = DatabaseStore(url: location.appendingPathComponent("library.sqlite"))
    let broken = Data("not a database".utf8)
    try broken.write(to: database.url)
    #expect(throws: (any Error).self) { try database.load() }
    #expect(try Data(contentsOf: database.url) == broken)
    let backup = Library(deck: try currentDeck())
    try database.replace(with: backup)
    #expect(try database.load()?.deck == backup.deck)
}

@Test func prerequisiteCyclesAndMissingDiagramsAreRejected() throws {
    var deck = try currentDeck()
    deck.concepts[0].prerequisiteIDs = [deck.concepts[1].id]
    deck.concepts[1].prerequisiteIDs = [deck.concepts[0].id]
    #expect(throws: RecallError.self) { try deck.validate() }
    deck = try currentDeck()
    deck.concepts[0].sections = [
        .init(
            id: "s", role: .intuition, title: "Figure",
            blocks: [.init(id: "b", kind: .diagram, assetID: "missing")])
    ]
    #expect(throws: RecallError.self) { try deck.validate() }
    deck.concepts[0].sections = [
        .init(
            id: "s", role: .history, title: "History",
            blocks: [.init(id: "b", kind: .text, text: "A historical claim")])
    ]
    #expect(throws: RecallError.self) { try deck.validate() }
}

@Test func repeatedReviewsReuseTheSameContentSnapshot() throws {
    var library = Library(deck: try currentDeck())
    let id = library.deck.cards[0].id
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .again, at: instant)
    let next = try #require(library.schedules[id]?.due)
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: next)
    #expect(library.contentVersions?.count == 1)
    #expect(library.events[0].contentID == library.events[1].contentID)
    let settings = try #require(library.contentVersions?.values.first?.scheduler)
    #expect(settings.weights.count == 21)
    #expect(settings.retention == 0.9)
    try library.validate()
}

@Test func compiledTikZTravelsWithTheDeckAndRejectsChangedBytes() throws {
    let deck = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Tests/Fixtures/v2-lessons-deck.json")))
    let asset = try #require(deck.assets?.first)
    try asset.validate()
    #expect(asset.data.starts(with: Data("%PDF-".utf8)))
    #expect(asset.data.count < 20_000)
    #expect(asset.darkData?.starts(with: Data("%PDF-".utf8)) == true)
    #expect(String(data: try Codec.encode(deck), encoding: .utf8)?.contains("latexSource") == false)
    let restored = try Codec.decode(Deck.self, from: Codec.encode(deck))
    try restored.validate()
    #expect(restored.assets == deck.assets)
    var changed = asset
    changed.data.append(0)
    #expect(throws: RecallError.self) { try changed.validate() }
}

@Test func legacyImportCannotDowngradeVersionedConcepts() throws {
    let oldDeck = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Tests/Fixtures/v1-deck.json")))
    let current = try currentDeck()
    #expect(throws: RecallError.self) { try oldDeck.plan(against: current) }
}

@Test func bundledPresentationUpdatesPreserveTheSessionAndReviewHistory() throws {
    let oldDeck = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Tests/Fixtures/v1-deck.json")))
    var old = Library(deck: oldDeck)
    let id = oldDeck.cards[0].id
    old.session = ReviewSession(queue: Array(oldDeck.cards.prefix(3).map(\.id)))
    try old.rate(cardID: id, rating: .good, at: instant)
    let contentID = try #require(old.events.first?.contentID)
    let refreshed = try old.refreshingBundledContent(from: currentDeck())
    #expect(refreshed.schedules == old.schedules)
    var expectedSession = old.session!
    let archived = Set(refreshed.deck.cards.filter(\.isArchived).map(\.id))
    expectedSession.queue.removeAll { archived.contains($0) }
    expectedSession.total = expectedSession.completed + expectedSession.queue.count
    #expect(refreshed.session == expectedSession)
    #expect(refreshed.events.count == old.events.count)
    #expect(refreshed.contentVersions == old.contentVersions)
    #expect(refreshed.contentVersions?[contentID]?.card == oldDeck.cards[0])
    #expect(refreshed.deck.cards.first?.revision == (try currentDeck()).cards.first?.revision)
    #expect(refreshed.deck.cards.contains { $0.isArchived })
    try refreshed.validate()
}

@Test func bundledUpdatesKeepLocalEditsAtTheSameRevision() throws {
    let bundled = try currentDeck()
    var library = Library(deck: bundled)
    library.deck.cards[0].answer = "My edited answer"
    library.deck.cards[0].answerBlocks = nil
    library.deck.concepts[0].explanation = "My own explanation"
    let refreshed = try library.refreshingBundledContent(from: bundled)
    #expect(refreshed.deck.cards[0].answer == "My edited answer")
    #expect(refreshed.deck.concepts[0].explanation == "My own explanation")
}
