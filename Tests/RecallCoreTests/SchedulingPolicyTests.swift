import FSRS
import Foundation
import Testing

@testable import RecallCore

private let schedulingNow = Date(timeIntervalSince1970: 1_800_000_000)
private let schedulingGrades: [Rating] = [.again, .hard, .good, .easy]

private func schedulingLibrary() throws -> Library {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    return Library(
        deck: try Codec.decode(
            Deck.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/starter.json"))))
}

private func scheduler(learning: [String], relearning: [String]) -> FSRS {
    FSRS(
        parameters: .init(
            requestRetention: 0.9, w: FSRSDefaults.defaultWv6, enableFuzz: false, enableShortTerm: true,
            learningSteps: learning, relearningSteps: relearning))
}

@Test func allFourRatingsUseModelIntervalsWithoutFixedSteps() throws {
    let library = try schedulingLibrary()
    let card = try #require(library.deck.cards.first { !$0.isArchived })
    #expect(library.schedulerSettings.learningSteps.isEmpty)
    #expect(library.schedulerSettings.relearningSteps.isEmpty)
    #expect(library.schedulerSettings.enableShortTerm)
    let reference = scheduler(learning: [], relearning: [])
    let initial = Card(due: schedulingNow)
    for grade in schedulingGrades {
        let actual = try library.preview(cardID: card.id, rating: grade, at: schedulingNow)
        let expected = try reference.next(card: initial, now: schedulingNow, grade: grade).card
        #expect(actual == expected)
        #expect(actual.due.timeIntervalSince(schedulingNow) >= 86400)
        #expect(actual.learningSteps == 0)
    }
    let again = try library.preview(cardID: card.id, rating: .again, at: schedulingNow)
    let easy = try library.preview(cardID: card.id, rating: .easy, at: schedulingNow)
    #expect(easy.stability > again.stability)
    #expect(easy.due > again.due)
}

@Test func oldLearningAndRelearningStatesUseTheModelOnTheirNextRating() throws {
    var library = try schedulingLibrary()
    let card = try #require(library.deck.cards.first { !$0.isArchived })
    let legacy = scheduler(learning: ["1m", "10m"], relearning: ["10m"])
    let initial = Card(due: schedulingNow)
    let learning = try legacy.next(card: initial, now: schedulingNow, grade: .good).card
    let learned = try legacy.next(card: initial, now: schedulingNow, grade: .easy).card
    let relearning = try legacy.next(card: learned, now: learned.due, grade: .again).card
    #expect(learning.state == .learning)
    #expect(learning.learningSteps == 1)
    #expect(relearning.state == .relearning)
    let reference = scheduler(learning: [], relearning: [])
    for old in [learning, relearning] {
        library.schedules[card.id] = old
        let at = old.due
        for grade in schedulingGrades {
            let actual = try library.preview(cardID: card.id, rating: grade, at: at)
            let expected = try reference.next(card: old, now: at, grade: grade).card
            #expect(actual == expected)
            #expect(actual.due.timeIntervalSince(at) >= 86400)
            #expect(actual.learningSteps == 0)
        }
        #expect(library.schedules[card.id] == old)
    }
}

@Test func schedulerChangePreservesOldDueDatesAndHistoricalSettings() throws {
    var library = try schedulingLibrary()
    let card = try #require(library.deck.cards.first { !$0.isArchived })
    let concept = try #require(library.deck.concepts.first { $0.id == card.conceptID })
    var oldSettings = library.schedulerSettings
    oldSettings.learningSteps = ["1m", "10m"]
    oldSettings.relearningSteps = ["10m"]
    let oldScheduler = scheduler(learning: oldSettings.learningSteps, relearning: oldSettings.relearningSteps)
    let initial = Card(due: schedulingNow)
    let result = try oldScheduler.next(card: initial, now: schedulingNow, grade: .good)
    let content = ReviewContent(card: card, concept: concept, scheduler: oldSettings)
    let hash = try content.digest
    library.schedules[card.id] = result.card
    library.contentVersions = [hash: content]
    library.events = [
        .init(
            id: UUID(), cardID: card.id, revision: card.revision,
            log: result.log, before: initial, after: result.card, contentID: hash)
    ]
    library.session = ReviewSession(queue: [card.id])
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = DatabaseStore(url: folder.appendingPathComponent("library.sqlite"))
    try store.save(library)
    let saved = try store.load()
    var loaded = try #require(saved)
    #expect(loaded.schedules == library.schedules)
    #expect(loaded.events.map(\.id) == library.events.map(\.id))
    #expect(loaded.contentVersions == library.contentVersions)
    #expect(result.card.due.timeIntervalSince(schedulingNow) == 600)
    try loaded.rate(cardID: card.id, rating: .again, at: result.card.due)
    let next = try #require(loaded.schedules[card.id])
    #expect(next.due.timeIntervalSince(result.card.due) >= 86400)
    #expect(loaded.events.count == 2)
    #expect(loaded.contentVersions?[hash]?.scheduler.learningSteps == ["1m", "10m"])
    let newHash = try #require(loaded.events.last?.contentID)
    #expect(loaded.contentVersions?[newHash]?.scheduler.learningSteps == [])
    #expect(loaded.contentVersions?[newHash]?.scheduler.relearningSteps == [])
    try loaded.validate()
}
