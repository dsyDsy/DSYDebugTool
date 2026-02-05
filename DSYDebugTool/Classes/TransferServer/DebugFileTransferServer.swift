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
    public var serverPort: UInt = 8080
    
    /// Debug 开关，控制是否输出日志
    public var isDebugEnabled: Bool = true
    
    /// 端口被占用时，自动顺延尝试的次数（例如 20 表示最多尝试 `serverPort...serverPort+20`）
    public var portAutoRetryCount: UInt = 20

    private var webServer: GCDWebServer?
    public private(set) var isRunning = false
   
    private var appDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
  
    private var uploadedFiles: [(name: String, data: Data, uploadTime: Date)] = []
    
    override init() {
        super.init()
    }
    
    // MARK: - 日志输出方法
    public func log<T>(_ message: T,
                    file : StaticString = #file,
                    method: StaticString = #function,
                    lineNumber : UInt = #line) {
        guard isDebugEnabled else { return }
        print("[文件传输助手][\((file.description as NSString).lastPathComponent): \(method) line:\(lineNumber)]---> \(message)")
    }
    
    private func isPortInUseError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // POSIX: EADDRINUSE = 48
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == 48 {
            return true
        }
        let desc = nsError.localizedDescription.lowercased()
        if desc.contains("address already in use") || desc.contains("eaddrinuse") || desc.contains("port") && desc.contains("in use") {
            return true
        }
        return false
    }
    
    public func startServer(completion: @escaping (Bool, String?) -> Void) {
        guard !isRunning else {
            completion(true, getCompleteAddress())
            return
        }
        
        webServer = GCDWebServer()
        
        // 添加文件下载处理（必须在默认处理器之前）
        webServer?.addHandler(forMethod: "GET", pathRegex: "^/download/(\\d+)$", request: GCDWebServerRequest.self) { [weak self] request in
            DebugFileTransferServer.shared.log("📥 收到下载请求: \(request.path)")
            
            guard let self = self else {
                DebugFileTransferServer.shared.log("❌ self为nil")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            
            // 从路径中提取文件索引
            let pathComponents = request.path.components(separatedBy: "/")
            DebugFileTransferServer.shared.log("🔍 路径组件: \(pathComponents)")
            DebugFileTransferServer.shared.log("📊 当前文件总数: \(self.uploadedFiles.count)")
            
            guard pathComponents.count >= 3,
                  let index = Int(pathComponents[2]) else {
                DebugFileTransferServer.shared.log("❌ 无法解析文件索引: \(pathComponents)")
                return GCDWebServerErrorResponse(statusCode: 404)
            }
            
            DebugFileTransferServer.shared.log("🔢 请求的文件索引: \(index)")
            
            guard index >= 0, index < self.uploadedFiles.count else {
                DebugFileTransferServer.shared.log("❌ 文件索引超出范围: \(index), 文件总数: \(self.uploadedFiles.count)")
                return GCDWebServerErrorResponse(statusCode: 404)
            }
            
            DebugFileTransferServer.shared.log("✅ 找到文件索引: \(index)")
            let file = self.uploadedFiles[index]
            DebugFileTransferServer.shared.log("📄 文件名: \(file.name)")
            return self.createFileDownloadResponse(fileName: file.name, fileData: file.data)
        }
        
        // 添加文件预览处理（必须在默认处理器之前）
        webServer?.addHandler(forMethod: "GET", pathRegex: "^/preview/(\\d+)$", request: GCDWebServerRequest.self) { [weak self] request in
            DebugFileTransferServer.shared.log("📥 收到预览请求: \(request.path)")
            
            guard let self = self else {
                DebugFileTransferServer.shared.log("❌ self为nil")
                return GCDWebServerErrorResponse(statusCode: 500)
            }
            
            // 从路径中提取文件索引
            let pathComponents = request.path.components(separatedBy: "/")
            DebugFileTransferServer.shared.log("🔍 预览路径组件: \(pathComponents)")
            DebugFileTransferServer.shared.log("📊 当前文件总数: \(self.uploadedFiles.count)")
            
            guard pathComponents.count >= 3,
                  let index = Int(pathComponents[2]) else {
                DebugFileTransferServer.shared.log("❌ 无法解析文件索引: \(pathComponents)")
                return GCDWebServerErrorResponse(statusCode: 404)
            }
            
            DebugFileTransferServer.shared.log("🔢 请求的预览文件索引: \(index)")
            
            guard index >= 0, index < self.uploadedFiles.count else {
                DebugFileTransferServer.shared.log("❌ 预览文件索引超出范围: \(index), 文件总数: \(self.uploadedFiles.count)")
                return GCDWebServerErrorResponse(statusCode: 404)
            }
            
            DebugFileTransferServer.shared.log("✅ 找到预览文件索引: \(index)")
            let file = self.uploadedFiles[index]
            DebugFileTransferServer.shared.log("📄 预览文件名: \(file.name)")
            DebugFileTransferServer.shared.log("📊 预览文件数据大小: \(file.data.count) bytes")
            if file.data.count > 0 {
                DebugFileTransferServer.shared.log("📝 预览文件数据前20字节: \(file.data.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
            return self.createFilePreviewResponse(fileName: file.name, fileData: file.data)
        }
        
        // 添加主页处理（只匹配根路径，必须最后注册）
        webServer?.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self) { [weak self] request in
            DebugFileTransferServer.shared.log("📥 收到GET请求（主页）: \(request.path)")
            return self?.handleMainPage() ?? GCDWebServerErrorResponse(statusCode: 500)
        }
        
        // 启动服务器（端口占用时自动顺延）
        let basePort = serverPort
        let maxTry = portAutoRetryCount
        var lastError: Error?
        
        for offset in 0...maxTry {
            let tryPort = basePort + offset
            do {
                try webServer?.start(options: [
                    GCDWebServerOption_Port: tryPort,
                    GCDWebServerOption_BindToLocalhost: false,
                    GCDWebServerOption_AutomaticallySuspendInBackground: false,
                    GCDWebServerOption_ConnectedStateCoalescingInterval: 2.0
                ])
                
                // 成功：回写实际端口
                serverPort = tryPort
                isRunning = true
                
                let ipAddress = getWiFiAddress() ?? "未知IP"
                DebugFileTransferServer.shared.log("📡 GCDWebServer 已启动: http://\(ipAddress):\(serverPort)")
                DebugFileTransferServer.shared.log("📡 服务器配置:")
                DebugFileTransferServer.shared.log("   - 端口: \(serverPort)")
                DebugFileTransferServer.shared.log("   - 绑定到localhost: false")
                DebugFileTransferServer.shared.log("   - 后台运行: true")
                
                completion(true, getCompleteAddress())
                return
            } catch {
                lastError = error
                if isPortInUseError(error), offset < maxTry {
                    DebugFileTransferServer.shared.log("⚠️ 端口 \(tryPort) 被占用，尝试下一个端口...")
                    continue
                } else {
                    break
                }
            }
        }
        
        DebugFileTransferServer.shared.log("❌ 启动 GCDWebServer 失败（已尝试 \(maxTry + 1) 个端口，从 \(basePort) 起）: \(String(describing: lastError))")
        isRunning = false
        completion(false, nil)
    }
    
    public func stopServer() {
        guard isRunning else { return }
        
        webServer?.stop()
        webServer = nil
        isRunning = false
        uploadedFiles.removeAll()
        
        log("📡 GCDWebServer 已停止")
    }
    
    func textName()->String{
        return "文字内容_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)).txt"
    }
    
    func imageName()->String{
        return "图片_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)).jpg"
    }
    
    
   public func uploadTextContent(_ text:String,call:((String,Data)->())? = nil){
        let fileName =  self.textName()
        let textData = text.data(using: .utf8) ?? Data()
        log("📝 上传文字内容: \(text)")
        log("📝 文件名: \(fileName)")
        log("📝 数据大小: \(textData.count)")
        uploadFile(name: fileName, data: textData)
        call?(fileName,textData)
    }
    
    public func uploadImageContent(_ image:UIImage,call:((String,Data)->())? = nil){
        let fileName =  DebugFileTransferServer.shared.imageName()
        if  let fileData =  image.jpegData(compressionQuality: 1) {
            uploadFile(name: fileName, data: fileData )
        }else{
            log("📝 数据处理失败")
        }
       
     }
    
    public func uploadFile(name: String, data: Data) {
        // 显式复制数据，确保数据不会被意外修改
        let dataCopy = Data(data)
        let fileInfo = (name: name, data: dataCopy, uploadTime: Date())
        let indexBeforeAppend = uploadedFiles.count
        uploadedFiles.append(fileInfo)
        let indexAfterAppend = uploadedFiles.count - 1
        
        log("📤 当前队列数据: \(indexBeforeAppend) 个")
        log("📤 文件已上传: \(name)")
        log("📤 原始数据大小: \(data.count) bytes")
        log("📤 复制后数据大小: \(dataCopy.count) bytes")
        log("📤 当前文件总数: \(uploadedFiles.count)")
        log("📤 文件索引: \(indexAfterAppend)")
        
        // 验证数据完整性
        if dataCopy.isEmpty {
            log("⚠️ 警告: 上传的文件数据为空!")
        } else {
            log("✅ 文件数据正常，前10字节: \(dataCopy.prefix(10).map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
        
        // 验证存储后的数据
        if indexAfterAppend < uploadedFiles.count {
            let storedFile = uploadedFiles[indexAfterAppend]
            log("🔍 验证存储 - 索引: \(indexAfterAppend), 存储的文件名: \(storedFile.name), 存储的数据大小: \(storedFile.data.count) bytes")
            if storedFile.data.count != dataCopy.count {
                log("❌ 数据大小不匹配! 复制后: \(dataCopy.count) bytes, 存储: \(storedFile.data.count) bytes")
            } else {
                log("✅ 数据存储验证通过")
            }
        }
    }
    
    private func handleMainPage() -> GCDWebServerResponse {
        let htmlContent = createUploadPageHTML()
        
        guard let response = GCDWebServerDataResponse(html: htmlContent) else {
            log("❌ 无法创建HTML响应")
            return GCDWebServerErrorResponse(statusCode: 500)
        }
        
        log("✅ HTML页面响应创建成功")
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
        
        log("📤 创建文件下载响应:")
        log("   文件名: \(fileName)")
        log("   Content-Type: \(contentType)")
        log("   文件大小: \(fileData.count) bytes")
        
        // 即使文件为空也允许下载（下载空文件）
        if fileData.isEmpty {
            log("⚠️ 文件数据为空，但允许下载（空文件）")
        }
        
        let response = GCDWebServerDataResponse(data: fileData, contentType: contentType)
        
        // 设置下载文件名 - 使用简单编码避免问题
        let safeFileName = fileName.replacingOccurrences(of: " ", with: "_")
                                  .replacingOccurrences(of: ",", with: "_")
                                  .replacingOccurrences(of: ":", with: "_")
        response.setValue("attachment; filename=\"\(safeFileName)\"", forAdditionalHeader: "Content-Disposition")
        
        // 添加缓存控制
        response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
        
        log("✅ 文件下载响应创建成功，安全文件名: \(safeFileName)")
        
        return response
    }
    
    private func createFilePreviewResponse(fileName: String, fileData: Data) -> GCDWebServerResponse {
        // 根据文件扩展名确定Content-Type和预览方式
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
            contentType = "application/json; charset=utf-8"
        default:
            contentType = "application/octet-stream"
        }
        
        log("👁️ 创建文件预览响应:")
        log("   文件名: \(fileName)")
        log("   Content-Type: \(contentType)")
        log("   文件大小: \(fileData.count) bytes")
        
        // 对于文本文件，即使为空也允许预览（显示空内容）
        // 对于其他类型的文件，如果为空则返回404
        if fileData.isEmpty {
            let textExtensions = ["txt", "json"]
            if textExtensions.contains(fileExtension) {
                log("⚠️ 文件数据为空，但允许预览（文本文件）")
                // 返回空字符串的响应
                let emptyData = Data()
                let response = GCDWebServerDataResponse(data: emptyData, contentType: contentType)
                response.setValue("inline", forAdditionalHeader: "Content-Disposition")
                response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
                return response
            } else {
                log("❌ 文件数据为空，返回404")
                return GCDWebServerErrorResponse(statusCode: 404)
            }
        }
        
        let response = GCDWebServerDataResponse(data: fileData, contentType: contentType)
        
        // 预览时使用 inline，而不是 attachment
        response.setValue("inline", forAdditionalHeader: "Content-Disposition")
        
        // 添加缓存控制
        response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
        
        log("✅ 文件预览响应创建成功")
        
        return response
    }
    
    private func canPreviewFile(_ fileName: String) -> Bool {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        let previewableExtensions = ["jpg", "jpeg", "png", "gif", "mp4", "mov", "txt", "pdf", "json"]
        return previewableExtensions.contains(fileExtension)
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
            let canPreview = canPreviewFile(file.name)
            // 调试日志：检查文件数据
            log("📋 生成文件列表项 - 索引: \(originalIndex), 文件名: \(file.name), 数据大小: \(file.data.count) bytes")
            // 转义文件名中的特殊字符，用于 JavaScript
            let escapedFileName = file.name.replacingOccurrences(of: "\\", with: "\\\\")
                                           .replacingOccurrences(of: "'", with: "\\'")
                                           .replacingOccurrences(of: "\"", with: "\\\"")
                                           .replacingOccurrences(of: "\n", with: "\\n")
                                           .replacingOccurrences(of: "\r", with: "\\r")
            let previewBtn = canPreview ? """
                <button onclick="previewFile(\(originalIndex), '\(escapedFileName)')" class="preview-btn">👁️ 预览</button>
            """ : ""
            return """
            <div class="file-item">
                <div class="file-info">
                    <span class="file-name">📄 \(file.name)</span>
                    <span class="file-details">\(sizeStr) • \(timeStr)</span>
                </div>
                <div class="file-actions">
                    \(previewBtn)
                    <a href="/download/\(originalIndex)" class="download-btn" download="\(file.name)">下载</a>
                </div>
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
                .file-actions { display: flex; gap: 10px; align-items: center; }
                .preview-btn { background: linear-gradient(45deg, #007AFF, #0056CC); color: white; border: none; padding: 8px 16px; border-radius: 20px; font-weight: 600; cursor: pointer; transition: all 0.3s ease; }
                .preview-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,122,255,0.4); }
                .download-btn { background: linear-gradient(45deg, #28a745, #20c997); color: white; text-decoration: none; padding: 8px 16px; border-radius: 20px; font-weight: 600; transition: all 0.3s ease; }
                .download-btn:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(40,167,69,0.4); }
                /* 预览模态框样式 */
                .preview-modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.9); overflow: auto; }
                .preview-modal.active { display: flex; align-items: center; justify-content: center; }
                .preview-content { position: relative; max-width: 90%; max-height: 90%; margin: auto; background: #fff; border-radius: 12px; padding: 20px; box-shadow: 0 10px 40px rgba(0,0,0,0.5); }
                .preview-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 2px solid #e9ecef; }
                .preview-title { font-size: 20px; font-weight: 600; color: #333; margin: 0; }
                .preview-close { background: #dc3545; color: white; border: none; padding: 8px 16px; border-radius: 8px; cursor: pointer; font-size: 18px; font-weight: bold; transition: all 0.3s ease; }
                .preview-close:hover { background: #c82333; transform: scale(1.05); }
                .preview-body { max-height: 70vh; overflow: auto; }
                .preview-image { max-width: 100%; max-height: 70vh; display: block; margin: 0 auto; border-radius: 8px; }
                .preview-video { max-width: 100%; max-height: 70vh; display: block; margin: 0 auto; border-radius: 8px; }
                .preview-text { background: #f8f9fa; padding: 20px; border-radius: 8px; font-family: 'Courier New', monospace; font-size: 14px; line-height: 1.6; white-space: pre-wrap; word-wrap: break-word; max-height: 70vh; overflow: auto; }
                .preview-pdf { width: 100%; height: 70vh; border: none; border-radius: 8px; }
                .preview-unsupported { text-align: center; padding: 40px; color: #666; }
                .preview-unsupported .emoji { font-size: 48px; margin-bottom: 20px; }
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
                    • 点击预览按钮可在线查看文件（支持图片、视频、文本、PDF等）<br>
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
                    • 文件按上传时间倒序排列（最新的在最上面）<br>
                    • 支持预览图片、视频、文本、PDF等文件
                </div>
            </div>
            
            <!-- 预览模态框 -->
            <div id="previewModal" class="preview-modal">
                <div class="preview-content">
                    <div class="preview-header">
                        <h2 class="preview-title" id="previewTitle">文件预览</h2>
                        <button class="preview-close" onclick="closePreview()">&times; 关闭</button>
                    </div>
                    <div class="preview-body" id="previewBody">
                        <!-- 预览内容将动态加载到这里 -->
                    </div>
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
                
                // 预览文件功能
                function previewFile(index, fileName) {
                    const modal = document.getElementById('previewModal');
                    const title = document.getElementById('previewTitle');
                    const body = document.getElementById('previewBody');
                    
                    title.textContent = '预览: ' + fileName;
                    body.innerHTML = '<div style="text-align: center; padding: 40px;"><div style="font-size: 48px; margin-bottom: 20px;">⏳</div><p>加载中...</p></div>';
                    modal.classList.add('active');
                    
                    const fileExtension = fileName.split('.').pop().toLowerCase();
                    const previewUrl = '/preview/' + index;
                    
                    if (['jpg', 'jpeg', 'png', 'gif'].includes(fileExtension)) {
                        // 图片预览
                        body.innerHTML = '<img src="' + previewUrl + '" class="preview-image" alt="' + fileName + '" onerror="handlePreviewError()">';
                    } else if (['mp4', 'mov'].includes(fileExtension)) {
                        // 视频预览
                        body.innerHTML = '<video src="' + previewUrl + '" class="preview-video" controls autoplay></video>';
                    } else if (['txt', 'json'].includes(fileExtension)) {
                        // 文本预览
                        console.log('开始加载文本文件:', previewUrl);
                        fetch(previewUrl)
                            .then(response => {
                                console.log('响应状态:', response.status, response.statusText);
                                console.log('Content-Type:', response.headers.get('Content-Type'));
                                if (!response.ok) {
                                    throw new Error('HTTP ' + response.status + ': ' + response.statusText);
                                }
                                return response.text();
                            })
                            .then(text => {
                                console.log('文本内容长度:', text ? text.length : 0);
                                if (text === null || text === undefined || text === '') {
                                    throw new Error('响应内容为空');
                                }
                                const escapedText = escapeHtml(text);
                                body.innerHTML = '<div class="preview-text">' + escapedText + '</div>';
                                console.log('文本预览加载成功');
                            })
                            .catch(error => {
                                console.error('预览错误:', error);
                                body.innerHTML = '<div class="preview-unsupported"><div class="emoji">❌</div><h3>加载失败</h3><p>' + escapeHtml(error.message || '未知错误') + '</p><p>请检查控制台获取详细信息</p></div>';
                            });
                    } else if (fileExtension === 'pdf') {
                        // PDF预览
                        body.innerHTML = '<iframe src="' + previewUrl + '" class="preview-pdf"></iframe>';
                    } else {
                        // 不支持预览的文件类型
                        body.innerHTML = '<div class="preview-unsupported"><div class="emoji">📄</div><h3>不支持预览此文件类型</h3><p>文件类型: .' + fileExtension + '</p><p>请下载后查看</p></div>';
                    }
                }
                
                // 关闭预览
                function closePreview() {
                    const modal = document.getElementById('previewModal');
                    modal.classList.remove('active');
                    const body = document.getElementById('previewBody');
                    body.innerHTML = '';
                }
                
                // 点击模态框外部关闭
                document.getElementById('previewModal').addEventListener('click', function(e) {
                    if (e.target === this) {
                        closePreview();
                    }
                });
                
                // ESC键关闭预览
                document.addEventListener('keydown', function(e) {
                    if (e.key === 'Escape') {
                        closePreview();
                    }
                });
                
                // HTML转义函数
                function escapeHtml(text) {
                    const div = document.createElement('div');
                    div.textContent = text;
                    return div.innerHTML;
                }
                
                // 预览错误处理
                function handlePreviewError() {
                    const body = document.getElementById('previewBody');
                    body.innerHTML = '<div class="preview-unsupported"><div class="emoji">❌</div><h3>预览失败</h3><p>无法加载文件，请尝试下载后查看</p></div>';
                }
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



