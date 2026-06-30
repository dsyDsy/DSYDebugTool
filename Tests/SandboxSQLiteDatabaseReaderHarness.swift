import Foundation
import SQLite3

enum HarnessError: Error, CustomStringConvertible {
    case sqlite(String)
    case assertion(String)

    var description: String {
        switch self {
        case .sqlite(let message):
            return "SQLite error: \(message)"
        case .assertion(let message):
            return "Assertion failed: \(message)"
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw HarnessError.assertion(message)
    }
}

func execute(_ sql: String, database: OpaquePointer?) throws {
    var errorMessage: UnsafeMutablePointer<Int8>?
    let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
    if result != SQLITE_OK {
        let message = errorMessage.map { String(cString: $0) } ?? "unknown"
        sqlite3_free(errorMessage)
        throw HarnessError.sqlite(message)
    }
}

func createDatabase(at url: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK else {
        throw HarnessError.sqlite("open failed")
    }
    defer { sqlite3_close(database) }

    try execute("""
    CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        score REAL,
        note TEXT,
        payload BLOB
    );
    INSERT INTO users (name, score, note, payload) VALUES ('Ada', 9.5, NULL, x'010203');
    INSERT INTO users (name, score, note, payload) VALUES ('Linus', 8.25, 'kernel', x'');
    CREATE TABLE "odd table" (
        "select" TEXT,
        amount INTEGER
    );
    INSERT INTO "odd table" ("select", amount) VALUES ('quoted', 7);
    CREATE TABLE many_rows (
        id INTEGER PRIMARY KEY,
        title TEXT
    );
    """, database: database)

    for index in 1...150 {
        try execute("INSERT INTO many_rows (title) VALUES ('item-\(index)');", database: database)
    }
}

func copyDatabase(from sourceURL: URL, extension fileExtension: String) throws -> URL {
    let targetURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(fileExtension)
    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    return targetURL
}

func runReaderAssertions(fileURL: URL) throws {
    let reader = SandboxSQLiteDatabaseReader(fileURL: fileURL)
    try reader.open()

    let tables = try reader.tables()
    try expect(tables == ["many_rows", "odd table", "users"], "tables should be sorted user tables, got \(tables)")

    let schema = try reader.schema(for: "users")
    try expect(schema.map(\.name) == ["id", "name", "score", "note", "payload"], "schema column names mismatch")
    try expect(schema[0].type == "INTEGER", "id type should be INTEGER")
    try expect(schema[0].isPrimaryKey, "id should be primary key")
    try expect(schema[1].isNotNull, "name should be not null")

    let rowCount = try reader.rowCount(for: "users")
    try expect(rowCount == 2, "users row count should be 2")

    let firstPage = try reader.rows(for: "users", page: 0, pageSize: 1)
    try expect(firstPage.columns == ["id", "name", "score", "note", "payload"], "row columns mismatch")
    try expect(firstPage.rowIDs.count == 1, "first page should expose row ids for app editing")
    try expect(firstPage.rows.count == 1, "first page should contain one row")
    try expect(firstPage.rows[0]["name"] == "Ada", "first row name should be Ada")
    try expect(firstPage.rows[0]["score"] == "9.5", "real values should be stringified")
    try expect(firstPage.rows[0]["note"] == "NULL", "null values should render as NULL")
    try expect(firstPage.rows[0]["payload"] == "<3 bytes>", "blob should render byte count")

    let quotedRows = try reader.rows(for: "odd table", page: 0, pageSize: 100)
    try expect(quotedRows.rows.count == 1, "quoted table should return one row")
    try expect(quotedRows.rows[0]["select"] == "quoted", "quoted column should be readable")

    let manyRowsPage1 = try reader.rows(for: "many_rows", page: 0, pageSize: 100)
    try expect(manyRowsPage1.rows.count == 100, "first page should cap at 100 rows")
    try expect(manyRowsPage1.rows.first?["title"] == "item-1", "first page should begin at item-1")
    let manyRowsPage2 = try reader.rows(for: "many_rows", page: 1, pageSize: 100)
    try expect(manyRowsPage2.rows.count == 50, "second page should contain remaining 50 rows")
    try expect(manyRowsPage2.rows.first?["title"] == "item-101", "second page should begin at item-101")

    let filteredCount = try reader.rowCount(for: "many_rows", keyword: "item-12")
    try expect(filteredCount == 11, "search should match item-12 and item-120 through item-129")
    let filteredRows = try reader.rows(for: "many_rows", page: 0, pageSize: 100, keyword: "item-12")
    try expect(filteredRows.rows.count == 11, "search should return filtered rows")
    try expect(filteredRows.rows.first?["title"] == "item-12", "search should preserve table order")
    let filteredPage = try reader.rows(for: "many_rows", page: 1, pageSize: 100, keyword: "item-")
    try expect(filteredPage.rows.count == 50, "search should keep pagination at 100 rows")

    guard let firstUserRowID = firstPage.rowIDs.first ?? nil else {
        throw HarnessError.assertion("first user rowid should exist")
    }
    try reader.updateValue(tableName: "users", columnName: "name", rowID: firstUserRowID, value: "Grace")
    try reader.updateValue(tableName: "users", columnName: "note", rowID: firstUserRowID, value: nil)
    let updatedPage = try reader.rows(for: "users", page: 0, pageSize: 1)
    try expect(updatedPage.rows[0]["name"] == "Grace", "updated text value should be readable")
    try expect(updatedPage.rows[0]["note"] == "NULL", "nil update should write NULL")

    let tableHTML = SandboxSQLiteHTMLRenderer.localTablePage(
        tableName: "users",
        totalRows: 2,
        page: 0,
        pageSize: 1,
        rows: firstPage
    )
    try expect(tableHTML.contains("table-wrap"), "local table HTML should include a horizontal table wrapper")
    try expect(tableHTML.contains("<th>name</th>"), "local table HTML should render column headers")
    try expect(tableHTML.contains("Rows 1-1 of 2"), "local table HTML should render page status")
    try expect(tableHTML.contains("长按其他单元格可修改"), "local table HTML should advertise non-first-cell long-press editing")
    try expect(tableHTML.contains("sqliteEdit"), "local table HTML should post long-press edit messages")
    try expect(tableHTML.contains("sqliteCopyRow"), "local table HTML should post first-cell row copy messages")
    try expect(tableHTML.contains("copy-row"), "local table HTML should mark first cells as row copy triggers")
    try expect(tableHTML.contains("长按首列复制当前行"), "local table HTML should explain first-cell long-press copy")
    try expect(tableHTML.contains("postCopyRow"), "local table HTML should copy rows from a long-press handler")
    try expect(!tableHTML.contains("editable copy-row"), "first cells should not be editable")
    try expect(tableHTML.contains("data-rowid=\"\(firstUserRowID)\""), "local table HTML should expose row id attributes")
    try expect(!tableHTML.contains("<script>alert(1)</script>"), "local table HTML should escape raw script content")
    let webHTML = SandboxSQLiteHTMLRenderer.webBrowserPage()
    try expect(webHTML.contains("id=\"search\""), "web HTML should include a search input")
    try expect(webHTML.contains("/api/update"), "web HTML should post updates to the update API")
    try expect(webHTML.contains("rowIDs"), "web HTML should use row ids for editing")
    try expect(webHTML.contains("copyRow"), "web HTML should support copying a full row")
    try expect(webHTML.contains("navigator.clipboard"), "web HTML should prefer the browser clipboard API")
    try expect(webHTML.contains("showNotice('复制成功')"), "web HTML should show copy success feedback")
    try expect(webHTML.contains("startCopyPress"), "web HTML should copy rows on long press")
    try expect(
        SandboxSQLiteHTMLRenderer.escapeHTML("<script>alert(1)</script>") == "&lt;script&gt;alert(1)&lt;/script&gt;",
        "HTML escaping should neutralize tags"
    )
}

@main
struct SandboxSQLiteDatabaseReaderHarness {
    static func main() {
        do {
            let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("db")
            try createDatabase(at: baseURL)
            defer { try? FileManager.default.removeItem(at: baseURL) }

            for fileExtension in ["db", "sqlite", "sqlite3"] {
                let url = try copyDatabase(from: baseURL, extension: fileExtension)
                defer { try? FileManager.default.removeItem(at: url) }
                try runReaderAssertions(fileURL: url)
            }

            print("SQLite reader harness passed")
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }
}
