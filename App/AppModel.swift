import RecallCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var library: Library?
    @Published private(set) var review = ReviewMachine()
    @Published var importState: ImportState = .idle
    @Published var presentingReview = false
    @Published var importResetIDs: Set<String> = []
    @Published var error: String?
    @Published var startupError: String?
    let disk: DatabaseStore

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MathRecall", isDirectory: true)
        disk = DatabaseStore(url: folder.appendingPathComponent("library.sqlite"))
        do {
            guard let url = Bundle.main.url(forResource: "starter", withExtension: "json") else {
                throw RecallError.invalid("The starter deck is missing from the app.")
            }
            let deck = try Codec.decode(Deck.self, from: Data(contentsOf: url))
            if let saved = try disk.loadOrMigrateLegacy(at: folder.appendingPathComponent("library.json")) {
                let refreshed = try saved.refreshingBundledContent(from: deck)
                if refreshed.deck != saved.deck || refreshed.session != saved.session {
                    try disk.save(refreshed)
                }
                library = refreshed
            } else {
                let initial = Library(deck: deck)
                try disk.save(initial)
                library = initial
            }
        } catch { startupError = error.localizedDescription }
    }

    var due: [Flashcard] { library?.dueCards(at: Date()) ?? [] }
    var nextDue: Date? { library?.nextReviewDate }
    func concept(for card: Flashcard) -> Concept? { library?.deck.concepts.first { $0.id == card.conceptID } }
    func card(_ id: String) -> Flashcard? { library?.deck.cards.first { $0.id == id } }
    func commit(_ candidate: Library) throws {
        try disk.save(candidate)
        library = candidate
    }
    func startReview() {
        guard var candidate = library else { return }
        candidate.removeArchivedCardsFromSession()
        if candidate.session?.queue.isEmpty != false {
            candidate.session = ReviewSession(queue: due.map(\.id))
        }
        do {
            try commit(candidate)
            if let session = candidate.session { review.begin(session: session) }
        } catch { self.error = error.localizedDescription }
    }
    func turnCard(token: UUID) {
        guard review.canTurn else { return }
        do { try review.beginTurn(token: token) } catch { self.error = error.localizedDescription }
    }
    func finishTurn(token: UUID) { review.finishTurn(token: token) }
    func rate(_ grade: Grade, cardID: String) {
        guard var candidate = library else { return }
        do {
            try review.beginSave(cardID: cardID)
            try candidate.rate(cardID: cardID, rating: grade, at: Date())
            try commit(candidate)
            if let session = candidate.session { try review.saved(session: session) }
        } catch {
            review.saveFailed()
            self.error = error.localizedDescription
        }
    }
    func interval(_ grade: Grade, cardID: String) -> String {
        guard let scheduled = try? library?.preview(cardID: cardID, rating: grade, at: Date()) else {
            return ""
        }
        let seconds = max(0, scheduled.due.timeIntervalSinceNow)
        if seconds < 3600 { return "\(max(1, Int((seconds / 60).rounded())))m" }
        if seconds < 86400 { return "\(Int((seconds / 3600).rounded()))h" }
        return "\(Int((seconds / 86400).rounded()))d"
    }
    func readImport(_ url: URL) {
        importState = .reading
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 128_000_000 else { throw RecallError.invalid("Choose a file smaller than 128 MB.") }
            let data = try Data(contentsOf: url)
            switch try Codec.decode(CardFile.self, from: data) {
            case .backup(let backup):
                try backup.validate()
                importState = .restore(backup)
            case .deck(let deck):
                guard data.count <= 20_000_000 else {
                    throw RecallError.invalid("Choose a file smaller than 20 MB.")
                }
                guard let current = library else {
                    throw RecallError.invalid("Open your library before importing a deck.")
                }
                let plan = try deck.plan(against: current.deck)
                importResetIDs = Set(plan.updates.filter(\.suggestedReset).map(\.id))
                importState = .preview(plan)
            }
        } catch { importState = .failed(error.localizedDescription) }
    }
    func applyImport() {
        let pending = importState
        importState = .saving
        do {
            switch pending {
            case .preview(let plan):
                guard var candidate = library else {
                    throw RecallError.invalid("Open your library before importing a deck.")
                }
                try candidate.merge(plan.deck, resetting: importResetIDs)
                try commit(candidate)
                importState = .complete(
                    importResetIDs.isEmpty
                        ? "Cards imported. Review history kept."
                        : "Cards imported. Review history kept; selected cards will start again.")
            case .restore(let backup):
                // Keep a local recovery copy before replacing the library.
                let recovery = DiskStore(
                    url: disk.url.deletingLastPathComponent().appendingPathComponent("before-restore.json"))
                if let current = library {
                    try recovery.save(current)
                } else if FileManager.default.fileExists(atPath: disk.url.path) {
                    let original = try Data(contentsOf: disk.url)
                    let kept = disk.url.deletingLastPathComponent().appendingPathComponent(
                        "unreadable-" + UUID().uuidString + ".json")
                    try original.write(to: kept, options: .atomic)
                }
                try disk.replace(with: backup)
                library = backup
                startupError = nil
                importState = .complete("Backup restored, including review history.")
            default: throw RecallError.invalidTransition
            }
        } catch { importState = .failed(error.localizedDescription) }
    }
    func setArchived(cardID: String, archived: Bool) throws {
        guard var candidate = library else { throw RecallError.invalid("Your library is not open.") }
        try candidate.setArchived(cardID: cardID, archived: archived)
        try commit(candidate)
    }

    func editAnswer(cardID: String, answer: String, reset: Bool = false) throws {
        guard var candidate = library,
            let index = candidate.deck.cards.firstIndex(where: { $0.id == cardID }),
            !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw RecallError.invalid("An answer cannot be empty.")
        }
        candidate.deck.cards[index].answer = answer
        candidate.deck.cards[index].hint = ""
        candidate.deck.cards[index].revision += 1
        candidate.deck.cards[index].answerBlocks = nil
        candidate.deck.cards[index].explanationSections = nil
        candidate.deck.cards[index].change = .explanation
        if reset { candidate.schedules.removeValue(forKey: cardID) }
        try commit(candidate)
    }
}
