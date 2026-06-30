import Foundation
import Darwin
import GCDWebServer

final class SandboxSQLiteWebServer {
    private let webServer = GCDWebServer()
    private let fileURL: URL
    private(set) var urlString: String?

    init(fileURL: URL) {
        self.fileURL = fileURL
        registerHandlers()
    }

    deinit {
        stop()
    }

    func start() throws -> String {
        if webServer.isRunning, let urlString {
            return urlString
        }

        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: 0,
                GCDWebServerOption_BindToLocalhost: false,
                GCDWebServerOption_AutomaticallySuspendInBackground: false
            ])
            let host = Self.wifiAddress()
            let address = host.map { "http://\($0):\(webServer.port)" } ?? webServer.serverURL?.absoluteString ?? "http://127.0.0.1:\(webServer.port)"
            urlString = address
            return address
        } catch {
            throw NSError(
                domain: "SandboxSQLiteWebServer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Start web server failed: \(error.localizedDescription)"]
            )
        }
    }

    func stop() {
        if webServer.isRunning {
            webServer.stop()
        }
        urlString = nil
    }

    private func registerHandlers() {
        webServer.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self) { [weak self] _ in
            guard let self else {
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            return self.htmlResponse()
        }

        webServer.addHandler(forMethod: "GET", path: "/api/tables", request: GCDWebServerRequest.self) { [weak self] _ in
            guard let self else {
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            do {
                let reader = SandboxSQLiteDatabaseReader(fileURL: self.fileURL)
                let tables = try reader.tables()
                return self.jsonResponse(["tables": tables])
            } catch {
                return self.errorResponse(error)
            }
        }

        webServer.addHandler(forMethod: "GET", path: "/api/schema", request: GCDWebServerRequest.self) { [weak self] request in
            guard let self else {
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            guard let table = self.queryValue("table", request: request), !table.isEmpty else {
                return self.jsonResponse(["error": "Missing table"], statusCode: 400)
            }
            do {
                let reader = SandboxSQLiteDatabaseReader(fileURL: self.fileURL)
                let schema = try reader.schema(for: table).map { column in
                    [
                        "cid": column.cid,
                        "name": column.name,
                        "type": column.type,
                        "notNull": column.isNotNull,
                        "defaultValue": column.defaultValue ?? NSNull(),
                        "primaryKey": column.isPrimaryKey
                    ] as [String: Any]
                }
                return self.jsonResponse(["schema": schema])
            } catch {
                return self.errorResponse(error)
            }
        }

        webServer.addHandler(forMethod: "GET", path: "/api/rows", request: GCDWebServerRequest.self) { [weak self] request in
            guard let self else {
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            guard let table = self.queryValue("table", request: request), !table.isEmpty else {
                return self.jsonResponse(["error": "Missing table"], statusCode: 400)
            }
            let page = Int(self.queryValue("page", request: request) ?? "") ?? 0
            let pageSize = min(max(Int(self.queryValue("pageSize", request: request) ?? "") ?? 100, 1), 500)
            let keyword = self.queryValue("q", request: request)
            do {
                let reader = SandboxSQLiteDatabaseReader(fileURL: self.fileURL)
                let rows = try reader.rows(for: table, page: page, pageSize: pageSize, keyword: keyword)
                let count = try reader.rowCount(for: table, keyword: keyword)
                return self.jsonResponse([
                    "table": table,
                    "page": page,
                    "pageSize": pageSize,
                    "total": count,
                    "keyword": keyword ?? "",
                    "columns": rows.columns,
                    "rows": rows.rows,
                    "rowIDs": rows.rowIDs.map { $0.map { NSNumber(value: $0) } ?? NSNull() }
                ])
            } catch {
                return self.errorResponse(error)
            }
        }

        webServer.addHandler(forMethod: "POST", path: "/api/update", request: GCDWebServerDataRequest.self) { [weak self] request in
            guard let self else {
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            guard let dataRequest = request as? GCDWebServerDataRequest,
                  let object = try? JSONSerialization.jsonObject(with: dataRequest.data, options: []),
                  let body = object as? [String: Any],
                  let table = body["table"] as? String,
                  let column = body["column"] as? String,
                  let rowIDNumber = body["rowID"] as? NSNumber else {
                return self.jsonResponse(["error": "Invalid update body"], statusCode: 400)
            }

            let isNull = (body["isNull"] as? Bool) ?? false
            let value = isNull ? nil : (body["value"] as? String ?? "")
            do {
                let reader = SandboxSQLiteDatabaseReader(fileURL: self.fileURL)
                try reader.updateValue(tableName: table, columnName: column, rowID: rowIDNumber.int64Value, value: value)
                return self.jsonResponse(["ok": true])
            } catch {
                return self.errorResponse(error)
            }
        }
    }

    private func htmlResponse() -> GCDWebServerResponse {
        let html = SandboxSQLiteHTMLRenderer.webBrowserPage()
        guard let response = GCDWebServerDataResponse(html: html) else {
            return GCDWebServerErrorResponse(statusCode: 500)
        }
        response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
        return response
    }

    private func jsonResponse(_ object: [String: Any], statusCode: Int = 200) -> GCDWebServerResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object, options: [])) ?? Data()
        let response = GCDWebServerDataResponse(data: data, contentType: "application/json; charset=utf-8")
        response.statusCode = statusCode
        response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
        return response
    }

    private func errorResponse(_ error: Error) -> GCDWebServerResponse {
        jsonResponse(["error": error.localizedDescription], statusCode: 500)
    }

    private func queryValue(_ key: String, request: GCDWebServerRequest) -> String? {
        request.query?[key] as? String
    }

    private static func wifiAddress() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var pointer = interfaces
        while pointer != nil {
            guard let interface = pointer?.pointee else {
                break
            }
            let name = String(cString: interface.ifa_name)
            let family = interface.ifa_addr.pointee.sa_family
            if name == "en0", family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                address = String(cString: hostname)
                break
            }
            pointer = interface.ifa_next
        }
        return address
    }
}
