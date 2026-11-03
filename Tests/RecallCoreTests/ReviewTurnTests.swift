import Foundation
import Testing

@testable import RecallCore

@Test func turningBlocksTapsAndGradesUntilTheAnswerIsVisible() throws {
    var machine = ReviewMachine()
    machine.begin(session: ReviewSession(queue: ["a"]))
    let token = UUID()
    try machine.beginTurn(token: token)
    #expect(machine.currentID == "a")
    #expect(machine.showingBack)
    #expect(!machine.canTurn)
    #expect(!machine.canGrade)
    #expect(throws: RecallError.self) { try machine.beginTurn(token: UUID()) }
    #expect(throws: RecallError.self) { try machine.beginSave(cardID: "a") }
    machine.finishTurn(token: token)
    #expect(machine.phase == .answer("a"))
    #expect(machine.canGrade)
}

@Test func turningBackKeepsTheAnswerRevealedButRequiresTheBackForGrading() throws {
    var machine = ReviewMachine()
    machine.begin(session: ReviewSession(queue: ["a"]))
    let reveal = UUID()
    let back = UUID()
    let again = UUID()
    try machine.beginTurn(token: reveal)
    machine.finishTurn(token: reveal)
    try machine.beginTurn(token: back)
    #expect(!machine.showingBack)
    #expect(!machine.canGrade)
    machine.finishTurn(token: back)
    #expect(machine.phase == .questionRevisited("a"))
    #expect(machine.answerRevealed)
    #expect(throws: RecallError.self) { try machine.beginSave(cardID: "a") }
    try machine.beginTurn(token: again)
    machine.finishTurn(token: again)
    #expect(machine.canGrade)
}

@Test func staleAnimationCallbacksCannotRevealAnotherCardOrFinishAnotherTurn() throws {
    var machine = ReviewMachine()
    machine.begin(session: ReviewSession(queue: ["a"]))
    let old = UUID()
    let current = UUID()
    try machine.beginTurn(token: old)
    machine.begin(session: ReviewSession(queue: ["b"]))
    machine.finishTurn(token: old)
    #expect(machine.phase == .question("b"))
    try machine.beginTurn(token: current)
    machine.finishTurn(token: old)
    #expect(machine.phase == .turningToAnswer(cardID: "b", token: current))
    machine.finishTurn(token: current)
    try machine.beginSave(cardID: "b")
    machine.finishTurn(token: current)
    #expect(machine.phase == .saving("b"))
    machine.begin(session: ReviewSession(queue: ["a"]))
    #expect(machine.phase == .saving("b"))
    machine.saveFailed()
    #expect(machine.phase == .answer("b"))
    try machine.beginSave(cardID: "b")
    try machine.saved(session: ReviewSession(queue: []))
    machine.finishTurn(token: old)
    #expect(machine.phase == .finished)
    #expect(throws: RecallError.self) { try machine.beginTurn(token: UUID()) }
}

@Test func oldSwipeCannotGradeAfterReturningToTheSameAnswer() throws {
    var review = ReviewMachine()
    review.begin(session: ReviewSession(queue: ["a"]))
    let reveal = UUID()
    try review.beginTurn(token: reveal)
    review.finishTurn(token: reveal)
    let oldInteraction = review.interactionID
    #expect(review.acceptsGrade(cardID: "a", interactionID: oldInteraction))
    let hide = UUID()
    try review.beginTurn(token: hide)
    review.finishTurn(token: hide)
    let again = UUID()
    try review.beginTurn(token: again)
    review.finishTurn(token: again)
    #expect(review.canGrade)
    #expect(!review.acceptsGrade(cardID: "a", interactionID: oldInteraction))
    #expect(review.acceptsGrade(cardID: "a", interactionID: review.interactionID))
    let beforeSave = review.interactionID
    try review.beginSave(cardID: "a")
    review.saveFailed()
    #expect(!review.acceptsGrade(cardID: "a", interactionID: beforeSave))
    #expect(review.acceptsGrade(cardID: "a", interactionID: review.interactionID))
}
