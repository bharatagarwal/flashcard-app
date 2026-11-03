import Foundation
import Testing

@testable import RecallCore

private func starter() throws -> Deck {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    return try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Examples/math-foundations.json")))
}
private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Test func starterIsValidAndHasTheRequiredTopics() throws {
    let deck = try starter()
    try deck.validate()
    #expect(deck.cards.filter { !$0.isArchived }.count == 55)
    #expect(deck.concepts.count == 10)
    #expect(deck.concepts.allSatisfy { $0.sourceImage == nil })
    #expect(deck.concepts.allSatisfy { $0.sections?.isEmpty != false })
    #expect(deck.cards.contains { $0.id == "logs.fourth" && $0.answer.contains("x^4") })
}

@Test func ratingBeforeRevealAndDoubleRatingAreRejected() throws {
    var machine = ReviewMachine()
    machine.begin(session: ReviewSession(queue: ["a", "b"]))
    #expect(throws: RecallError.self) { try machine.beginSave(cardID: "a") }
    let turn = UUID()
    try machine.beginTurn(token: turn)
    machine.finishTurn(token: turn)
    #expect(throws: RecallError.self) { try machine.beginSave(cardID: "b") }
    try machine.beginSave(cardID: "a")
    #expect(throws: RecallError.self) { try machine.beginSave(cardID: "a") }
    try machine.saved(session: ReviewSession(queue: ["b"]))
    #expect(machine.phase == .question("b"))
    #expect(throws: RecallError.self) { try machine.beginSave(cardID: "a") }
}

@Test func failedSaveReturnsToAnswer() throws {
    var machine = ReviewMachine()
    machine.begin(session: ReviewSession(queue: ["a"]))
    let turn = UUID()
    try machine.beginTurn(token: turn)
    machine.finishTurn(token: turn)
    try machine.beginSave(cardID: "a")
    machine.saveFailed()
    #expect(machine.phase == .answer("a"))
}

@Test func fsrsGradesProduceRealSchedulesAndLogs() throws {
    let deck = try starter()
    let id = deck.cards[0].id
    let initial = Library(deck: deck)
    let again = try initial.preview(cardID: id, rating: .again, at: now)
    let easy = try initial.preview(cardID: id, rating: .easy, at: now)
    #expect(again.due > now)
    #expect(easy.due > again.due)
    #expect(easy.stability > again.stability)
    var library = initial
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: now)
    #expect(library.events.count == 1)
    #expect(library.schedules[id]?.reps == 1)
    #expect(library.session?.completed == 1)
    #expect(library.session?.queue.isEmpty == true)
    #expect(throws: RecallError.self) { try library.rate(cardID: id, rating: .good, at: now) }
    #expect(library.events.count == 1)
    try library.validate()
}

@Test func importsPreserveHistoryAndDoNotDeleteCards() throws {
    let deck = try starter()
    let id = deck.cards[0].id
    var library = Library(deck: deck)
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .easy, at: now)
    let schedule = library.schedules[id]
    var revised = deck
    revised.cards = [deck.cards[0]]
    revised.cards[0].answer += "\nUpdated explanation."
    revised.cards[0].answerBlocks = nil
    revised.cards[0].revision += 1
    revised.concepts[0].explanation += "\nMore detail."
    revised.concepts[0].revision = revised.concepts[0].effectiveRevision + 1
    let plan = try revised.plan(against: deck)
    #expect(plan.updated == 1)
    #expect(plan.added == 0)
    try library.merge(revised)
    #expect(library.deck.cards.count == deck.cards.count)
    #expect(library.schedules[id] == schedule)
    #expect(library.events.count == 1)
}

@Test func changedQuestionsAndDuplicateIDsAreRejected() throws {
    let deck = try starter()
    var changed = deck
    changed.cards[0].prompt = "A different question"
    changed.cards[0].change = .explanation
    changed.cards[0].revision += 1
    #expect(throws: RecallError.self) { try changed.plan(against: deck) }
    var duplicates = deck
    duplicates.cards.append(deck.cards[0])
    #expect(throws: RecallError.self) { try duplicates.validate() }
    var unknown = deck
    unknown.cards[0].conceptID = "missing"
    #expect(throws: RecallError.self) { try unknown.validate() }
}

@Test func staleAndUnversionedEditsAreRejected() throws {
    let deck = try starter()
    var changed = deck
    changed.cards[0].answer += " edit"
    #expect(throws: RecallError.self) { try changed.plan(against: deck) }
    changed.cards[0].revision = 0
    #expect(throws: RecallError.self) { try changed.validate() }
}

