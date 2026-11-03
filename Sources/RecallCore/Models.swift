import FSRS
import Foundation

public struct Concept: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var explanation: String
    public var pitfall: String
    public var diagram: String?
    public var sourceImage: String?
    public var sources: [String]
    public var revision: Int?
    public var sections: [LessonSection]?
    public var prerequisiteIDs: [String]?
    public var effectiveRevision: Int { revision ?? 1 }
}

public struct Flashcard: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var conceptID: String
    public var revision: Int
    public var kind: String
    public var prompt: String
    public var answer: String
    public var hint: String
    public var objectiveID: String?
    public var change: CardChange?
    public var answerBlocks: [LessonBlock]?
    public var explanationSections: [LessonSection]?
    public var archived: Bool?
    public var isArchived: Bool { archived == true }
    public var effectiveObjective: String { objectiveID ?? id }
}

public struct Deck: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var title: String
    public var concepts: [Concept]
    public var cards: [Flashcard]
    public var assets: [DiagramAsset]?
    public init(
        schemaVersion: Int = 2, title: String, concepts: [Concept], cards: [Flashcard],
        assets: [DiagramAsset]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.title = title
        self.concepts = concepts
        self.cards = cards
        self.assets = assets
    }
}

public struct ReviewEvent: Codable, Identifiable, Sendable {
    public var id: UUID
    public var cardID: String
    public var revision: Int
    public var log: ReviewLog
    public var before: Card
    public var after: Card
    public var contentID: String?
}

public struct ReviewSession: Codable, Equatable, Sendable {
    public var queue: [String]
    public var completed: Int = 0
    public var total: Int
    public init(queue: [String]) {
        self.queue = queue
        total = queue.count
    }
}

public struct Library: Codable, Sendable {
    public var schemaVersion = 2
    public var deck: Deck
    public var schedules: [String: Card] = [:]
    public var events: [ReviewEvent] = []
    public var session: ReviewSession?
    public var contentVersions: [String: ReviewContent]?
    public init(deck: Deck) { self.deck = deck }
    public func dueCards(at now: Date) -> [Flashcard] {
        deck.cards.filter { !$0.isArchived && (schedules[$0.id]?.due ?? .distantPast) <= now }
            .sorted {
                let a = schedules[$0.id]
                let b = schedules[$1.id]
                if (a == nil) != (b == nil) { return a != nil }
                if a?.due != b?.due { return (a?.due ?? .distantPast) < (b?.due ?? .distantPast) }
                return $0.id < $1.id
            }
    }
    /// Retire cards from a pending queue without deleting their schedules or past reviews.
    public mutating func removeArchivedCardsFromSession() {
        guard var pending = session else { return }
        let active = Set(deck.cards.filter { !$0.isArchived }.map(\.id))
        pending.queue.removeAll { !active.contains($0) }
        pending.total = pending.completed + pending.queue.count
        session = pending
    }
    public var nextReviewDate: Date? {
        let active = Set(deck.cards.filter { !$0.isArchived }.map(\.id))
        return schedules.filter { active.contains($0.key) }.values.map(\.due).min()
    }
    public var schedulerSettings: SchedulerSettings {
        .init(
            algorithm: "FSRS-6", implementation: "swift-fsrs@4fbaf20184d62f82a9f44f343337c61a2c5483e9",
            retention: 0.9, weights: FSRSDefaults.defaultWv6,
            learningSteps: FSRSDefaults.defaultLearningSteps,
            relearningSteps: FSRSDefaults.defaultRelearningSteps)
    }
    public var scheduler: FSRS {
        let settings = schedulerSettings
        return FSRS(
            parameters: .init(
                requestRetention: settings.retention, maximumInterval: settings.maximumInterval,
                w: settings.weights,
                enableFuzz: settings.enableFuzz, enableShortTerm: settings.enableShortTerm,
                learningSteps: settings.learningSteps, relearningSteps: settings.relearningSteps))
    }
    public func preview(cardID: String, rating: Rating, at now: Date) throws -> Card {
        try scheduler.next(card: schedules[cardID] ?? Card(due: now), now: now, grade: rating).card
    }
    public mutating func rate(cardID: String, rating: Rating, at now: Date) throws {
        guard let card = deck.cards.first(where: { $0.id == cardID }),
            !card.isArchived, session?.queue.first == cardID
        else { throw RecallError.invalidTransition }
        guard let concept = deck.concepts.first(where: { $0.id == card.conceptID }) else {
            throw RecallError.invalidTransition
        }
        let content = ReviewContent(card: card, concept: concept, scheduler: schedulerSettings)
        let contentID = try content.digest
        let before = schedules[cardID] ?? Card(due: now)
        let result = try scheduler.next(card: before, now: now, grade: rating)
        if contentVersions == nil { contentVersions = [:] }
        contentVersions?[contentID] = content
        schedules[cardID] = result.card
        events.append(
            .init(
                id: UUID(), cardID: cardID, revision: card.revision,
                log: result.log, before: before, after: result.card, contentID: contentID))
        session?.queue.removeFirst()
        session?.completed += 1
    }
}

public enum RecallError: LocalizedError {
    case invalid(String)
    case invalidTransition
    public var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .invalidTransition: return "This action is not available in the current state."
        }
    }
}

public enum Codec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data, maximumBytes: Int? = nil) throws
        -> T
    {
        if let maximumBytes, data.count > maximumBytes {
            throw RecallError.invalid("Choose a file smaller than 20 MB.")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

public typealias Grade = Rating
