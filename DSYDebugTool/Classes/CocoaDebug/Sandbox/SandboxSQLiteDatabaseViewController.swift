import UIKit
import WebKit

@objc(SandboxSQLiteDatabaseViewController)
final class SandboxSQLiteDatabaseViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, WKScriptMessageHandler {
    private let fileURL: URL
    private let pageSize = 100
    private var reader: SandboxSQLiteDatabaseReader?
    private var webServer: SandboxSQLiteWebServer?
    private var tables: [String] = []
    private var selectedTable: String?
    private var rowPage = SandboxSQLiteRows(columns: [], rows: [], rowIDs: [])
    private var totalRows = 0
    private var page = 0
    private var message: String?
    private var keyword: String?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private lazy var webView: WKWebView = {
        let contentController = WKUserContentController()
        contentController.add(self, name: "sqliteEdit")
        contentController.add(self, name: "sqliteCopyRow")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    private let toolbar = UIStackView()
    private let pageLabel = UILabel()
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    private let searchBar = UISearchBar(frame: .zero)

    @objc(initWithFileURL:)
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sqliteEdit")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "sqliteCopyRow")
        webServer?.stop()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = fileURL.deletingPathExtension().lastPathComponent
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Web", style: .plain, target: self, action: #selector(startWebBrowsing)),
            UIBarButtonItem(title: "Tables", style: .plain, target: self, action: #selector(showTables))
        ]
        setupViews()
        loadTables()
    }

    private func setupViews() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 10
        toolbar.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        toolbar.isLayoutMarginsRelativeArrangement = true
        toolbar.isHidden = true
        view.addSubview(toolbar)

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "搜索当前表"
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.showsCancelButton = true
        searchBar.isHidden = true
        view.addSubview(searchBar)

        previousButton.setTitle("Previous", for: .normal)
        previousButton.addTarget(self, action: #selector(previousPage), for: .touchUpInside)
        nextButton.setTitle("Next", for: .normal)
        nextButton.addTarget(self, action: #selector(nextPage), for: .touchUpInside)
        pageLabel.font = .systemFont(ofSize: 13)
        pageLabel.textColor = .secondaryLabel
        pageLabel.textAlignment = .center
        pageLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        toolbar.addArrangedSubview(previousButton)
        toolbar.addArrangedSubview(pageLabel)
        toolbar.addArrangedSubview(nextButton)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isHidden = true
        webView.scrollView.alwaysBounceVertical = true
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 48),

            searchBar.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 52),

            webView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadTables() {
        do {
            let reader = SandboxSQLiteDatabaseReader(fileURL: fileURL)
            try reader.open()
            self.reader = reader
            tables = try reader.tables()
            if tables.isEmpty {
                showMessage("No tables")
            } else {
                message = nil
                showTableList()
            }
        } catch {
            showMessage(error.localizedDescription)
        }
    }

    private func showTableList() {
        toolbar.isHidden = true
        searchBar.isHidden = true
        webView.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
    }

    @objc private func showTables() {
        showTableList()
    }

    private func showMessage(_ message: String) {
        self.message = message
        toolbar.isHidden = true
        searchBar.isHidden = true
        webView.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
    }