@Test func backupRoundTripRetainsReviewsAndSession() throws {
    let deck = try starter()
    var library = Library(deck: deck)
    library.session = ReviewSession(queue: Array(deck.cards.prefix(3).map(\.id)))
    try library.rate(cardID: deck.cards[0].id, rating: .good, at: now)
    let restored = try Codec.decode(Library.self, from: Codec.encode(library))
    try restored.validate()
    #expect(restored.deck == library.deck)
    #expect(restored.schedules == library.schedules)
    #expect(restored.session == library.session)
    #expect(restored.events.first?.log == library.events.first?.log)
    var machine = ReviewMachine()
    machine.begin(session: restored.session!)
    #expect(machine.phase == .question(deck.cards[1].id))
}

@Test func diskWritesAreAtomicAndBadFileIsKept() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DiskStore(url: folder.appendingPathComponent("library.json"))
    #expect(try store.load() == nil)
    let library = Library(deck: try starter())
    try store.save(library)
    #expect(try store.load()?.deck == library.deck)
    let broken = Data("not valid JSON".utf8)
    try broken.write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.url) == broken)
}

@Test func failedDiskSaveDoesNotChangeSavedLibrary() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DiskStore(url: folder.appendingPathComponent("library.json"))
    let good = Library(deck: try starter())
    try store.save(good)
    var bad = good
    bad.deck.schemaVersion = 999
    #expect(throws: RecallError.self) { try store.save(bad) }
    #expect(try store.load()?.deck == good.deck)
    let blocker = folder.appendingPathComponent("file-not-directory")
    try Data().write(to: blocker)
    let unwritable = DiskStore(url: blocker.appendingPathComponent("library.json"))
    #expect(throws: (any Error).self) { try unwritable.save(good) }
}

@Test func unknownBackupVersionAndInvalidSessionAreRejected() throws {
    var library = Library(deck: try starter())
    library.schemaVersion = 999
    #expect(throws: RecallError.self) { try library.validate() }
    library.schemaVersion = 1
    library.session = ReviewSession(queue: ["missing"])
    #expect(throws: RecallError.self) { try library.validate() }
}

@Test func newCardsAreDueButFutureCardsAreNot() throws {
    let deck = try starter()
    let id = deck.cards[0].id
    var library = Library(deck: deck)
    #expect(library.dueCards(at: now).count == deck.cards.filter { !$0.isArchived }.count)
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .easy, at: now)
    #expect(library.dueCards(at: now).count == deck.cards.filter { !$0.isArchived }.count - 1)
    #expect(
        library.dueCards(at: now.addingTimeInterval(86400 * 100)).count
            == deck.cards.filter { !$0.isArchived }.count)
}

@Test func repeatedLearningReviewAndForgettingSurviveReloads() throws {
    let deck = try starter()
    let id = deck.cards[0].id
    var library = Library(deck: deck)
    var instant = now
    let grades: [Grade] = [.again, .hard, .good, .good, .easy, .good, .again, .good, .good]
    for index in 0..<45 {
        library.session = ReviewSession(queue: [id])
        try library.rate(cardID: id, rating: grades[index % grades.count], at: instant)
        try library.validate()
        let scheduled = try #require(library.schedules[id])
        #expect(scheduled.reps == index + 1)
        #expect(scheduled.due > instant)
        #expect(scheduled.stability.isFinite && scheduled.stability > 0)
        library = try Codec.decode(Library.self, from: Codec.encode(library))
        try library.validate()
        instant = scheduled.due
    }
    #expect(library.events.count == 45)
    #expect((library.schedules[id]?.lapses ?? 0) > 0)
}

@Test func newNotationDeckImportsIntoAnOlderCollection() throws {
    let deck = try starter()
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let incoming = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("Examples/divisibility-and-logic.json"))
    )
    try incoming.validate()
    let older = Deck(
        title: deck.title,
        concepts: deck.concepts.filter { !["divisibility", "logic"].contains($0.id) },
        cards: deck.cards.filter { !["divisibility", "logic"].contains($0.conceptID) }, assets: deck.assets)
    var library = Library(deck: older)
    let id = older.cards[0].id
    library.session = ReviewSession(queue: [id])
    try library.rate(cardID: id, rating: .good, at: now)
    let previous = library.schedules[id]
    let plan = try incoming.plan(against: older)
    #expect(plan.added == incoming.cards.count)
    try library.merge(incoming)
    try library.validate()
    #expect(library.deck.cards.count == deck.cards.count)
    #expect(library.schedules[id] == previous)
    #expect(library.deck.cards.contains { $0.id == "divisibility.read" })
    #expect(try incoming.plan(against: library.deck).unchanged == incoming.cards.count)
}
