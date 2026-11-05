import CSQLite
import Foundation
import Testing

@testable import RecallCore

private func understandingDeck() throws -> Deck {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    return try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/starter.json")))
}

@Test func pausingUnderstandingKeepsContentMemoryAndCompletedReviews() throws {
    var library = Library(deck: try understandingDeck())
    let ids = ["derivatives.sin", "derivatives.cos", "angles.sin"]
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    library.session = ReviewSession(queue: ids)
    try library.rate(cardID: ids[0], rating: .good, at: now)
    let schedules = library.schedules
    let eventIDs = library.events.map(\.id)
    let snapshots = library.contentVersions
    let deck = library.deck
    // Pause a studied card and a new card; neither operation is a memory review.
    try library.setUnderstanding(.needsUnderstanding, cardID: ids[0])
    try library.setUnderstanding(.needsUnderstanding, cardID: ids[1])
    #expect(library.session?.queue == [ids[2]])
    #expect(library.session?.completed == 1)
    #expect(library.session?.total == 2)
    #expect(library.needsUnderstandingCount == 2)
    #expect(library.schedules == schedules)
    #expect(library.events.map(\.id) == eventIDs)
    #expect(library.contentVersions == snapshots)
    #expect(library.deck == deck)
    #expect(
        !library.dueCards(at: now.addingTimeInterval(86400 * 365)).contains { ids.prefix(2).contains($0.id) })
    #expect(library.nextReviewDate == nil)
    // Core grading rejects a paused card even if a stale caller supplies it in a queue.
    library.session = ReviewSession(queue: [ids[0]])
    #expect(throws: RecallError.self) { try library.rate(cardID: ids[0], rating: .again, at: now) }
    try library.setUnderstanding(.understood, cardID: ids[0])
    #expect(library.nextReviewDate == schedules[ids[0]]?.due)
    #expect(library.schedules == schedules)
}

@Test func understandingAndArchivingRemainIndependentAndDoNotInsertIntoRunningSessions() throws {
    var library = Library(deck: try understandingDeck())
    let id = "derivatives.sin"
    library.session = ReviewSession(queue: [id, "derivatives.cos"])
    try library.setUnderstanding(.needsUnderstanding, cardID: id)
    try library.setArchived(cardID: id, archived: true)
    try library.setArchived(cardID: id, archived: false)
    #expect(library.needsUnderstanding(id))
    #expect(!library.dueCards(at: Date()).contains { $0.id == id })
    try library.setUnderstanding(.understood, cardID: id)
    #expect(library.dueCards(at: Date()).contains { $0.id == id })
    #expect(library.session?.queue == ["derivatives.cos"])
    try library.setArchived(cardID: id, archived: true)
    #expect(!library.dueCards(at: Date()).contains { $0.id == id })
    #expect(library.understanding?[id] == .understood)
}

@Test func understandingSurvivesSQLiteBackupRestoreAndContentUpdates() throws {
    let deck = try understandingDeck()
    var library = Library(deck: deck)
    let id = "derivatives.sin"
    try library.setUnderstanding(.needsUnderstanding, cardID: id)
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DatabaseStore(url: folder.appendingPathComponent("library.sqlite"))
    try store.save(library)
    let read = try store.load()
    var saved = try #require(read)
    #expect(saved.understanding == library.understanding)
    let backup = try Codec.decode(Library.self, from: Codec.encode(saved))
    try store.replace(with: backup)
    let restored = try store.load()
    #expect(restored?.understanding == library.understanding)
    var update = deck
    let index = try #require(update.cards.firstIndex { $0.id == id })
    update.cards[index].revision += 1
    update.cards[index].answer += " "
    update.cards[index].change = .explanation
    saved = try saved.refreshingBundledContent(from: update)
    try saved.merge(update)
    #expect(saved.needsUnderstanding(id))
    #expect(saved.deck.cards[index].revision == update.cards[index].revision)
    #expect(!saved.dueCards(at: Date()).contains { $0.id == id })
}

