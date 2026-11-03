import Foundation

public struct CardUpdate: Identifiable, Sendable {
    public var id: String { after.id }
    public let before: Flashcard
    public let after: Flashcard
    public var answerChanged: Bool {
        before.answer != after.answer || before.answerBlocks != after.answerBlocks
    }
    public var suggestedReset: Bool {
        after.change == .correction
            || (answerChanged && after.change != .explanation && after.change != .wording)
    }
}

public struct ImportPlan: Sendable {
    public let deck: Deck
    public let added: Int
    public let updated: Int
    public let unchanged: Int
    public let updates: [CardUpdate]
}

extension Deck {
    public func validate() throws {
        guard [1, 2].contains(schemaVersion) else {
            throw RecallError.invalid("This deck uses an unsupported format.")
        }
        guard !title.isEmpty, !cards.isEmpty, cards.count <= 5000, concepts.count <= 1000 else {
            throw RecallError.invalid("A deck needs a title, concepts, and between 1 and 5,000 cards.")
        }
        let conceptIDs = Set(concepts.map(\.id))
        let cardIDs = Set(cards.map(\.id))
        let assetIDs = Set((assets ?? []).map(\.id))
        guard conceptIDs.count == concepts.count, cardIDs.count == cards.count,
            assetIDs.count == (assets ?? []).count
        else { throw RecallError.invalid("The file contains duplicate IDs.") }
        for asset in assets ?? [] { try asset.validate() }
        for concept in concepts {
            guard !concept.id.isEmpty, !concept.title.isEmpty, !concept.explanation.isEmpty,
                concept.explanation.count <= 50000, concept.effectiveRevision > 0,
                (concept.prerequisiteIDs ?? []).allSatisfy({ conceptIDs.contains($0) && $0 != concept.id })
            else {
                throw RecallError.invalid(
                    "A concept has an invalid ID, title, explanation, revision, or prerequisite.")
            }
            if let image = concept.sourceImage {
                guard image == URL(fileURLWithPath: image).lastPathComponent, !image.contains("..") else {
                    throw RecallError.invalid("Screenshot references must be plain file names.")
                }
            }
            try validate(sections: concept.sections ?? [], assets: assetIDs)
        }
        // Catch prerequisite cycles before the app tries to navigate through them.
        var visited = Set<String>()
        var visiting = Set<String>()
        let prerequisites = Dictionary(
            uniqueKeysWithValues: concepts.map { ($0.id, $0.prerequisiteIDs ?? []) })
        func visit(_ id: String) throws {
            if visited.contains(id) { return }
            guard visiting.insert(id).inserted else {
                throw RecallError.invalid("Prerequisite links contain a cycle.")
            }
            for prerequisite in prerequisites[id] ?? [] { try visit(prerequisite) }
            visiting.remove(id)
            visited.insert(id)
        }
        for id in conceptIDs { try visit(id) }
        for card in cards {
            guard !card.id.isEmpty, conceptIDs.contains(card.conceptID), card.revision > 0,
                !card.effectiveObjective.isEmpty, !card.prompt.isEmpty, !card.answer.isEmpty,
                card.prompt.count <= 10000, card.answer.count <= 20000
            else {
                throw RecallError.invalid("A card has an invalid concept, revision, question, or answer.")
            }
            try validate(blocks: card.answerBlocks ?? [], assets: assetIDs)
            try validate(sections: card.explanationSections ?? [], assets: assetIDs)
        }
    }
    private func validate(sections: [LessonSection], assets: Set<String>) throws {
        guard sections.count <= 40, Set(sections.map(\.id)).count == sections.count else {
            throw RecallError.invalid("A lesson has too many sections or duplicate section IDs.")
        }
        for section in sections {
            guard !section.id.isEmpty, !section.title.isEmpty,
                section.role != .history || !(section.sourceURLs ?? []).isEmpty
            else {
                throw RecallError.invalid(
                    "A lesson section needs a title, and historical notes need sources.")
            }
            for source in section.sourceURLs ?? [] {
                guard let url = URL(string: source), url.scheme == "https", url.host != nil else {
                    throw RecallError.invalid("Lesson sources must be HTTPS links.")
                }
            }
            try validate(blocks: section.blocks, assets: assets)
            let steps = section.steps ?? []
            guard steps.count <= 40, Set(steps.map(\.id)).count == steps.count else {
                throw RecallError.invalid("A derivation has too many steps or duplicate step IDs.")
            }
            for step in steps {
                guard !step.id.isEmpty, !step.title.isEmpty, !step.blocks.isEmpty else {
                    throw RecallError.invalid("A derivation step needs a title and content.")
                }
                try validate(blocks: step.blocks, assets: assets)
            }
        }
    }
    private func validate(blocks: [LessonBlock], assets: Set<String>) throws {
        guard blocks.count <= 200, Set(blocks.map(\.id)).count == blocks.count else {
            throw RecallError.invalid("Content blocks need unique IDs and a reasonable length.")
        }
        for block in blocks {
            guard !block.id.isEmpty else { throw RecallError.invalid("A content block needs an ID.") }
            switch block.kind {
            case .text, .equation:
                guard let text = block.text, !text.isEmpty, text.count <= 50000 else {
                    throw RecallError.invalid("A text or equation block is empty or too long.")
                }
            case .diagram:
                guard let id = block.assetID, assets.contains(id) else {
                    throw RecallError.invalid("A diagram block refers to a missing asset.")
                }
            }
        }
    }
    public func plan(against existing: Deck) throws -> ImportPlan {
        try validate()
        var added = 0
        var updated = 0
        var unchanged = 0
        var updates: [CardUpdate] = []
        for concept in concepts {
            if let old = existing.concepts.first(where: { $0.id == concept.id }),
                schemaVersion >= 2 || old.revision != nil
            {
                guard concept.effectiveRevision >= old.effectiveRevision,
                    concept == old || concept.effectiveRevision > old.effectiveRevision
                else {
                    throw RecallError.invalid("Increase the revision for concept \(concept.id).")
                }
            }
        }
        for card in cards {
            guard let old = existing.cards.first(where: { $0.id == card.id }) else {
                added += 1
                continue
            }
            guard old.effectiveObjective == card.effectiveObjective, old.conceptID == card.conceptID,
                old.kind == card.kind,
                old.prompt == card.prompt || card.change == .wording
            else {
                throw RecallError.invalid(
                    "Card \(card.id) changes what is tested. Use a new ID, or mark a wording-only edit explicitly."
                )
            }
            guard card.revision >= old.revision else {
                throw RecallError.invalid("Card \(card.id) has an older revision.")
            }
            if old == card {
                unchanged += 1
            } else {
                guard card.revision > old.revision else {
                    throw RecallError.invalid("Increase the revision for card \(card.id).")
                }
                updated += 1
                updates.append(.init(before: old, after: card))
            }
        }
        return ImportPlan(deck: self, added: added, updated: updated, unchanged: unchanged, updates: updates)
    }
}

