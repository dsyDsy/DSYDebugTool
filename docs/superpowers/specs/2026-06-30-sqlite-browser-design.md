# SQLite Browser Design

## Goal

Add read-only SQLite browsing to CocoaDebug's Sandbox tab. When a user taps a `.sqlite`, `.sqlite3`, or `.db` file, the app should show a local database preview and offer a LAN browser view through GCDWebServer.

## Scope

The first version is read-only. It lists tables, shows table schema, and pages through rows. It does not edit data, run user-entered SQL, export query results, or mutate database files.

## Architecture

The feature stays inside `DSYDebugTool/Classes/CocoaDebug/Sandbox` and reuses the existing CocoaDebug dependency on `DSYDebugTool/TransferServer`, which already provides GCDWebServer. Swift handles the database reader, local UI, and web projection. Objective-C sandbox files only identify SQLite extensions and route selected database files into the Swift preview controller.

## Components

`SandboxSQLiteDatabaseReader.swift` opens SQLite files with `SQLITE_OPEN_READONLY` and exposes a small API: table list, schema, row count, and paged rows. It quotes identifiers internally and does not accept arbitrary SQL.

`SandboxSQLiteDatabaseViewController.swift` is the local preview UI. It shows tables first, then table rows with paging. It includes a navigation action to start the web projection and display the URL.

`SandboxSQLiteWebServer.swift` owns a small GCDWebServer instance for the selected database. It serves a read-only HTML page plus JSON endpoints for tables, schema, and paged rows.

`_FileInfo` recognizes `.sqlite`, `.sqlite3`, and `.db` as `_FileTypeDatabase`.

`_DirectoryContentsTableViewController` routes `_FileTypeDatabase` files to `SandboxSQLiteDatabaseViewController`.

## Data Flow

The Sandbox list creates `_FileInfo` objects for files. If a tapped file is a database, the Objective-C controller instantiates the Swift database view controller with the file URL. The view controller creates a reader to load tables and rows. If the user starts computer browsing, the web server creates its own read-only reader for API responses and serves the LAN URL.

## Error Handling

Encrypted, corrupt, locked, missing, or non-SQLite files show readable errors instead of crashing. Empty databases show an empty state. Large tables are paged with a default page size of 100 rows. Values are converted to strings for display, with blobs represented by byte counts.

## Verification

The SQLite reader gets a Swift command-line harness that creates a temporary database, verifies extension-independent read-only access, table listing, schema, row paging, identifier quoting, and row count. The CocoaDebug integration is verified with an Example workspace build where available.
