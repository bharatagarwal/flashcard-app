import Foundation

public enum BrowseSheet: Equatable, Identifiable, Sendable {
    case edit(String)
    case history(String)

    public var id: String {
        switch self {
        case .edit(let cardID): "edit:" + cardID
        case .history(let cardID): "history:" + cardID
        }
    }
}

/// Selection, sheets and delayed actions share one visit identity, even when returning to the same card.
public struct BrowseMachine {
    public enum Phase: Equatable, Sendable {
        case browsing
        case sheet(BrowseSheet)
        case closed
    }
    public let cardIDs: [String]
    public private(set) var index: Int
    public private(set) var phase: Phase = .browsing
    public private(set) var visitID = UUID()
    public private(set) var lastStep = 1
    public private(set) var face = ReviewMachine()

    public init(cardID: String, cardIDs: [String]) {
        var seen = Set<String>()
        let unique = cardIDs.filter { seen.insert($0).inserted }
        self.cardIDs = unique.contains(cardID) ? unique : [cardID]
        index = self.cardIDs.firstIndex(of: cardID) ?? 0
        face.begin(session: ReviewSession(queue: [cardID]))
    }
    public var currentID: String { cardIDs[index] }
    public var canGoBack: Bool { canTurn && index > 0 }
    public var canGoForward: Bool { canTurn && index + 1 < cardIDs.count }
    public var sheet: BrowseSheet? {
        if case .sheet(let value) = phase { return value }
        return nil
    }
    public var canTurn: Bool { phase == .browsing && face.canTurn }
    public func accepts(visitID: UUID) -> Bool { canTurn && self.visitID == visitID }

    public mutating func beginTurn(token: UUID) throws {
        guard canTurn else { throw RecallError.invalidTransition }
        try face.beginTurn(token: token)
        visitID = UUID()
    }
    public mutating func finishTurn(token: UUID) {
        guard phase == .browsing else { return }
        let old = face.interactionID
        face.finishTurn(token: token)
        if old != face.interactionID { visitID = UUID() }
    }

    public mutating func move(by step: Int) {
        guard canTurn, step == -1 || step == 1 else { return }
        let next = index + step
        guard cardIDs.indices.contains(next) else { return }
        lastStep = step
        index = next
        face.begin(session: ReviewSession(queue: [currentID]))
        visitID = UUID()
    }
    public mutating func showHistory() { present(.history(currentID)) }
    public mutating func edit() { present(.edit(currentID)) }
    private mutating func present(_ sheet: BrowseSheet) {
        guard canTurn else { return }
        phase = .sheet(sheet)
        visitID = UUID()
    }
    public mutating func dismissSheet() {
        guard case .sheet = phase else { return }
        phase = .browsing
        visitID = UUID()
    }
    public mutating func close() {
        phase = .closed
        visitID = UUID()
    }
}
