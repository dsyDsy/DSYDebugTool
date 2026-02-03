//
//  DebugFileTransferServer.swift
//  Reelrush
//
//  Created by code on 2026/1/21.
//

import UIKit
import Foundation
// MARK: - 文件传输服务器
import GCDWebServer

public class DebugFileTransferServer: NSObject {
    public static let shared = DebugFileTransferServer()
    public   var serverPort: UInt = 8080

    private var webServer: GCDWebServer?
    public  private(set) var isRunning = false
   
    private var  appDisplayName =   Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
  
    private var uploadedFiles: [(name: String, data: Data, uploadTime: Date)] = []
    
    override init() {
        super.init()
    }
    
    public func startServer(completion: @escaping (Bool, String?) -> Void) {
        guard !isRunning else {
            completion(true, getCompleteAddress())
            return
        }
        
        webServer = GCDWebServer()
        
        // 添加主页处理
        webServer?.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request in
            print("web_test📥 收到GET请求: \(request.path)")
            return self?.handleMainPage() ?? GCDWebServerErrorResponse(statusCode: 500)
        }
        
        // 添加文件下载处理
        webServer?.addHandler(forMethod: "GET", pathRegex: "^/download/(\\d+)$", request: GCDWebServerRequest.self) { [weak self] request in
            print("web_test📥 收到下载请求: \(request.path)")
            
            guard let self = self else {
                print("web_test❌ self为nil")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            
            // 从路径中提取文件索引
            let pathComponents = request.path.components(separatedBy: "/")
            print("web_test🔍 路径组件: \(pathComponents)")
            
            guard pathComponents.count >= 3,
                  let index = Int(pathComponents[2]),
                  index < self.uploadedFiles.count else {
                print("web_test❌ 无效的文件索引: \(pathComponents)")
                return GCDWebServerErrorResponse(statusCode: 404)
            }
            
            print("web_test✅ 找到文件索引: \(index)")
            let file = self.uploadedFiles[index]
            return self.createFileDownloadResponse(fileName: file.name, fileData: file.data)
        }
        
        // 启动服务器
        do {
            try webServer?.start(options: [
                GCDWebServerOption_Port: serverPort,
                GCDWebServerOption_BindToLocalhost: false,
                GCDWebServerOption_AutomaticallySuspendInBackground: false,
                GCDWebServerOption_ConnectedStateCoalescingInterval: 2.0
            ])
            
            isRunning = true
            let ipAddress = getWiFiAddress() ?? "未知IP"
            
            print("web_test📡 GCDWebServer 已启动: http://\(ipAddress):\(serverPort)")
            print("web_test📡 服务器配置:")
            print("web_test   - 端口: \(serverPort)")
            print("web_test   - 绑定到localhost: false")
            print("web_test   - 后台运行: true")
            
            completion(true, getCompleteAddress())
            
        } catch {
            print("web_test❌ 启动 GCDWebServer 失败: \(error)")
            isRunning = false
            completion(false, nil)
        }
    }
    
    public func stopServer() {
        guard isRunning else { return }
        
        webServer?.stop()
        webServer = nil
        isRunning = false
        uploadedFiles.removeAll()
        
        print("web_test📡 GCDWebServer 已停止")
    }
    
