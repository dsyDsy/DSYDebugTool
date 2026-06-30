# SQLite Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build read-only SQLite browsing from CocoaDebug's Sandbox tab, with local app preview and LAN browser projection.

**Architecture:** Swift owns the SQLite reader, UIKit preview controller, and GCDWebServer projection server. Existing Objective-C Sandbox files only add database extension recognition and route selected database files into the Swift controller.

**Tech Stack:** Swift 5, Objective-C, UIKit, SQLite3, GCDWebServer, CocoaPods Example workspace.

---

## File Structure

- Create `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseReader.swift`: read-only SQLite access, data conversion, identifier quoting.
- Create `Tests/SandboxSQLiteDatabaseReaderHarness.swift`: executable Swift harness for reader behavior.
- Create `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteWebServer.swift`: per-database read-only GCDWebServer page and JSON API.
- Create `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseViewController.swift`: table list, schema, paged row UI, web server action.
- Modify `DSYDebugTool/Classes/CocoaDebug/Sandbox/_FileInfo.m`: map `.sqlite` and `.sqlite3` to `_FileTypeDatabase`.
- Modify `DSYDebugTool/Classes/CocoaDebug/Sandbox/_DirectoryContentsTableViewController.m`: import generated Swift interface and route database files to Swift preview.
- Modify `DSYDebugTool.podspec`: add `sqlite3` to CocoaDebug libraries if the Example build requires explicit linkage.

### Task 1: SQLite Reader

**Files:**
- Create: `Tests/SandboxSQLiteDatabaseReaderHarness.swift`
- Create: `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseReader.swift`

- [ ] **Step 1: Write the failing harness**

Create `Tests/SandboxSQLiteDatabaseReaderHarness.swift` with a temporary SQLite database, assertions for tables, schema, row count, paged rows, blob display, and quoted identifiers. It should instantiate `SandboxSQLiteDatabaseReader`, call `open()`, `tables()`, `schema(for:)`, `rowCount(for:)`, and `rows(for:page:pageSize:)`.

- [ ] **Step 2: Run the harness to verify it fails**

Run:

```bash
swiftc Tests/SandboxSQLiteDatabaseReaderHarness.swift DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseReader.swift -lsqlite3 -o /tmp/sqlite-reader-harness
```

Expected: FAIL because `SandboxSQLiteDatabaseReader.swift` does not exist or the symbols are not implemented.

- [ ] **Step 3: Implement the reader**

Add a `SandboxSQLiteDatabaseReader` class that opens with `SQLITE_OPEN_READONLY`, reads user tables from `sqlite_master`, uses `PRAGMA table_info`, counts rows, and returns paged rows ordered by SQLite's natural row order. Convert null to `"NULL"`, integer/float/text to strings, and blobs to `"<N bytes>"`.

- [ ] **Step 4: Run the harness to verify it passes**

Run:

```bash
swiftc Tests/SandboxSQLiteDatabaseReaderHarness.swift DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseReader.swift -lsqlite3 -o /tmp/sqlite-reader-harness
/tmp/sqlite-reader-harness
```

Expected: PASS and output `SQLite reader harness passed`.

### Task 2: Sandbox Routing

**Files:**
- Modify: `DSYDebugTool/Classes/CocoaDebug/Sandbox/_FileInfo.m`
- Modify: `DSYDebugTool/Classes/CocoaDebug/Sandbox/_DirectoryContentsTableViewController.m`
- Create: `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseViewController.swift`

- [ ] **Step 1: Write the routing expectation**

Update the harness to assert that paths ending in `.db`, `.sqlite`, and `.sqlite3` can all be opened by the reader when they contain SQLite data.

- [ ] **Step 2: Run the harness to verify reader behavior still passes**

Run `/tmp/sqlite-reader-harness` after recompilation. Expected: PASS.

- [ ] **Step 3: Add the local preview controller**

Create `SandboxSQLiteDatabaseViewController` as an `@objc` Swift `UITableViewController` subclass initialized with a file URL. It lists tables, shows schema and paged row values, and displays errors with labels or alerts.

- [ ] **Step 4: Route database files**

Add `.sqlite` and `.sqlite3` recognition in `_FileInfo.m`. Import `DSYDebugTool-Swift.h` in `_DirectoryContentsTableViewController.m` and return `SandboxSQLiteDatabaseViewController(fileURL:)` before Quick Look handling for `_FileTypeDatabase`.

### Task 3: GCDWebServer Projection

**Files:**
- Create: `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteWebServer.swift`
- Modify: `DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseViewController.swift`

- [ ] **Step 1: Add server class**

Create `SandboxSQLiteWebServer` with `start(fileURL:)`, `stop()`, and `urlString`. Register `/`, `/api/tables`, `/api/schema`, and `/api/rows` handlers. Use `SandboxSQLiteDatabaseReader` per request and return JSON responses.

- [ ] **Step 2: Add UI action**

Add a right navigation bar action in the database preview controller. It starts the server, then shows an alert with the LAN URL and a copy action.

- [ ] **Step 3: Verify server API compiles**

Run the Example workspace build. Expected: the DSYDebugTool target compiles with the new Swift files and GCDWebServer imports.

### Task 4: Final Verification

**Files:**
- Verify all changed source files.

- [ ] **Step 1: Run reader harness**

Run:

```bash
swiftc Tests/SandboxSQLiteDatabaseReaderHarness.swift DSYDebugTool/Classes/CocoaDebug/Sandbox/SandboxSQLiteDatabaseReader.swift -lsqlite3 -o /tmp/sqlite-reader-harness
/tmp/sqlite-reader-harness
```

Expected: `SQLite reader harness passed`.

- [ ] **Step 2: Run Example build**

Run:

```bash
xcodebuild -workspace Example/DSYDebugToolTest.xcworkspace -scheme DSYDebugToolTest -destination 'generic/platform=iOS Simulator' build
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Inspect Git diff**

Run:

```bash
git diff -- DSYDebugTool/Classes/CocoaDebug/Sandbox DSYDebugTool.podspec Tests docs
```

Expected: only SQLite browser feature changes and docs.
