import CSQLite
import Foundation

/// SQLite transactions keep each rating, schedule, content snapshot, and session in one commit.
public struct DatabaseStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    private struct Header: Codable {
        var schemaVersion: Int
        var deckVersion: Int
        var title: String
        var concepts: [String]
        var cards: [String]
        var assets: [String]?
        var events: [String]
        var session: ReviewSession?
    }
    private static let tables = [
        "metadata", "concepts", "cards", "assets", "schedules", "events", "content_versions",
    ]

    public func loadOrMigrateLegacy(at legacyURL: URL) throws -> Library? {
        if FileManager.default.fileExists(atPath: url.path) { return try load() }
        guard let legacy = try DiskStore(url: legacyURL).load() else { return nil }
        try save(legacy)
        return try load()
    }

    public func load() throws -> Library? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try connection { db in
            let headers: [String: Header] = try read("metadata", db)
            guard let header = headers["library"] else {
                throw RecallError.invalid("The database is missing its library record.")
            }
            let concepts: [String: Concept] = try read("concepts", db)
            let cards: [String: Flashcard] = try read("cards", db)
            let assets: [String: DiagramAsset] = try read("assets", db)
            let events: [String: ReviewEvent] = try read("events", db)
            func ordered<T>(_ ids: [String], _ values: [String: T]) throws -> [T] {
                try ids.map { id in
                    guard let value = values[id] else {
                        throw RecallError.invalid("A database record is missing.")
                    }
                    return value
                }
            }
            var deck = Deck(
                schemaVersion: header.deckVersion, title: header.title,
                concepts: try ordered(header.concepts, concepts), cards: try ordered(header.cards, cards))
            deck.assets = try header.assets.map { try ordered($0, assets) }
            var result = Library(deck: deck)
            result.schemaVersion = header.schemaVersion
            result.schedules = try read("schedules", db)
            result.events = try ordered(header.events, events)
            result.session = header.session
            let versions: [String: ReviewContent] = try read("content_versions", db)
            result.contentVersions = versions.isEmpty ? nil : versions
            try result.validate()
            return result
        }
    }

    public func save(_ library: Library) throws {
        try library.validate()
        try connection { db in
            try execute("BEGIN IMMEDIATE", db)
            do {
                try reconcile(
                    "concepts", Dictionary(uniqueKeysWithValues: library.deck.concepts.map { ($0.id, $0) }),
                    db)
                try reconcile(
                    "cards", Dictionary(uniqueKeysWithValues: library.deck.cards.map { ($0.id, $0) }), db)
                try reconcile(
                    "assets",
                    Dictionary(uniqueKeysWithValues: (library.deck.assets ?? []).map { ($0.id, $0) }), db)
                try reconcile("schedules", library.schedules, db)
                try reconcile(
                    "events", Dictionary(uniqueKeysWithValues: library.events.map { ($0.id.uuidString, $0) }),
                    db)
                try reconcile("content_versions", library.contentVersions ?? [:], db)
                let header = Header(
                    schemaVersion: library.schemaVersion, deckVersion: library.deck.schemaVersion,
                    title: library.deck.title, concepts: library.deck.concepts.map(\.id),
                    cards: library.deck.cards.map(\.id),
                    assets: library.deck.assets?.map(\.id), events: library.events.map { $0.id.uuidString },
                    session: library.session)
                try reconcile("metadata", ["library": header], db)
                try execute("COMMIT", db)
            } catch {
                try? execute("ROLLBACK", db)
                throw error
            }
        }
    }

    /// Build a complete replacement separately, then replace even a corrupt database atomically.
    public func replace(with library: Library) throws {
        let stagedURL = url.deletingLastPathComponent().appendingPathComponent(
            "restore-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        try DatabaseStore(url: stagedURL).save(library)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: stagedURL)
        } else {
            try FileManager.default.moveItem(at: stagedURL, to: url)
        }
    }

    private func connection<T>(_ work: (OpaquePointer) throws -> T) throws -> T {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard
            sqlite3_open_v2(
                url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
                == SQLITE_OK,
            let db = handle
        else {
            if let handle { sqlite3_close(handle) }
            throw RecallError.invalid("Couldn’t open the local database.")
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 5000)
        let version = try statement("PRAGMA user_version", db) { statement -> Int32 in
            guard sqlite3_step(statement) == SQLITE_ROW else { throw failure(db) }
            return sqlite3_column_int(statement, 0)
        }
        guard version == 0 || version == 1 else {
            throw RecallError.invalid("This database needs a newer app version.")
        }
        for table in Self.tables {
            try execute(
                "CREATE TABLE IF NOT EXISTS \(table) (id TEXT PRIMARY KEY NOT NULL, payload BLOB NOT NULL)",
                db)
        }
        if version == 0 { try execute("PRAGMA user_version=1", db) }
        return try work(db)
    }
    private func read<T: Decodable>(_ table: String, _ db: OpaquePointer) throws -> [String: T] {
        try statement("SELECT id,payload FROM \(table)", db) { statement in
            var results: [String: T] = [:]
            while true {
                let code = sqlite3_step(statement)
                if code == SQLITE_DONE { break }
                guard code == SQLITE_ROW, let rawID = sqlite3_column_text(statement, 0),
                    let bytes = sqlite3_column_blob(statement, 1)
                else { throw failure(db) }
                let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 1)))
                results[String(cString: rawID)] = try Codec.decode(T.self, from: data)
            }
            return results
        }
    }
    private func reconcile<T: Encodable>(_ table: String, _ values: [String: T], _ db: OpaquePointer) throws {
        let keys: [String] = try statement("SELECT id FROM \(table)", db) { statement in
            var keys: [String] = []
            while true {
                let code = sqlite3_step(statement)
                if code == SQLITE_DONE { break }
                guard code == SQLITE_ROW, let key = sqlite3_column_text(statement, 0) else {
                    throw failure(db)
                }
                keys.append(String(cString: key))
            }
            return keys
        }
        for key in keys where values[key] == nil {
            try statement("DELETE FROM \(table) WHERE id=?", db) { statement in
                try bind(key, at: 1, statement, db)
                guard sqlite3_step(statement) == SQLITE_DONE else { throw failure(db) }
            }
        }
        try statement(
            "INSERT INTO \(table)(id,payload) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload WHERE payload != excluded.payload",
            db
        ) { statement in
            for (key, value) in values {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                let data = try Codec.encode(value)
                try bind(key, at: 1, statement, db)
                let status = data.withUnsafeBytes {
                    sqlite3_bind_blob(
                        statement, 2, $0.baseAddress, Int32(data.count),
                        unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                }
                guard status == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else { throw failure(db) }
            }
        }
    }
    private func bind(_ text: String, at index: Int32, _ statement: OpaquePointer, _ db: OpaquePointer) throws
    {
        guard
            sqlite3_bind_text(statement, index, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                == SQLITE_OK
        else { throw failure(db) }
    }
    private func statement<T>(_ sql: String, _ db: OpaquePointer, _ work: (OpaquePointer) throws -> T) throws
        -> T
    {
        var pointer: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &pointer, nil) == SQLITE_OK, let pointer else {
            throw failure(db)
        }
        defer { sqlite3_finalize(pointer) }
        return try work(pointer)
    }
    private func execute(_ sql: String, _ db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure(db) }
    }
    private func failure(_ db: OpaquePointer) -> RecallError {
        .invalid("Local database: " + String(cString: sqlite3_errmsg(db)))
    }
}
