import Foundation

public enum CardSwipeDirection: String, CaseIterable, Sendable {
    case left, right, up, down

    public var grade: Grade {
        switch self {
        case .left: .again
        case .right: .good
        case .up: .easy
        case .down: .hard
        }
    }
}

/// Only a deliberate drag along one axis can commit an action. Velocity alone cannot grade a card.
public struct CardSwipeMachine {
    public enum Phase: Equatable, Sendable {
        case idle
        case dragging(x: Double, y: Double)
        case committing(CardSwipeDirection, UUID)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var readyDirection: CardSwipeDirection?
    public static let threshold = 96.0
    public init() {}

    public var canInteract: Bool { phase == .idle }

    public mutating func update(x: Double, y: Double, allowed: Set<CardSwipeDirection>) {
        if case .committing = phase { return }
        guard x.isFinite, y.isFinite else {
            cancel()
            return
        }
        phase = .dragging(x: x, y: y)
        let direction: CardSwipeDirection?
        if abs(x) >= Self.threshold, abs(x) > abs(y) * 1.3 {
            direction = x < 0 ? .left : .right
        } else if abs(y) >= Self.threshold, abs(y) > abs(x) * 1.3 {
            direction = y < 0 ? .up : .down
        } else {
            direction = nil
        }
        readyDirection = direction.flatMap { allowed.contains($0) ? $0 : nil }
    }

    public mutating func release(token: UUID, allowed: Set<CardSwipeDirection>) -> CardSwipeDirection? {
        guard case .dragging = phase else { return nil }
        guard let direction = readyDirection, allowed.contains(direction) else {
            cancel()
            return nil
        }
        phase = .committing(direction, token)
        readyDirection = nil
        return direction
    }

    /// An old completion must never trigger a second action or affect a later drag.
    @discardableResult
    public mutating func finish(token: UUID) -> Bool {
        guard case .committing(_, let expected) = phase, token == expected else { return false }
        phase = .idle
        return true
    }

    /// Leaving a screen invalidates even a released swipe; touch cancellation alone does not.
    public mutating func invalidate() {
        phase = .idle
        readyDirection = nil
    }

    public mutating func cancel() {
        guard case .committing = phase else {
            phase = .idle
            readyDirection = nil
            return
        }
    }
}
