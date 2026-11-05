import Foundation
import Testing

@testable import RecallCore

private func queryLibrary() throws -> Library {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let deck = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/starter.json")))
    return Library(deck: deck)
}

@Test func libraryLayoutsShareOrderedSearchAndUnderstandingResults() throws {
    var library = try queryLibrary()
    let id = "sets.idempotent-origin"
    try library.setUnderstanding(.needsUnderstanding, cardID: id)
    let query = LibraryQuery(needsUnderstandingOnly: true, search: "IDEMPOTENT")
    let groups = library.groups(matching: query)
    #expect(groups.flatMap { $0.cards.map(\.id) } == [id])
    #expect(groups.first?.concept.id == "sets")
    #expect(library.groups(matching: LibraryQuery(search: "Idem:")).flatMap { $0.cards.map(\.id) } == [id])
    let all = library.groups(matching: LibraryQuery())
    #expect(all.map(\.id) == library.deck.concepts.map(\.id))
    for group in all {
        #expect(
            group.cards.map(\.id)
                == library.deck.cards.filter { !$0.isArchived && $0.conceptID == group.id }.map(\.id))
    }
    try library.setUnderstanding(.understood, cardID: id)
    #expect(library.groups(matching: query).isEmpty)
    #expect(
        library.groups(matching: LibraryQuery(search: "IDEMPOTENT")).flatMap { $0.cards.map(\.id) } == [id])
}

@Test func libraryArchiveAndUnderstandingScopesStayIndependentAcrossLayouts() throws {
    var library = try queryLibrary()
    let id = "sets.idempotent-origin"
    try library.setUnderstanding(.needsUnderstanding, cardID: id)
    try library.setArchived(cardID: id, archived: true)
    #expect(library.groups(matching: LibraryQuery(needsUnderstandingOnly: true)).isEmpty)
    let archived = LibraryQuery(archived: true, needsUnderstandingOnly: true)
    #expect(library.groups(matching: archived).flatMap { $0.cards.map(\.id) } == [id])
    try library.setArchived(cardID: id, archived: false)
    #expect(library.groups(matching: archived).isEmpty)
    #expect(
        library.groups(matching: LibraryQuery(needsUnderstandingOnly: true)).flatMap { $0.cards.map(\.id) }
            == [id])
}
