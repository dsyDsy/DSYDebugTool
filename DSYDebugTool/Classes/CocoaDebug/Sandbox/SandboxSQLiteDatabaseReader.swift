import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct SandboxSQLiteColumn {
    let cid: Int
    let name: String
    let type: String
    let isNotNull: Bool
    let defaultValue: String?
    let isPrimaryKey: Bool
}

struct SandboxSQLiteRows {
    let columns: [String]
    let rows: [[String: String]]
    let rowIDs: [Int64?]
}

final class SandboxSQLiteDatabaseReader {
    enum ReaderError: Error, LocalizedError {
        case openFailed(String)
        case queryFailed(String)
        case invalidPageSize
        case unsupportedTable(String)

        var errorDescription: String? {
            switch self {
            case .openFailed(let message):
                return "Open database failed: \(message)"
            case .queryFailed(let message):
                return "Query database failed: \(message)"
            case .invalidPageSize:
                return "Page size must be greater than zero"
            case .unsupportedTable(let message):
                return message
            }
        }
    }

    private let fileURL: URL
    private var database: OpaquePointer?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    deinit {
        close()
    }

    func open() throws {
        if database != nil {
            return
        }

        var openedDatabase: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let result = sqlite3_open_v2(fileURL.path, &openedDatabase, flags, nil)
        guard result == SQLITE_OK, let openedDatabase else {
            let message = openedDatabase.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let openedDatabase {
                sqlite3_close(openedDatabase)
            }
            throw ReaderError.openFailed(message)
        }

        database = openedDatabase
    }

    func close() {
        if let database {
            sqlite3_close(database)
            self.database = nil
        }
    }

    func tables() throws -> [String] {
        try open()
        let sql = """
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name COLLATE NOCASE
        """
        let rows = try query(sql: sql)
        return rows.compactMap { $0["name"] }
    }

    func schema(for tableName: String) throws -> [SandboxSQLiteColumn] {
        try open()
        let sql = "PRAGMA table_info(\(quoteIdentifier(tableName)))"
        let rows = try query(sql: sql)
        return rows.map { row in
            SandboxSQLiteColumn(
                cid: Int(row["cid"] ?? "") ?? 0,
                name: row["name"] ?? "",
                type: row["type"] ?? "",
                isNotNull: (Int(row["notnull"] ?? "") ?? 0) != 0,
                defaultValue: row["dflt_value"],
                isPrimaryKey: (Int(row["pk"] ?? "") ?? 0) != 0
            )
        }
    }

    func rowCount(for tableName: String, keyword: String? = nil) throws -> Int {
        try open()
        let search = try searchClause(tableName: tableName, keyword: keyword)
        let rows = try query(sql: "SELECT COUNT(*) AS count FROM \(quoteIdentifier(tableName))\(search.sql)", bindings: search.bindings)
        return Int(rows.first?["count"] ?? "") ?? 0
    }

    func rows(for tableName: String, page: Int, pageSize: Int, keyword: String? = nil) throws -> SandboxSQLiteRows {
        try open()
        guard pageSize > 0 else {
            throw ReaderError.invalidPageSize
        }

        let safePage = max(0, page)
        let offset = safePage * pageSize
        let search = try searchClause(tableName: tableName, keyword: keyword)
        let sql = "SELECT rowid AS __dsy_debug_rowid__, * FROM \(quoteIdentifier(tableName))\(search.sql) LIMIT \(pageSize) OFFSET \(offset)"
        return try queryRows(sql: sql, bindings: search.bindings, extractsRowID: true)
    }

