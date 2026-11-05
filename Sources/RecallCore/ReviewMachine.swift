import Foundation

public enum ReviewReadyFace: Equatable, Sendable {
    case question, answer, questionRevisited
}

public enum ReviewPhase: Equatable {
    case idle
    case question(String)
    case answer(String)
    case questionRevisited(String)
    case saving(String)
    case pausing(cardID: String, previousFace: ReviewReadyFace)
    case finished
    case turningToAnswer(cardID: String, token: UUID)
    case turningToQuestion(cardID: String, token: UUID)
}

public struct ReviewMachine {
    public private(set) var phase: ReviewPhase = .idle
    public private(set) var interactionID = UUID()
    public init() {}

    public var currentID: String? {
        switch phase {
        case .question(let id), .answer(let id), .questionRevisited(let id), .saving(let id),
            .turningToAnswer(let id, _), .turningToQuestion(let id, _), .pausing(let id, _):
            return id
        case .idle, .finished: return nil
        }
    }
    public var turnToken: UUID? {
        switch phase {
        case .turningToAnswer(_, let token), .turningToQuestion(_, let token): token
        default: nil
        }
    }
    public var showingBack: Bool {
        switch phase {
        case .turningToAnswer, .answer, .saving: return true
        case .pausing(_, let face): return face == .answer
        default: return false
        }
    }
    public var answerRevealed: Bool {
        switch phase {
        case .idle, .question, .finished: return false
        case .pausing(_, let face): return face != .question
        default: return true
        }
    }
    public var canTurn: Bool {
        switch phase {
        case .question, .answer, .questionRevisited: return true
        default: return false
        }
    }
    public var canPause: Bool { canTurn }
    public func acceptsPause(cardID: String, interactionID: UUID) -> Bool {
        canPause && currentID == cardID && self.interactionID == interactionID
    }
    public mutating func beginPause(cardID: String, interactionID: UUID) throws {
        guard acceptsPause(cardID: cardID, interactionID: interactionID) else {
            throw RecallError.invalidTransition
        }
        let face: ReviewReadyFace
        switch phase {
        case .question: face = .question
        case .answer: face = .answer
        case .questionRevisited: face = .questionRevisited
        default: throw RecallError.invalidTransition
        }
        phase = .pausing(cardID: cardID, previousFace: face)
        self.interactionID = UUID()
    }
    public var canGrade: Bool {
        if case .answer = phase { return true }
        return false
    }
    public func acceptsGrade(cardID: String, interactionID: UUID) -> Bool {
        phase == .answer(cardID) && self.interactionID == interactionID
    }
    public mutating func begin(session: ReviewSession) {
        switch phase {
        case .saving, .pausing: return
        default: break
        }
        phase = session.queue.first.map { .question($0) } ?? .finished
        interactionID = UUID()
    }
    public mutating func beginTurn(token: UUID) throws {
        switch phase {
        case .question(let id), .questionRevisited(let id): phase = .turningToAnswer(cardID: id, token: token)
        case .answer(let id): phase = .turningToQuestion(cardID: id, token: token)
        default: throw RecallError.invalidTransition
        }
        interactionID = UUID()
    }
    /// A callback from an old card or interrupted turn must not advance the review.
    public mutating func finishTurn(token: UUID) {
        switch phase {
        case .turningToAnswer(let id, let expected) where token == expected: phase = .answer(id)
        case .turningToQuestion(let id, let expected) where token == expected: phase = .questionRevisited(id)
        default: return
        }
        interactionID = UUID()
    }
    public mutating func beginSave(cardID: String) throws {
        guard phase == .answer(cardID) else { throw RecallError.invalidTransition }
        phase = .saving(cardID)
        interactionID = UUID()
    }
    public mutating func saved(session: ReviewSession) throws {
        switch phase {
        case .saving, .pausing: break
        default: throw RecallError.invalidTransition
        }
        phase = session.queue.first.map { .question($0) } ?? .finished
        interactionID = UUID()
    }
    public mutating func saveFailed() {
        switch phase {
        case .saving(let id): phase = .answer(id)
        case .pausing(let id, let face):
            switch face {
            case .question: phase = .question(id)
            case .answer: phase = .answer(id)
            case .questionRevisited: phase = .questionRevisited(id)
            }
        default: return
        }
        interactionID = UUID()
    }
}

public struct DiskStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Library? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let library = try Codec.decode(Library.self, from: Data(contentsOf: url))
        try library.validate()
        return library
    }
    public func save(_ library: Library) throws {
        try library.validate()
        let data = try Codec.encode(library)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
