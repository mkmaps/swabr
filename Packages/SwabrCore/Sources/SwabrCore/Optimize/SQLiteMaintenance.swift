import Foundation
import SQLite3

/// A read-write connection through the SQLite C API. Never creates a database.
final class SQLiteDatabase {
    enum Failure: Error, Equatable {
        /// Another process holds a lock longer than the busy timeout.
        case locked
        case damaged(String)
        case unreadable(String)
        case other(String)
    }

    private var handle: OpaquePointer?

    private init(_ handle: OpaquePointer) { self.handle = handle }

    deinit { close() }

    /// Opening is lazy in SQLite; a file that is not a database only fails at the first statement.
    static func open(_ path: String, timeoutMs: Int32) -> Result<SQLiteDatabase, Failure> {
        var db: OpaquePointer?
        let rc = sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
        guard rc == SQLITE_OK, let db else {
            let failure = classify(rc, db.map { String(cString: sqlite3_errmsg($0)) } ?? String(cString: sqlite3_errstr(rc)))
            sqlite3_close_v2(db)
            return .failure(failure)
        }
        sqlite3_busy_timeout(db, timeoutMs)
        return .success(SQLiteDatabase(db))
    }

    func close() {
        if let handle { sqlite3_close_v2(handle) }
        handle = nil
    }

    func execute(_ sql: String) throws(Failure) {
        guard let handle else { throw .other("closed") }
        let rc = sqlite3_exec(handle, sql, nil, nil, nil)
        guard rc == SQLITE_OK else { throw Self.classify(rc, String(cString: sqlite3_errmsg(handle))) }
    }

    /// All rows as text.
    func rows(_ sql: String) throws(Failure) -> [[String]] {
        guard let handle else { throw .other("closed") }
        var statement: OpaquePointer?
        var rc = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard rc == SQLITE_OK, let statement else { throw Self.classify(rc, String(cString: sqlite3_errmsg(handle))) }
        defer { sqlite3_finalize(statement) }
        var out: [[String]] = []
        while true {
            rc = sqlite3_step(statement)
            if rc == SQLITE_DONE { return out }
            guard rc == SQLITE_ROW else { throw Self.classify(rc, String(cString: sqlite3_errmsg(handle))) }
            out.append((0..<sqlite3_column_count(statement)).map { i in
                sqlite3_column_text(statement, i).map { String(cString: $0) } ?? ""
            })
        }
    }

    func integer(_ sql: String) throws(Failure) -> Int64 {
        Int64(try rows(sql).first?.first ?? "") ?? 0
    }

    var changes: Int64 { handle.map { Int64(sqlite3_changes64($0)) } ?? 0 }

    /// `PRAGMA integrity_check` answers a single row "ok" for a sound database.
    func isIntact() throws(Failure) -> Bool {
        do {
            return try rows("PRAGMA integrity_check") == [["ok"]]
        } catch .damaged {
            return false
        }
    }

    private static func classify(_ rc: Int32, _ message: String) -> Failure {
        switch rc & 0xFF {
        case SQLITE_BUSY, SQLITE_LOCKED: .locked
        case SQLITE_CORRUPT, SQLITE_NOTADB: .damaged(message)
        case SQLITE_CANTOPEN, SQLITE_PERM, SQLITE_AUTH, SQLITE_READONLY, SQLITE_IOERR: .unreadable(message)
        default: .other(message)
        }
    }
}

/// Compacts app databases with VACUUM, but only small and intact ones.
public enum SQLiteMaintenance {
    /// Larger databases are reported, not touched: VACUUM rewrites the whole file and needs as much free space again.
    public static let sizeLimit: Int64 = 100_000_000
    /// Milliseconds to wait for another process's lock.
    public static let busyTimeout: Int32 = 2_000

    public enum Verdict: Equatable, Sendable {
        case compacted(saved: Int64)
        /// No free pages, VACUUM would gain nothing.
        case alreadyCompact
        case tooLarge(Int64)
        case damaged
        case locked
        case unreadable
        case missing
    }

    public static func compact(_ path: String, sizeLimit: Int64 = sizeLimit, timeoutMs: Int32 = busyTimeout) -> Verdict {
        guard FileManager.default.fileExists(atPath: path) else { return .missing }
        let before = footprint(path)
        if before > sizeLimit { return .tooLarge(before) }
        let db: SQLiteDatabase
        switch SQLiteDatabase.open(path, timeoutMs: timeoutMs) {
        case .success(let opened): db = opened
        case .failure(let f): return verdict(f)
        }
        do {
            guard try db.isIntact() else { return .damaged }
            if try db.integer("PRAGMA freelist_count") == 0 { return .alreadyCompact }
            try db.execute("VACUUM")
            // In WAL mode the rewritten pages sit in the log until a checkpoint shrinks the file.
            if try db.rows("PRAGMA journal_mode").first?.first?.lowercased() == "wal" {
                try db.execute("PRAGMA wal_checkpoint(TRUNCATE)")
            }
        } catch {
            return verdict(error)
        }
        db.close()
        return .compacted(saved: max(0, before - footprint(path)))
    }

    /// The database file plus its write-ahead log.
    static func footprint(_ path: String) -> Int64 {
        [path, path + "-wal"].reduce(0) { sum, p in
            sum + ((try? FileManager.default.attributesOfItem(atPath: p)[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    static func verdict(_ failure: SQLiteDatabase.Failure) -> Verdict {
        switch failure {
        case .locked: .locked
        case .damaged: .damaged
        case .unreadable, .other: .unreadable
        }
    }
}