    private func loadRows(table: String, page: Int) {
        do {
            let reader = self.reader ?? SandboxSQLiteDatabaseReader(fileURL: fileURL)
            self.reader = reader
            try reader.open()
            selectedTable = table
            totalRows = try reader.rowCount(for: table, keyword: keyword)
            rowPage = try reader.rows(for: table, page: page, pageSize: pageSize, keyword: keyword)
            self.page = max(0, page)
            renderCurrentPage()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func renderCurrentPage() {
        guard let selectedTable else {
            return
        }

        tableView.isHidden = true
        toolbar.isHidden = false
        searchBar.isHidden = false
        webView.isHidden = false

        let totalPages = max(1, Int(ceil(Double(totalRows) / Double(pageSize))))
        pageLabel.text = "Page \(page + 1) / \(totalPages)"
        previousButton.isEnabled = page > 0
        nextButton.isEnabled = (page + 1) * pageSize < totalRows

        let html = SandboxSQLiteHTMLRenderer.localTablePage(
            tableName: selectedTable,
            totalRows: totalRows,
            page: page,
            pageSize: pageSize,
            rows: rowPage
        )
        webView.loadHTMLString(html, baseURL: nil)
    }

    @objc private func startWebBrowsing() {
        do {
            let server = webServer ?? SandboxSQLiteWebServer(fileURL: fileURL)
            webServer = server
            let address = try server.start()
            let message = "\(address)\n\nUse a browser on the same Wi-Fi network. The port is assigned by the device to avoid local port conflicts."
            let alert = UIAlertController(title: "Computer Browsing", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Copy", style: .default, handler: { _ in
                UIPasteboard.general.string = address
            }))
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            present(alert, animated: true)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showError(_ text: String) {
        let alert = UIAlertController(title: "SQLite Browser", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        applySearch(searchBar.text)
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        applySearch(nil)
        searchBar.resignFirstResponder()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            applySearch(nil)
        }
    }

    private func applySearch(_ text: String?) {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        keyword = trimmed.isEmpty ? nil : trimmed
        guard let selectedTable else {
            return
        }
        loadRows(table: selectedTable, page: 0)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "sqliteCopyRow",
           let body = message.body as? [String: Any],
           let row = body["row"] as? String {
            UIPasteboard.general.string = row
            showToast("已复制当前行数据")
            return
        }

        guard message.name == "sqliteEdit",
              let body = message.body as? [String: Any],
              let rowIDText = body["rowID"] as? String,
              let rowID = Int64(rowIDText),
              let column = body["column"] as? String else {
            return
        }
        let value = body["value"] as? String ?? ""
        showEditAlert(rowID: rowID, column: column, value: value)
    }

    private func showToast(_ text: String) {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.alpha = 0
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            label.heightAnchor.constraint(equalToConstant: 40)
        ])

        UIView.animate(withDuration: 0.18, animations: {
            label.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 1.0, options: [], animations: {
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        })
    }

    private func showEditAlert(rowID: Int64, column: String, value: String) {
        guard let selectedTable else {
            return
        }

        let alert = UIAlertController(
            title: "修改 \(column)",
            message: "表: \(selectedTable)\n输入 NULL 将写入数据库 NULL",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.text = value == "NULL" ? "" : value
            textField.placeholder = "输入新值，或输入 NULL"
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default, handler: { [weak self, weak alert] _ in
            guard let self else {
                return
            }
            let text = alert?.textFields?.first?.text ?? ""
            let newValue: String? = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "NULL" ? nil : text
            do {
                try self.reader?.updateValue(tableName: selectedTable, columnName: column, rowID: rowID, value: newValue)
                self.loadRows(table: selectedTable, page: self.page)
            } catch {
                self.showError(error.localizedDescription)
            }
        }))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if message != nil {
            return 1
        }
        return tables.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Tables"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = message ?? tables[indexPath.row]
        cell.textLabel?.numberOfLines = 1
        cell.selectionStyle = message == nil ? .default : .none
        cell.accessoryType = message == nil && selectedTable == tables[indexPath.row] ? .checkmark : (message == nil ? .disclosureIndicator : .none)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard message == nil, !tables.isEmpty else {
            return
        }
        keyword = nil
        searchBar.text = nil
        loadRows(table: tables[indexPath.row], page: 0)
    }

    @objc private func previousPage() {
        guard let selectedTable else {
            return
        }
        loadRows(table: selectedTable, page: max(0, page - 1))
    }

    @objc private func nextPage() {
        guard let selectedTable else {
            return
        }
        loadRows(table: selectedTable, page: page + 1)
    }
}