extension Library {
    public mutating func merge(_ incoming: Deck, resetting resetIDs: Set<String> = []) throws {
        let plan = try incoming.plan(against: deck)
        guard resetIDs.isSubset(of: Set(plan.updates.map(\.id))) else {
            throw RecallError.invalid("Only revised cards can have their schedule reset during import.")
        }
        for concept in incoming.concepts {
            if let i = deck.concepts.firstIndex(where: { $0.id == concept.id }) {
                deck.concepts[i] = concept
            } else {
                deck.concepts.append(concept)
            }
        }
        for card in incoming.cards {
            if let i = deck.cards.firstIndex(where: { $0.id == card.id }) {
                deck.cards[i] = card
            } else {
                deck.cards.append(card)
            }
        }
        var assets = deck.assets ?? []
        for asset in incoming.assets ?? [] where !assets.contains(where: { $0.id == asset.id }) {
            assets.append(asset)
        }
        if !assets.isEmpty { deck.assets = assets }
        for id in resetIDs { schedules.removeValue(forKey: id) }
        deck.schemaVersion = max(deck.schemaVersion, incoming.schemaVersion)
        removeArchivedCardsFromSession()
    }
    public func validate() throws {
        guard [1, 2].contains(schemaVersion) else {
            throw RecallError.invalid("This backup uses an unsupported format.")
        }
        try deck.validate()
        let ids = Set(deck.cards.map(\.id))
        for (id, card) in schedules {
            guard ids.contains(id), card.due.timeIntervalSince1970.isFinite,
                card.stability.isFinite, card.stability >= 0, card.difficulty.isFinite,
                (0...10).contains(card.difficulty), card.reps >= 0, card.lapses >= 0,
                card.elapsedDays.isFinite, card.elapsedDays >= 0,
                card.scheduledDays.isFinite, card.scheduledDays >= 0,
                card.learningSteps >= 0, card.learningSteps < 2
            else {
                throw RecallError.invalid("The backup contains an invalid review schedule.")
            }
        }
        guard Set(events.map(\.id)).count == events.count,
            events.allSatisfy({ ids.contains($0.cardID) })
        else { throw RecallError.invalid("The backup has invalid review records.") }
        for (key, content) in contentVersions ?? [:] {
            guard try content.digest == key else {
                throw RecallError.invalid("An archived content version has an invalid hash.")
            }
        }
        for event in events {
            if let key = event.contentID {
                guard let content = contentVersions?[key], content.card.id == event.cardID,
                    content.card.revision == event.revision
                else { throw RecallError.invalid("A review is missing its content version.") }
            }
        }
        if let session {
            guard session.completed >= 0, session.total == session.completed + session.queue.count,
                Set(session.queue).count == session.queue.count,
                session.queue.allSatisfy({ ids.contains($0) })
            else {
                throw RecallError.invalid("The backup has an invalid review session.")
            }
        }
    }
}

public enum ImportState {
    case idle, reading
    case preview(ImportPlan)
    case restore(Library)
    case saving
    case complete(String)
    case failed(String)
}

/// A typed discriminator for the two supported file formats.
public enum CardFile: Decodable, Sendable {
    case backup(Library)
    case deck(Deck)
    private enum CodingKeys: String, CodingKey { case deck }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.deck) {
            self = .backup(try Library(from: decoder))
        } else {
            self = .deck(try Deck(from: decoder))
        }
    }
}