    func updateValue(tableName: String, columnName: String, rowID: Int64, value: String?) throws {
        var writableDatabase: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX
        let openResult = sqlite3_open_v2(fileURL.path, &writableDatabase, flags, nil)
        guard openResult == SQLITE_OK, let writableDatabase else {
            let message = writableDatabase.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let writableDatabase {
                sqlite3_close(writableDatabase)
            }
            throw ReaderError.openFailed(message)
        }
        defer { sqlite3_close(writableDatabase) }

        let sql = "UPDATE \(quoteIdentifier(tableName)) SET \(quoteIdentifier(columnName)) = ? WHERE rowid = ?"
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(writableDatabase, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            throw ReaderError.queryFailed(String(cString: sqlite3_errmsg(writableDatabase)))
        }
        defer { sqlite3_finalize(statement) }

        if let value {
            sqlite3_bind_text(statement, 1, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 1)
        }
        sqlite3_bind_int64(statement, 2, rowID)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw ReaderError.queryFailed(String(cString: sqlite3_errmsg(writableDatabase)))
        }
    }

    private func query(sql: String, bindings: [String] = []) throws -> [[String: String]] {
        let result = try queryRows(sql: sql, bindings: bindings)
        return result.rows
    }

    private func queryRows(sql: String, bindings: [String] = [], extractsRowID: Bool = false) throws -> SandboxSQLiteRows {
        guard let database else {
            throw ReaderError.openFailed("database is not open")
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK, let statement else {
            throw ReaderError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }

        let rawColumnCount = sqlite3_column_count(statement)
        guard !extractsRowID || rawColumnCount > 0 else {
            throw ReaderError.unsupportedTable("This table cannot expose rowid for editing")
        }
        let firstDataColumn: Int32 = extractsRowID ? 1 : 0
        let columns = (firstDataColumn..<rawColumnCount).map { index in
            String(cString: sqlite3_column_name(statement, index))
        }

        var rows: [[String: String]] = []
        var rowIDs: [Int64?] = []
        while true {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_ROW {
                if extractsRowID {
                    rowIDs.append(sqlite3_column_type(statement, 0) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 0))
                }
                var row: [String: String] = [:]
                for index in firstDataColumn..<rawColumnCount {
                    row[columns[Int(index - firstDataColumn)]] = stringValue(statement: statement, column: index)
                }
                rows.append(row)
            } else if stepResult == SQLITE_DONE {
                break
            } else {
                throw ReaderError.queryFailed(String(cString: sqlite3_errmsg(database)))
            }
        }

        return SandboxSQLiteRows(columns: columns, rows: rows, rowIDs: rowIDs)
    }

    private func searchClause(tableName: String, keyword: String?) throws -> (sql: String, bindings: [String]) {
        guard let keyword = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !keyword.isEmpty else {
            return ("", [])
        }

        let searchableColumns = try schema(for: tableName).filter { column in
            !column.type.uppercased().contains("BLOB")
        }
        guard !searchableColumns.isEmpty else {
            return (" WHERE 0", [])
        }

        let predicates = searchableColumns.map { column in
            "CAST(\(quoteIdentifier(column.name)) AS TEXT) LIKE ? ESCAPE '\\'"
        }
        return (" WHERE \(predicates.joined(separator: " OR "))", Array(repeating: "%\(escapedLikePattern(keyword))%", count: searchableColumns.count))
    }

    private func escapedLikePattern(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "%", with: "\\%")
        escaped = escaped.replacingOccurrences(of: "_", with: "\\_")
        return escaped
    }

    private func stringValue(statement: OpaquePointer, column: Int32) -> String {
        switch sqlite3_column_type(statement, column) {
        case SQLITE_INTEGER:
            return String(sqlite3_column_int64(statement, column))
        case SQLITE_FLOAT:
            return String(sqlite3_column_double(statement, column))
        case SQLITE_TEXT:
            guard let text = sqlite3_column_text(statement, column) else {
                return ""
            }
            return String(cString: text)
        case SQLITE_BLOB:
            return "<\(sqlite3_column_bytes(statement, column)) bytes>"
        case SQLITE_NULL:
            return "NULL"
        default:
            return ""
        }
    }

    private func quoteIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