    func uploadFile(name: String, data: Data) {
        let fileInfo = (name: name, data: data, uploadTime: Date())
        uploadedFiles.append(fileInfo)
        
        print("web_test📤 文件已上传: \(name)")
        print("web_test📤 文件大小: \(data.count) bytes")
        print("web_test📤 当前文件总数: \(uploadedFiles.count)")
        
        // 验证数据完整性
        if data.isEmpty {
            print("web_test⚠️ 警告: 上传的文件数据为空!")
        } else {
            print("web_test✅ 文件数据正常，前10字节: \(data.prefix(10).map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
    }
    
    private func handleMainPage() -> GCDWebServerResponse {
        let htmlContent = createUploadPageHTML()
        
        guard let response = GCDWebServerDataResponse(html: htmlContent) else {
            print("web_test❌ 无法创建HTML响应")
            return GCDWebServerErrorResponse(statusCode: 500)
        }
        
        print("web_test✅ HTML页面响应创建成功")
        return response
    }
    
    private func createFileDownloadResponse(fileName: String, fileData: Data) -> GCDWebServerResponse {
        // 根据文件扩展名确定Content-Type
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let contentType: String
        
        switch fileExtension {
        case "jpg", "jpeg":
            contentType = "image/jpeg"
        case "png":
            contentType = "image/png"
        case "gif":
            contentType = "image/gif"
        case "mp4":
            contentType = "video/mp4"
        case "mov":
            contentType = "video/quicktime"
        case "txt":
            contentType = "text/plain; charset=utf-8"
        case "pdf":
            contentType = "application/pdf"
        case "json":
            contentType = "application/json"
        default:
            contentType = "application/octet-stream"
        }
        
        print("web_test📤 创建文件下载响应:")
        print("web_test   文件名: \(fileName)")
        print("web_test   Content-Type: \(contentType)")
        print("web_test   文件大小: \(fileData.count) bytes")
        
        // 验证文件数据
        if fileData.isEmpty {
            print("web_test❌ 文件数据为空，返回404")
            return GCDWebServerErrorResponse(statusCode: 404)
        }
        
        let response = GCDWebServerDataResponse(data: fileData, contentType: contentType)
        
        // 设置下载文件名 - 使用简单编码避免问题
        let safeFileName = fileName.replacingOccurrences(of: " ", with: "_")
                                  .replacingOccurrences(of: ",", with: "_")
                                  .replacingOccurrences(of: ":", with: "_")
        response.setValue("attachment; filename=\"\(safeFileName)\"", forAdditionalHeader: "Content-Disposition")
        
        // 添加缓存控制
        response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
        
        print("web_test✅ 文件下载响应创建成功，安全文件名: \(safeFileName)")
        
        return response
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    

    
    private func createUploadPageHTML() -> String {
        // 按上传时间倒序排列文件（最新的在最上面）
        let sortedFiles = uploadedFiles.enumerated().sorted { (first, second) in
            return first.element.uploadTime > second.element.uploadTime
        }
        
        let fileListHTML:String = sortedFiles.map { originalIndex, file in
            let sizeStr = formatFileSize(file.data.count)
            let timeStr = DateFormatter.localizedString(from: file.uploadTime, dateStyle: .short, timeStyle: .medium)
            return """
            <div class="file-item">
                <div class="file-info">
                    <span class="file-name">📄 \(file.name)</span>
                    <span class="file-details">\(sizeStr) • \(timeStr)</span>
                </div>
                <a href="/download/\(originalIndex)" class="download-btn" download="\(file.name)">下载</a>
            </div>
            """
        }.joined()
        
        let htmlContent:String = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title> \(appDisplayName) 文件传输 - 接收文件</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; }
                .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); }
                h1 { color: #333; text-align: center; margin-bottom: 30px; font-size: 28px; }
                .info { background: linear-gradient(45deg, #e3f2fd, #f3e5f5); padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #007AFF; }
                .file-list { margin-top: 30px; }
                .file-item { background: #f8f9fa; padding: 15px; margin: 10px 0; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; border: 1px solid #e9ecef; }
                .file-info { flex: 1; }
                .file-name { display: block; font-weight: 600; color: #333; margin-bottom: 5px; }
                .file-details { font-size: 14px; color: #666; }
                .download-btn { background: linear-gradient(45deg, #28a745, #20c997); color: white; text-decoration: none; padding: 8px 16px; border-radius: 20px; font-weight: 600; transition: all 0.3s ease; }
                .download-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(40,167,69,0.4); }
                .empty-state { text-align: center; padding: 60px 20px; color: #666; }
                .empty-state .emoji { font-size: 48px; margin-bottom: 20px; }
                .refresh-btn { background: linear-gradient(45deg, #007AFF, #0056CC); color: white; border: none; padding: 10px 20px; border-radius: 20px; cursor: pointer; font-weight: 600; transition: all 0.3s ease; }
                .refresh-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,122,255,0.4); }
                .stats-container { display: flex; justify-content: space-between; align-items: center; background: #f8f9fa; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .stats { display: flex; gap: 40px; }
                .stat-item { text-align: center; }
                .stat-number { font-size: 24px; font-weight: bold; color: #007AFF; }
                .stat-label { font-size: 14px; color: #666; margin-top: 5px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📱 \(appDisplayName) 文件接收站</h1>
                
                <div class="info">
                    <strong>📋 使用说明：</strong><br>
                    • 此页面用于接收从\(appDisplayName)应用发送的文件<br>
                    • 文件会实时显示在下方列表中<br>
                    • 点击下载按钮可保存文件到电脑<br>
                    • 页面会自动刷新显示新文件
                </div>
                
                <div class="stats-container">
                    <div class="stats">
                        <div class="stat-item">
                            <div class="stat-number">\(uploadedFiles.count)</div>
                            <div class="stat-label">文件总数</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number">\(formatFileSize(uploadedFiles.reduce(0) { $0 + $1.data.count }))</div>
                            <div class="stat-label">总大小</div>
                        </div>
                    </div>
                    <button class="refresh-btn" onclick="location.reload()">🔄 刷新页面</button>
                </div>
                
                <div class="file-list">
                    \(uploadedFiles.isEmpty ? """
                    <div class="empty-state">
                        <div class="emoji">📭</div>
                        <h3>暂无文件</h3>
                        <p>请在\(appDisplayName)应用中上传文件，文件会自动显示在这里</p>
                    </div>
                    """ : fileListHTML)
                </div>
                
                <div class="info" style="margin-top: 30px;">
                    <strong>💡 提示：</strong><br>
                    • 页面每30秒自动刷新一次<br>
                    • 也可以手动刷新查看新文件<br>
                    • 文件按上传时间倒序排列（最新的在最上面）
                </div>
            </div>
            
            <script>
                // 每30秒自动刷新页面
                setTimeout(() => {
                    location.reload();
                }, 30000);
                
                // 添加下载统计
                document.querySelectorAll('.download-btn').forEach(btn => {
                    btn.addEventListener('click', () => {
                        console.log('文件下载:', btn.getAttribute('download'));
                    });
                });
            </script>
        </body>
        </html>
        """
        
        return htmlContent
    }
    
    func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                let name = String(cString: interface.ifa_name)
                if name == "en0" { // WiFi interface
                    
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
  public  func getCompleteAddress() -> String? {
        if let ip = getWiFiAddress() {
           return "http://\(ip):\(DebugFileTransferServer.shared.serverPort)"
        }
        
        return nil
    }
}