@Test func unmarkedLibrariesKeepTheirLegacyWireShapeAndUnknownMarksAreRejected() throws {
    var library = Library(deck: try understandingDeck())
    let encoded = try Codec.encode(library)
    let json = try #require(String(data: encoded, encoding: .utf8))
    #expect(!json.contains("\"understanding\""))
    let legacy = try Codec.decode(Library.self, from: encoded)
    #expect(legacy.understanding == nil)
    #expect(throws: RecallError.self) { try library.setUnderstanding(.needsUnderstanding, cardID: "missing") }
    library.understanding = ["missing": .needsUnderstanding]
    #expect(throws: RecallError.self) { try library.validate() }
}

@Test func failedUnderstandingCommitRollsBackTheMarkAndQueueTogether() throws {
    var library = Library(deck: try understandingDeck())
    library.session = ReviewSession(queue: ["derivatives.sin", "derivatives.cos"])
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DatabaseStore(url: folder.appendingPathComponent("library.sqlite"))
    try store.save(library)
    var handle: OpaquePointer?
    #expect(sqlite3_open(store.url.path, &handle) == SQLITE_OK)
    let db = try #require(handle)
    defer { sqlite3_close(db) }
    #expect(
        sqlite3_exec(
            db,
            "CREATE TRIGGER reject_mark BEFORE UPDATE ON metadata BEGIN SELECT RAISE(ABORT,'test failure'); END;",
            nil, nil, nil) == SQLITE_OK)
    var candidate = library
    try candidate.setUnderstanding(.needsUnderstanding, cardID: "derivatives.sin")
    #expect(throws: RecallError.self) { try store.save(candidate) }
    let restored = try store.load()
    #expect(restored?.understanding == nil)
    #expect(restored?.session == library.session)
}

@Test func pausingReviewRejectsStaleEventsAndRestoresEachFaceAfterSaveFailure() throws {
    for face in [ReviewReadyFace.question, .answer, .questionRevisited] {
        var machine = ReviewMachine()
        machine.begin(session: ReviewSession(queue: ["a", "b"]))
        if face != .question {
            let token = UUID()
            try machine.beginTurn(token: token)
            #expect(!machine.canPause)
            #expect(throws: RecallError.self) {
                try machine.beginPause(cardID: "a", interactionID: machine.interactionID)
            }
            machine.finishTurn(token: token)
        }
        if face == .questionRevisited {
            let token = UUID()
            try machine.beginTurn(token: token)
            machine.finishTurn(token: token)
        }
        let before = machine.phase
        let oldInteraction = machine.interactionID
        try machine.beginPause(cardID: "a", interactionID: oldInteraction)
        #expect(!machine.canGrade && !machine.canTurn && !machine.canPause)
        #expect(throws: RecallError.self) { try machine.beginSave(cardID: "a") }
        #expect(machine.phase == .pausing(cardID: "a", previousFace: face))
        #expect(machine.showingBack == (face == .answer))
        #expect(throws: RecallError.self) {
            try machine.beginPause(cardID: "a", interactionID: oldInteraction)
        }
        machine.saveFailed()
        #expect(machine.phase == before)
        #expect(!machine.acceptsPause(cardID: "a", interactionID: oldInteraction))
        try machine.beginPause(cardID: "a", interactionID: machine.interactionID)
        try machine.saved(session: ReviewSession(queue: ["b"]))
        #expect(machine.phase == .question("b"))
        machine.begin(session: ReviewSession(queue: ["a"]))
        #expect(!machine.acceptsPause(cardID: "a", interactionID: oldInteraction))
    }
}

@Test func browsingUnderstandingChangesInvalidateSwipesWithoutGradingOrReopeningClosedViews() throws {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a", "b"])
    let turn = UUID()
    try browser.beginTurn(token: turn)
    browser.finishTurn(token: turn)
    let oldVisit = browser.visitID
    try browser.beginUnderstandingChange(visitID: oldVisit)
    browser.move(by: 1)
    browser.edit()
    #expect(browser.currentID == "a")
    #expect(browser.sheet == nil)
    #expect(!browser.accepts(visitID: oldVisit))
    browser.finishUnderstandingChange()
    #expect(browser.face.showingBack)
    #expect(browser.canTurn)
    #expect(throws: RecallError.self) { try browser.beginUnderstandingChange(visitID: oldVisit) }
    try browser.beginUnderstandingChange(visitID: browser.visitID)
    browser.close()
    browser.finishUnderstandingChange()
    #expect(browser.phase == .closed)
}
