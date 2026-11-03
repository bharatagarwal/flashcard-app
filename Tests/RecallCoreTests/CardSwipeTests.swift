import Foundation
import Testing

@testable import RecallCore

@Test func shortAndDiagonalDragsNeverCommitGrades() {
    var machine = CardSwipeMachine()
    let all = Set(CardSwipeDirection.allCases)
    for (x, y) in [(95.0, 0.0), (0, -95), (130, 125), (-140, -140), (0, 0)] {
        machine.update(x: x, y: y, allowed: all)
        #expect(machine.readyDirection == nil)
        #expect(machine.release(token: UUID(), allowed: all) == nil)
        #expect(machine.canInteract)
    }
}

@Test func eachDirectionRequiresDistanceAndCanCommitOnlyOnce() {
    let all = Set(CardSwipeDirection.allCases)
    let drags: [(Double, Double, CardSwipeDirection)] = [
        (-120, 10, .left), (120, -10, .right), (10, -120, .up), (-10, 120, .down),
    ]
    for (x, y, direction) in drags {
        var machine = CardSwipeMachine()
        let token = UUID()
        machine.update(x: x, y: y, allowed: all)
        #expect(machine.readyDirection == direction)
        #expect(!machine.canInteract)
        #expect(machine.release(token: token, allowed: all) == direction)
        machine.update(x: -x, y: -y, allowed: all)
        #expect(machine.phase == .committing(direction, token))
        #expect(machine.release(token: UUID(), allowed: all) == nil)
        let staleFinished = machine.finish(token: UUID())
        #expect(!staleFinished)
        // Cancelling a touch must not cancel an action that already committed.
        machine.cancel()
        let finished = machine.finish(token: token)
        #expect(finished)
        let twiceFinished = machine.finish(token: token)
        #expect(!twiceFinished)
        #expect(machine.canInteract)
    }
}

@Test func blockedDirectionsAndChangedEligibilityCannotCommit() {
    var machine = CardSwipeMachine()
    let horizontal: Set<CardSwipeDirection> = [.left, .right]
    machine.update(x: 0, y: -200, allowed: horizontal)
    #expect(machine.readyDirection == nil)
    #expect(machine.release(token: UUID(), allowed: horizontal) == nil)
    machine.update(x: 200, y: 0, allowed: horizontal)
    #expect(machine.readyDirection == .right)
    #expect(machine.release(token: UUID(), allowed: []) == nil)
    #expect(machine.canInteract)
}

@Test func draggingBackUnderThresholdAndInterruptionsLeaveNoPendingAction() {
    var machine = CardSwipeMachine()
    let all = Set(CardSwipeDirection.allCases)
    machine.update(x: 150, y: 0, allowed: all)
    machine.update(x: 15, y: 0, allowed: all)
    #expect(machine.readyDirection == nil)
    machine.cancel()
    #expect(machine.canInteract)
    #expect(machine.release(token: UUID(), allowed: all) == nil)
    for value in [Double.nan, .infinity, -.infinity] {
        machine.update(x: value, y: 100, allowed: all)
        #expect(machine.canInteract)
    }
}

@Test func swipeRatingsMatchTheirLabelsAndStillRequireARevealedAnswer() throws {
    #expect(CardSwipeDirection.left.grade == .again)
    #expect(CardSwipeDirection.down.grade == .hard)
    #expect(CardSwipeDirection.right.grade == .good)
    #expect(CardSwipeDirection.up.grade == .easy)
    var review = ReviewMachine()
    review.begin(session: ReviewSession(queue: ["a", "b"]))
    #expect(!review.canGrade)
    #expect(throws: RecallError.self) { try review.beginSave(cardID: "a") }
    let turn = UUID()
    try review.beginTurn(token: turn)
    #expect(!review.canGrade)
    review.finishTurn(token: turn)
    try review.beginSave(cardID: "a")
    #expect(!review.canGrade)
    try review.saved(session: ReviewSession(queue: ["b"]))
    #expect(!review.canGrade)
    #expect(throws: RecallError.self) { try review.beginSave(cardID: "a") }
}

@Test func leavingAScreenInvalidatesEvenAReleasedSwipe() {
    var swipe = CardSwipeMachine()
    let token = UUID()
    swipe.update(x: 150, y: 0, allowed: [.right])
    let released = swipe.release(token: token, allowed: [.right])
    #expect(released == .right)
    swipe.invalidate()
    let completed = swipe.finish(token: token)
    #expect(!completed)
    #expect(swipe.canInteract)
}
