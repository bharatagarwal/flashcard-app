import Foundation
import Testing

@testable import RecallCore

@Test func returningToTheSameCardDoesNotAcceptAnOldSwipe() {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a", "b"])
    let oldVisit = browser.visitID
    browser.move(by: 1)
    browser.move(by: -1)
    #expect(browser.currentID == "a")
    #expect(!browser.accepts(visitID: oldVisit))
    #expect(browser.accepts(visitID: browser.visitID))
}

@Test func browseSheetsAreExclusiveAndBlockNavigation() {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a", "b"])
    let beforeSheet = browser.visitID
    browser.showHistory()
    #expect(browser.sheet == .history("a"))
    #expect(!browser.canGoForward)
    #expect(!browser.accepts(visitID: beforeSheet))
    browser.edit()
    browser.move(by: 1)
    #expect(browser.sheet == .history("a"))
    #expect(browser.currentID == "a")
    browser.dismissSheet()
    #expect(browser.phase == .browsing)
    #expect(!browser.accepts(visitID: beforeSheet))
    browser.edit()
    browser.showHistory()
    #expect(browser.sheet == .edit("a"))
}

@Test func closingTheBrowserInvalidatesSwipesAndLateSheetDismissals() {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a", "b"])
    let visit = browser.visitID
    browser.edit()
    browser.close()
    browser.dismissSheet()
    browser.move(by: 1)
    browser.showHistory()
    #expect(browser.phase == .closed)
    #expect(browser.currentID == "a")
    #expect(!browser.accepts(visitID: visit))
    #expect(browser.sheet == nil)
}

@Test func invalidBrowseStepsLeaveTheCurrentVisitUntouched() {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a", "a", "b"])
    #expect(browser.cardIDs == ["a", "b"])
    let first = browser.visitID
    browser.move(by: -1)
    browser.move(by: Int.max)
    #expect(browser.visitID == first)
    browser.move(by: 1)
    let last = browser.visitID
    browser.move(by: 1)
    #expect(browser.currentID == "b")
    #expect(browser.visitID == last)
    let fallback = BrowseMachine(cardID: "a", cardIDs: [])
    #expect(fallback.currentID == "a")
    #expect(!fallback.canGoBack)
    #expect(!fallback.canGoForward)
}

@Test func browsingFlipBlocksSheetsAndNavigationUntilItFinishes() throws {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a", "b"])
    let visit = browser.visitID
    let token = UUID()
    try browser.beginTurn(token: token)
    #expect(browser.face.showingBack)
    #expect(browser.face.turnToken == token)
    #expect(!browser.canTurn)
    #expect(!browser.canGoForward)
    #expect(!browser.accepts(visitID: visit))
    browser.showHistory()
    browser.edit()
    browser.move(by: 1)
    #expect(browser.phase == .browsing)
    #expect(browser.currentID == "a")
    browser.finishTurn(token: UUID())
    #expect(!browser.canTurn)
    browser.finishTurn(token: token)
    #expect(browser.face.turnToken == nil)
    #expect(browser.canTurn)
    #expect(browser.face.showingBack)
    browser.move(by: 1)
    #expect(browser.currentID == "b")
    #expect(!browser.face.showingBack)
    browser.finishTurn(token: token)
    #expect(!browser.face.showingBack)
}

@Test func closingDuringABrowseFlipCannotBeReopenedByItsCompletion() throws {
    var browser = BrowseMachine(cardID: "a", cardIDs: ["a"])
    let token = UUID()
    try browser.beginTurn(token: token)
    browser.close()
    browser.finishTurn(token: token)
    #expect(browser.phase == .closed)
    #expect(!browser.canTurn)
}
