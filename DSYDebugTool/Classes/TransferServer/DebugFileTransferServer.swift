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
import Photos

public class DebugFileTransferServer: NSObject {
    public static let shared = DebugFileTransferServer()
    public var serverPort: UInt = 8080
    
    /// Debug 开关，控制是否输出日志
    public var isDebugLogEnabled: Bool = true
    
    /// 端口被占用时，自动顺延尝试的次数（例如 20 表示最多尝试 `serverPort...serverPort+20`）
    public var portAutoRetryCount: UInt = 20

    private var webServer: GCDWebServer?
    public private(set) var isRunning = false
   
    private var appDisplayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? ""
  
    private var uploadedFiles: [(name: String, data: Data, uploadTime: Date)] = []
    /// Web 端上传图片到 App 的大小限制（字节），默认 20MB，可在 App 侧按需覆盖
    public var webImageUploadMaxSizeBytes: Int = 20 * 1024 * 1024
    /// Web 端上传任意文件到 App 的大小限制（字节），默认 20MB，可在 App 侧按需覆盖
    public var webFileUploadMaxSizeBytes: Int = 20 * 1024 * 1024
    /// Web 端上传文本到 App 的大小限制（字节）
    private let webTextUploadMaxSizeBytes: Int = 20 * 1024 * 1024
    
    override init() {
        super.init()
    }
    
    // MARK: - 日志输出方法
    public func log<T>(_ message: T,
                    file : StaticString = #file,
                    method: StaticString = #function,
                    lineNumber : UInt = #line) {
        guard isDebugLogEnabled else { return }
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
        
        // favicon 处理，避免浏览器默认请求返回 501
        webServer?.addHandler(forMethod: "GET", path: "/favicon.ico", request: GCDWebServerRequest.self) { _ in
            let response = GCDWebServerDataResponse(data: Data(), contentType: "image/x-icon")
            response.statusCode = 204
            response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
            return response
        }
        
        // Web 端上传到 App（文本）
        webServer?.addHandler(forMethod: "POST", path: "/api/upload-text", request: GCDWebServerDataRequest.self) { [weak self] request, completion in
            guard let self = self, let dataRequest = request as? GCDWebServerDataRequest else {
                completion(GCDWebServerErrorResponse(statusCode: 500))
                return
            }
            completion(self.handleWebTextUpload(request: dataRequest))
        }
        
        // Web 端上传到 App（图片）
        webServer?.addHandler(forMethod: "POST", path: "/api/upload-image", request: GCDWebServerDataRequest.self) { [weak self] request, completion in
            guard let self = self, let dataRequest = request as? GCDWebServerDataRequest else {
                completion(GCDWebServerErrorResponse(statusCode: 500))
                return
            }
            completion(self.handleWebImageUpload(request: dataRequest))
        }
        
        // Web 端上传到 App（任意文件：txt/word/pdf...）
        webServer?.addHandler(forMethod: "POST", path: "/api/upload-file", request: GCDWebServerDataRequest.self) { [weak self] request, completion in
            guard let self = self, let dataRequest = request as? GCDWebServerDataRequest else {
                completion(GCDWebServerErrorResponse(statusCode: 500))
                return
            }
            completion(self.handleWebFileUpload(request: dataRequest))
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
    
    private func handleWebTextUpload(request: GCDWebServerDataRequest) -> GCDWebServerResponse {
        log("⬆️ Web文本上传，请求大小: \(request.data.count)")
        guard let json = try? JSONSerialization.jsonObject(with: request.data) as? [String: Any] else {
            log("❌ Web文本上传 JSON 解析失败")
            return jsonResponse(code: 400, message: "JSON格式错误")
        }
        
        let text = (json["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            log("❌ Web文本上传为空")
            return jsonResponse(code: 400, message: "文本不能为空")
        }
        
        if text.utf8.count > webTextUploadMaxSizeBytes {
            log("❌ Web文本上传过大: \(text.utf8.count)")
            return jsonResponse(code: 400, message: "文本过大，最大支持20MB")
        }
        
        if let image = decodeBase64Image(from: text) {
            log("✅ Web文本识别为 base64 图片，按图片处理")
            DispatchQueue.main.async { [weak self] in
                self?.presentReceivedImageAlert(image: image)
            }
            return jsonResponse(message: "检测到base64图片，已按图片发送到App")
        }
        
        log("✅ Web文本上传成功，长度: \(text.count)")
        
        DispatchQueue.main.async { [weak self] in
            self?.presentReceivedTextAlert(text: text)
        }
        return jsonResponse(message: "文本已发送到App")
    }
    
    private func handleWebImageUpload(request: GCDWebServerDataRequest) -> GCDWebServerResponse {
        log("⬆️ Web图片上传，请求大小: \(request.data.count)")
        guard let json = try? JSONSerialization.jsonObject(with: request.data) as? [String: Any] else {
            log("❌ Web图片上传 JSON 解析失败")
            return jsonResponse(code: 400, message: "JSON格式错误")
        }
        
        let base64OrDataURL = (json["imageData"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base64OrDataURL.isEmpty else {
            log("❌ Web图片上传数据为空")
            return jsonResponse(code: 400, message: "图片数据不能为空")
        }
        
        let base64String: String
        if let commaIndex = base64OrDataURL.firstIndex(of: ","),
           base64OrDataURL[..<commaIndex].contains("base64") {
            base64String = String(base64OrDataURL[base64OrDataURL.index(after: commaIndex)...])
        } else {
            base64String = base64OrDataURL
        }
        
        guard let imageData = Data(base64Encoded: base64String), !imageData.isEmpty else {
            log("❌ Web图片 base64 解码失败")
            return jsonResponse(code: 400, message: "图片数据解析失败")
        }
        
        if imageData.count > webImageUploadMaxSizeBytes {
            log("❌ Web图片过大: \(imageData.count)")
            return jsonResponse(code: 400, message: "图片过大，最大支持20MB")
        }
        
        guard let image = UIImage(data: imageData) else {
            log("❌ Web图片 UIImage 解析失败")
            return jsonResponse(code: 400, message: "图片解析失败")
        }
        log("✅ Web图片上传成功，大小: \(imageData.count)")
        
        DispatchQueue.main.async { [weak self] in
            self?.presentReceivedImageAlert(image: image)
        }
        return jsonResponse(message: "图片已发送到App")
    }
    
    private func handleWebFileUpload(request: GCDWebServerDataRequest) -> GCDWebServerResponse {
        log("⬆️ Web文件上传，请求大小: \(request.data.count)")
        guard let json = try? JSONSerialization.jsonObject(with: request.data) as? [String: Any] else {
            log("❌ Web文件上传 JSON 解析失败")
            return jsonResponse(code: 400, message: "JSON格式错误")
        }
        
        let fileName = (json["fileName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let mimeType = (json["mimeType"] as? String ?? "application/octet-stream").trimmingCharacters(in: .whitespacesAndNewlines)
        let base64OrDataURL = (json["fileData"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fileName.isEmpty else {
            return jsonResponse(code: 400, message: "文件名不能为空")
        }
        guard !base64OrDataURL.isEmpty else {
            return jsonResponse(code: 400, message: "文件数据不能为空")
        }
        
        let base64String: String
        if let commaIndex = base64OrDataURL.firstIndex(of: ","),
           base64OrDataURL[..<commaIndex].contains("base64") {
            base64String = String(base64OrDataURL[base64OrDataURL.index(after: commaIndex)...])
        } else {
            base64String = base64OrDataURL
        }
        
        guard let fileData = Data(base64Encoded: base64String), !fileData.isEmpty else {
            return jsonResponse(code: 400, message: "文件数据解析失败")
        }
        
        if fileData.count > webFileUploadMaxSizeBytes {
            return jsonResponse(code: 400, message: "文件过大，最大支持20MB")
        }
        
        log("✅ Web文件上传成功: \(fileName), size=\(fileData.count), mime=\(mimeType)")
        DispatchQueue.main.async { [weak self] in
            self?.presentReceivedFileAlert(fileName: fileName, mimeType: mimeType, data: fileData)
        }
        return jsonResponse(message: "文件已发送到App")
    }
    
    private func jsonResponse(code: Int = 0, message: String) -> GCDWebServerResponse {
        let payload: [String: Any] = [
            "code": code,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
        let response = GCDWebServerDataResponse(data: data, contentType: "application/json; charset=utf-8")
        response.setValue("no-cache", forAdditionalHeader: "Cache-Control")
        return response
    }
    
    private func topMostViewController() -> UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController?.topMostViewController
    }
    
    private func presentReceivedTextAlert(text: String) {
        guard let topVC = topMostViewController() else { return }
        if topVC.presentedViewController is UIAlertController { return }
        
        let alert = UIAlertController(
            title: "收到网页文本",
            message: text,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "复制", style: .default, handler: { _ in
            UIPasteboard.general.string = text
        }))
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        topVC.present(alert, animated: true)
    }
    
    private func presentReceivedImageAlert(image: UIImage) {
        guard let topVC = topMostViewController() else { return }
        if topVC.presentedViewController is UIAlertController { return }
        
        let previewVC = UIViewController()
        previewVC.view.backgroundColor = .systemBackground
        
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        previewVC.view.addSubview(imageView)
        
        // 根据图片比例计算预览区域，避免超高图导致大量空白
        let maxWidth = min(UIScreen.main.bounds.width - 90, 300)
        let maxHeight: CGFloat = 320
        let imageSize = image.size
        let safeImageSize = CGSize(width: max(imageSize.width, 1), height: max(imageSize.height, 1))
        let scale = min(maxWidth / safeImageSize.width, maxHeight / safeImageSize.height)
        let previewWidth = max(120, safeImageSize.width * scale)
        let previewHeight = max(120, safeImageSize.height * scale)
        previewVC.preferredContentSize = CGSize(width: previewWidth + 24, height: previewHeight + 24)
        
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: previewWidth),
            imageView.heightAnchor.constraint(equalToConstant: previewHeight),
            imageView.centerXAnchor.constraint(equalTo: previewVC.view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: previewVC.view.centerYAnchor)
        ])
        
        let alert = UIAlertController(
            title: "收到网页图片",
            message: "可直接保存到系统相册",
            preferredStyle: .alert
        )
        alert.setValue(previewVC, forKey: "contentViewController")
        alert.addAction(UIAlertAction(title: "添加到相册", style: .default, handler: { [weak self] _ in
            self?.saveImageToAlbum(image: image)
        }))
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        topVC.present(alert, animated: true)
    }
    
    private func presentReceivedFileAlert(fileName: String, mimeType: String, data: Data) {
        guard let topVC = topMostViewController() else { return }
        if topVC.presentedViewController is UIAlertController { return }
        
        let message = """
        文件名：\(fileName)
        类型：\(mimeType)
        大小：\(formatFileSize(data.count))
        """
        let alert = UIAlertController(title: "收到网页文件", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "保存到文件", style: .default, handler: { [weak self] _ in
            self?.saveFileToFiles(fileName: fileName, data: data)
        }))
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        topVC.present(alert, animated: true)
    }
    
    private func saveFileToFiles(fileName: String, data: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: tempURL, options: .atomic)
        } catch {
            presentSimpleTip(title: "保存失败", message: error.localizedDescription)
            return
        }
        
        guard let topVC = topMostViewController() else { return }
        if #available(iOS 14.0, *) {
            let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
            topVC.present(picker, animated: true)
        } else {
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            topVC.present(activityVC, animated: true)
        }
    }
    
    private func decodeBase64Image(from text: String) -> UIImage? {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { return nil }
        
        let base64: String
        if let commaIndex = input.firstIndex(of: ","),
           input[..<commaIndex].contains("base64") {
            base64 = String(input[input.index(after: commaIndex)...])
        } else {
            base64 = input
        }
        
        guard base64.count > 128, // 避免把普通短文本误判
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveImageToAlbum(image: UIImage) {
        let saveBlock = {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            self.presentSimpleTip(title: "保存成功", message: "图片已添加到系统相册")
        }
        
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            switch status {
            case .authorized, .limited:
                saveBlock()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { auth in
                    DispatchQueue.main.async {
                        if auth == .authorized || auth == .limited {
                            saveBlock()
                        } else {
                            self.presentSimpleTip(title: "无权限", message: "请在系统设置中允许照片权限")
                        }
                    }
                }
            default:
                presentSimpleTip(title: "无权限", message: "请在系统设置中允许照片权限")
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                saveBlock()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { auth in
                    DispatchQueue.main.async {
                        if auth == .authorized {
                            saveBlock()
                        } else {
                            self.presentSimpleTip(title: "无权限", message: "请在系统设置中允许照片权限")
                        }
                    }
                }
            default:
                presentSimpleTip(title: "无权限", message: "请在系统设置中允许照片权限")
            }
        }
    }
    
    private func presentSimpleTip(title: String, message: String) {
        guard let topVC = topMostViewController() else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        topVC.present(alert, animated: true)
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
                .top-nav { display:flex; gap:12px; margin-bottom: 12px; }
                .tab-btn { border: 0; padding:10px 16px; border-radius:999px; font-weight:600; background:#edf2ff; color:#333; cursor:pointer; }
                .tab-btn.active { background:#007AFF; color:#fff; }
                .panel { display:none; }
                .panel.active { display:block; }
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
                .upload-card { border:1px solid #e9ecef; border-radius: 10px; padding:16px; margin-top:16px; background:#f8f9fa; }
                .upload-row { display:flex; gap:12px; align-items:center; margin-top:12px; flex-wrap: wrap; }
                .upload-text { width:100%; min-height:120px; border:1px solid #d0d7de; border-radius:8px; padding:10px; font-size:14px; box-sizing:border-box; }
                .upload-btn { border:none; border-radius:20px; padding:9px 16px; color:#fff; font-weight:600; cursor:pointer; background:linear-gradient(45deg,#007AFF,#0056CC); }
                .upload-btn.secondary { background:linear-gradient(45deg,#6c757d,#495057); }
                .upload-btn.warn { background:linear-gradient(45deg,#ff8f00,#ff6f00); }
                .history-item { border:1px solid #e9ecef; border-radius:10px; padding:12px; background:#fff; margin-top:10px; }
                .history-meta { font-size:12px; color:#666; margin-bottom:8px; }
                .history-preview { font-size:14px; color:#222; max-height:60px; overflow:hidden; white-space:pre-wrap; word-break: break-word; }
                .history-image { max-width:140px; max-height:90px; border-radius:6px; display:block; margin-top:8px; border:1px solid #eee; }
                .tiny-tip { font-size:12px; color:#666; margin-top:8px; }
                .status-tip { font-size:13px; margin-top:10px; color:#007AFF; }
                .debug-log-card { display: none; }
                .debug-log-header { display:none; }
                .debug-log-box { display:none; }
                .drop-zone { margin-top: 10px; border: 2px dashed #90caf9; border-radius: 8px; padding: 22px 14px; min-height: 120px; color: #1976d2; background: #f5fbff; text-align: center; font-size: 13px; display:flex; align-items:center; justify-content:center; box-sizing:border-box; }
                .drop-zone.active { border-color: #007AFF; background: #eaf4ff; }
                .btn-disabled { opacity: 0.45; cursor: not-allowed; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📱 \(appDisplayName) 文件传输站</h1>
                <div class="top-nav">
                    <button id="tabReceive" type="button" class="tab-btn active" onclick="switchTab('receive')">📥 接收站</button>
                    <button id="tabUpload" type="button" class="tab-btn" onclick="switchTab('upload')">⬆️ 上传站</button>
                </div>
                <div id="panelReceive" class="panel active">
                
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
                
                <div id="panelUpload" class="panel">
                    <div class="info">
                        <strong>📤 上传到App</strong><br>
                        • 此页面用于向\(appDisplayName)应用发送的文件<br>
                        • 支持发送文本、图片、文件到手机 App<br>
                        • App 收到后会立刻弹框：文本可复制，图片可添加到相册，文件可保存到系统文件中<br>
                        • 支持历史记录、编辑、预览、再次发送
                    </div>
                    
                    <div class="upload-card">
                        <div><strong>内容类型</strong></div>
                        <div class="upload-row">
                            <button type="button" class="upload-btn secondary" id="typeTextBtn" onclick="setUploadType('text')">📝 文本</button>
                            <button type="button" class="upload-btn secondary" id="typeImageBtn" onclick="setUploadType('image')">🖼️ 图片</button>
                            <button type="button" class="upload-btn secondary" id="typeFileBtn" onclick="setUploadType('file')">📄 文件</button>
                        </div>
                        
                        <div id="textEditorWrap" style="margin-top:12px;">
                            <textarea id="textInput" class="upload-text" placeholder="输入要发送到App的文字"></textarea>
                        </div>
                        
                        <div id="imageEditorWrap" style="display:none; margin-top:12px;">
                            <input id="imageInput" type="file" accept="image/*" onchange="onSelectImage(event)" />
                            <div id="imageDropZone" class="drop-zone">将图片拖到这里，松开后自动上传</div>
                            <img id="imagePreview" class="history-image" style="display:none; max-width: 260px; max-height: 180px;" />
                        </div>
                        
                        <div id="fileEditorWrap" style="display:none; margin-top:12px;">
                            <input id="fileInput" type="file" accept=".txt,.pdf,.doc,.docx,.rtf,.md,.json,.csv,.xls,.xlsx,.ppt,.pptx" onchange="onSelectAnyFile(event)" />
                            <div id="fileDropZone" class="drop-zone">将 txt / word / pdf 等文件拖到这里，松开后自动上传</div>
                            <div id="fileInfo" class="tiny-tip"></div>
                        </div>
                        
                        <div class="upload-row">
                            <button type="button" class="upload-btn" onclick="sendCurrent()">发送到App</button>
                            <button type="button" class="upload-btn warn" onclick="clearEditor()">清空</button>
                        </div>
                        <div id="sendStatus" class="status-tip"></div>
                        <div class="tiny-tip">历史保存在当前浏览器 LocalStorage。</div>
                        
                        
                    </div>
                    
                    <div class="upload-card">
                        <div style="display:flex;justify-content:space-between;align-items:center;">
                            <strong>上传记录</strong>
                            <button type="button" class="upload-btn secondary" onclick="clearHistory()">清空历史</button>
                        </div>
                        <div id="historyList"></div>
                    </div>
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
                var uploadType = 'text';
                var selectedImageDataUrl = '';
                var selectedFileBase64 = '';
                var selectedFileName = '';
                var selectedFileMimeType = '';
                var editingHistoryId = '';
                const HISTORY_KEY = 'dsy_debug_upload_history_v1';
                
                function logDebug(msg) {
                    // 调试日志已禁用
                }
                
                function clearDebugLog() {
                    // 调试日志已禁用
                }
                
                window.addEventListener('error', function(e) {
                    logDebug('JS Error: ' + (e.message || 'unknown') + ' @' + (e.filename || '') + ':' + (e.lineno || 0));
                });
                
                window.addEventListener('unhandledrejection', function(e) {
                    const reason = e.reason && e.reason.message ? e.reason.message : String(e.reason || 'unknown');
                    logDebug('Promise Rejection: ' + reason);
                });
                
                // 每30秒自动刷新页面
                setTimeout(function() {
                    if (document.getElementById('panelReceive').classList.contains('active')) {
                        location.reload();
                    }
                }, 30000);
                
                // 添加下载统计
                document.querySelectorAll('.download-btn').forEach(function(btn) {
                    btn.addEventListener('click', function() {
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
                
                function escapeAttr(text) {
                    return String(text || '')
                        .replace(/&/g, '&amp;')
                        .replace(/"/g, '&quot;')
                        .replace(/</g, '&lt;')
                        .replace(/>/g, '&gt;');
                }
                
                // 预览错误处理
                function handlePreviewError() {
                    const body = document.getElementById('previewBody');
                    body.innerHTML = '<div class="preview-unsupported"><div class="emoji">❌</div><h3>预览失败</h3><p>无法加载文件，请尝试下载后查看</p></div>';
                }
                
                function switchTab(tab) {
                    logDebug('click tab: ' + tab);
                    const isReceive = tab === 'receive';
                    const panelReceive = document.getElementById('panelReceive');
                    const panelUpload = document.getElementById('panelUpload');
                    const tabReceive = document.getElementById('tabReceive');
                    const tabUpload = document.getElementById('tabUpload');
                    if (isReceive) {
                        panelReceive.classList.add('active');
                        panelUpload.classList.remove('active');
                        tabReceive.classList.add('active');
                        tabUpload.classList.remove('active');
                    } else {
                        panelUpload.classList.add('active');
                        panelReceive.classList.remove('active');
                        tabUpload.classList.add('active');
                        tabReceive.classList.remove('active');
                    }
                }
                
                function setUploadType(type) {
                    logDebug('set upload type: ' + type);
                    uploadType = type;
                    const isText = type === 'text';
                    const isImage = type === 'image';
                    const isFile = type === 'file';
                    document.getElementById('textEditorWrap').style.display = isText ? 'block' : 'none';
                    document.getElementById('imageEditorWrap').style.display = isImage ? 'block' : 'none';
                    document.getElementById('fileEditorWrap').style.display = isFile ? 'block' : 'none';
                    document.getElementById('typeTextBtn').style.opacity = isText ? '1' : '0.7';
                    document.getElementById('typeImageBtn').style.opacity = isImage ? '1' : '0.7';
                    document.getElementById('typeFileBtn').style.opacity = isFile ? '1' : '0.7';
                }
                
                function onSelectImage(event) {
                    const file = event.target.files && event.target.files[0];
                    if (!file) return;
                    logDebug('select image: ' + file.name + ', size=' + file.size);
                    loadImageFile(file, false);
                }
                
                function loadImageFile(file, autoSend) {
                    var reader = new FileReader();
                    reader.onload = function(e) {
                        selectedImageDataUrl = e.target.result || '';
                        var preview = document.getElementById('imagePreview');
                        preview.src = selectedImageDataUrl;
                        preview.style.display = selectedImageDataUrl ? 'block' : 'none';
                        if (autoSend && selectedImageDataUrl) {
                            logDebug('drop auto send image');
                            sendPayload('image', '', selectedImageDataUrl, '', '', '', '');
                        }
                    };
                    reader.readAsDataURL(file);
                }
                
                function onSelectAnyFile(event) {
                    var file = event.target.files && event.target.files[0];
                    if (!file) return;
                    loadAnyFile(file, false);
                }
                
                function loadAnyFile(file, autoSend) {
                    logDebug('select file: ' + file.name + ', size=' + file.size + ', type=' + (file.type || 'unknown'));
                    var reader = new FileReader();
                    reader.onload = function(e) {
                        var dataUrl = e.target.result || '';
                        var commaIndex = dataUrl.indexOf(',');
                        selectedFileBase64 = commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl;
                        selectedFileName = file.name || ('upload_' + Date.now());
                        selectedFileMimeType = file.type || 'application/octet-stream';
                        var fileInfo = document.getElementById('fileInfo');
                        fileInfo.textContent = '已选择：' + selectedFileName + ' (' + (selectedFileMimeType || 'unknown') + ')';
                        if (autoSend) {
                            sendPayload('file', '', '', '', selectedFileName, selectedFileMimeType, selectedFileBase64);
                        }
                    };
                    reader.readAsDataURL(file);
                }
                
                function setupDropZone() {
                    var dropZone = document.getElementById('imageDropZone');
                    if (!dropZone) return;
                    
                    ['dragenter', 'dragover'].forEach(function(eventName) {
                        dropZone.addEventListener(eventName, function(e) {
                            e.preventDefault();
                            e.stopPropagation();
                            dropZone.classList.add('active');
                        });
                    });
                    
                    ['dragleave', 'drop'].forEach(function(eventName) {
                        dropZone.addEventListener(eventName, function(e) {
                            e.preventDefault();
                            e.stopPropagation();
                            dropZone.classList.remove('active');
                        });
                    });
                    
                    dropZone.addEventListener('drop', function(e) {
                        var files = (e.dataTransfer && e.dataTransfer.files) ? e.dataTransfer.files : null;
                        if (!files || !files.length) {
                            setStatus('未检测到可上传文件');
                            return;
                        }
                        var file = files[0];
                        if (!file.type || file.type.indexOf('image/') !== 0) {
                            setStatus('请拖拽图片文件');
                            return;
                        }
                        setUploadType('image');
                        logDebug('drop image: ' + file.name + ', size=' + file.size);
                        loadImageFile(file, true);
                    });
                }
                
                function setupFileDropZone() {
                    var dropZone = document.getElementById('fileDropZone');
                    if (!dropZone) return;
                    ['dragenter', 'dragover'].forEach(function(eventName) {
                        dropZone.addEventListener(eventName, function(e) {
                            e.preventDefault();
                            e.stopPropagation();
                            dropZone.classList.add('active');
                        });
                    });
                    ['dragleave', 'drop'].forEach(function(eventName) {
                        dropZone.addEventListener(eventName, function(e) {
                            e.preventDefault();
                            e.stopPropagation();
                            dropZone.classList.remove('active');
                        });
                    });
                    dropZone.addEventListener('drop', function(e) {
                        var files = (e.dataTransfer && e.dataTransfer.files) ? e.dataTransfer.files : null;
                        if (!files || !files.length) {
                            setStatus('未检测到可上传文件');
                            return;
                        }
                        var file = files[0];
                        setUploadType('file');
                        loadAnyFile(file, true);
                    });
                }
                
                function findInList(list, predicate) {
                    if (!list || !list.length) return null;
                    for (var i = 0; i < list.length; i++) {
                        if (predicate(list[i])) return list[i];
                    }
                    return null;
                }
                
                function findIndexInList(list, predicate) {
                    if (!list || !list.length) return -1;
                    for (var i = 0; i < list.length; i++) {
                        if (predicate(list[i])) return i;
                    }
                    return -1;
                }
                
                function getHistory() {
                    try {
                        var raw = localStorage.getItem(HISTORY_KEY);
                        var parsed = raw ? JSON.parse(raw) : [];
                        return Array.isArray(parsed) ? parsed : [];
                    } catch (e) {
                        return [];
                    }
                }
                
                function setHistory(list) {
                    setHistoryWithQuota(list);
                }
                
                function setHistoryWithQuota(list) {
                    var candidate = list.slice();
                    while (candidate.length >= 0) {
                        try {
                            localStorage.setItem(HISTORY_KEY, JSON.stringify(candidate));
                            return true;
                        } catch (e) {
                            if (candidate.length === 0) {
                                logDebug('setHistory failed: quota exceeded and no removable records');
                                return false;
                            }
                            // 先移除最旧记录（列表本身是按 updatedAt 倒序）
                            var removed = candidate.pop();
                            logDebug('quota exceeded, remove oldest history id=' + (removed && removed.id ? removed.id : 'unknown'));
                        }
                    }
                    return false;
                }
                
                function payloadLength(item) {
                    if (!item) return 0;
                    var textLen = (item.text || '').length;
                    var imageLen = (item.imageDataUrl || '').length;
                    var fileLen = (item.fileDataBase64 || '').length;
                    return textLen + imageLen + fileLen;
                }
                
                function degradeItemForStorage(item) {
                    var cloned = JSON.parse(JSON.stringify(item || {}));
                    var type = cloned.type || 'text';
                    if (type === 'image') {
                        cloned.imageDataUrl = '';
                    } else if (type === 'file') {
                        cloned.fileDataBase64 = '';
                    }
                    cloned.storagePayloadOmitted = true;
                    cloned.storageOmitReason = 'payload_too_large_for_local_storage';
                    return cloned;
                }
                
                function getHistoryFingerprint(item) {
                    var type = item && item.type ? item.type : 'text';
                    if (type === 'image') {
                        var imageData = item && item.imageDataUrl ? item.imageDataUrl : '';
                        return 'image:' + imageData;
                    }
                    if (type === 'file') {
                        var fileData = item && item.fileDataBase64 ? item.fileDataBase64 : '';
                        return 'file:' + fileData;
                    }
                    var text = item && item.text ? item.text : '';
                    return 'text:' + text;
                }
                
                function saveHistory(item) {
                    var list = getHistory();
                    var fingerprint = getHistoryFingerprint(item);
                    var now = Date.now();
                    item.updatedAt = now;
                    
                    var sameContentIdx = findIndexInList(list, function(x) {
                        return getHistoryFingerprint(x) === fingerprint;
                    });
                    
                    if (sameContentIdx >= 0) {
                        var existed = list[sameContentIdx];
                        item.id = existed.id || item.id || ('h_' + now + '_' + Math.random().toString(36).slice(2, 8));
                        item.createdAt = existed.createdAt || item.createdAt || now;
                        list[sameContentIdx] = item;
                    } else if (item.id) {
                        var idx = findIndexInList(list, function(x) { return x.id === item.id; });
                        if (idx >= 0) {
                            item.createdAt = list[idx].createdAt || item.createdAt || now;
                            list[idx] = item;
                        } else {
                            item.createdAt = item.createdAt || now;
                            list.push(item);
                        }
                    } else {
                        item.id = 'h_' + now + '_' + Math.random().toString(36).slice(2, 8);
                        item.createdAt = item.createdAt || now;
                        list.push(item);
                    }
                    
                    // 二次去重（防历史脏数据），同内容只保留更新时间最新的一条
                    var dedupMap = {};
                    for (var i = 0; i < list.length; i++) {
                        var current = list[i];
                        var key = getHistoryFingerprint(current);
                        if (!dedupMap[key]) {
                            dedupMap[key] = current;
                        } else {
                            var existItem = dedupMap[key];
                            var existUpdatedAt = existItem.updatedAt || 0;
                            var currentUpdatedAt = current.updatedAt || 0;
                            if (currentUpdatedAt > existUpdatedAt) {
                                dedupMap[key] = current;
                            }
                        }
                    }
                    
                    var deduped = [];
                    for (var k in dedupMap) {
                        if (Object.prototype.hasOwnProperty.call(dedupMap, k)) {
                            deduped.push(dedupMap[k]);
                        }
                    }
                    
                    // 按更新时间倒序
                    deduped.sort(function(a, b) {
                        return (b.updatedAt || 0) - (a.updatedAt || 0);
                    });
                    
                    // 先尝试完整保存；失败后降级当前记录 payload 再保存
                    var saved = setHistoryWithQuota(deduped);
                    if (!saved) {
                        var indexCurrent = findIndexInList(deduped, function(x) { return x.id === item.id; });
                        if (indexCurrent >= 0) {
                            deduped[indexCurrent] = degradeItemForStorage(deduped[indexCurrent]);
                            deduped[indexCurrent].updatedAt = now;
                            deduped.sort(function(a, b) {
                                return (b.updatedAt || 0) - (a.updatedAt || 0);
                            });
                            saved = setHistoryWithQuota(deduped);
                        }
                    }
                    if (!saved) {
                        setStatus('历史记录存储空间不足，已自动清理旧记录');
                    }
                    renderHistory();
                }
                
                function clearHistory() {
                    logDebug('clear history');
                    setHistory([]);
                    renderHistory();
                }
                
                function renderHistory() {
                    var host = document.getElementById('historyList');
                    var list = getHistory();
                    if (!list.length) {
                        host.innerHTML = '<div class="tiny-tip">暂无历史记录</div>';
                        return;
                    }
                    host.innerHTML = list.map(function(item) {
                        var title = item.type === 'text' ? '📝 文本' : (item.type === 'image' ? '🖼️ 图片' : '📄 文件');
                        var preview = '';
                        if (item.type === 'text') {
                            preview = '<div class="history-preview">' + escapeHtml(item.text || '') + '</div>';
                        } else if (item.type === 'image') {
                            preview = (item.imageDataUrl || '') ? '<img class="history-image" src="' + item.imageDataUrl + '" />' : '<div class="tiny-tip">图片数据未缓存（仍可再次上传新内容）</div>';
                        } else {
                            preview = '<div class="history-preview">文件：' + escapeHtml(item.fileName || '未知文件') + '<br/>类型：' + escapeHtml(item.fileMimeType || 'application/octet-stream') + '</div>';
                        }
                        var omitTip = item.storagePayloadOmitted ? '<div class="tiny-tip">⚠️ 此记录数据过大，仅保留元信息，复制/预览/重发不可用</div>' : '';
                        var time = new Date(item.updatedAt || item.createdAt || Date.now()).toLocaleString();
                        return '<div class="history-item">' +
                            '<div class="history-meta">' + title + ' • ' + time + '</div>' +
                            preview +
                            omitTip +
                            '<div class="upload-row">' +
                            '<button class="upload-btn secondary" data-act="copy" data-id="' + escapeAttr(item.id) + '">复制</button>' +
                            ((item.type === 'text')
                                ? '<button class="upload-btn secondary" data-act="edit" data-id="' + escapeAttr(item.id) + '">修改</button>'
                                : '<button class="upload-btn secondary btn-disabled" data-act="edit-disabled" data-id="' + escapeAttr(item.id) + '">修改</button>') +
                            '<button class="upload-btn" data-act="resend" data-id="' + escapeAttr(item.id) + '">再次发送</button>' +
                            '<button class="upload-btn warn" data-act="preview" data-id="' + escapeAttr(item.id) + '">预览</button>' +
                            '</div></div>';
                    }).join('');
                }
                
                document.addEventListener('click', function(e) {
                    var target = e.target;
                    if (!target) return;
                    var action = target.getAttribute('data-act');
                    var id = target.getAttribute('data-id');
                    if (!action || !id) return;
                    if (action === 'copy') {
                        copyHistory(id);
                    } else if (action === 'edit-disabled') {
                        setStatus('仅文字类型支持修改');
                    } else if (action === 'edit') {
                        editHistory(id);
                    } else if (action === 'resend') {
                        resendHistory(id);
                    } else if (action === 'preview') {
                        previewHistory(id);
                    }
                });
                
                function editHistory(id) {
                    logDebug('edit history: ' + id);
                    var item = findInList(getHistory(), function(x) { return x.id === id; });
                    if (!item) return;
                    editingHistoryId = id;
                    setUploadType(item.type || 'text');
                    if ((item.type || 'text') === 'text') {
                        document.getElementById('textInput').value = item.text || '';
                    } else if ((item.type || 'text') === 'image') {
                        selectedImageDataUrl = item.imageDataUrl || '';
                        const preview = document.getElementById('imagePreview');
                        preview.src = selectedImageDataUrl;
                        preview.style.display = selectedImageDataUrl ? 'block' : 'none';
                    } else {
                        selectedFileBase64 = item.fileDataBase64 || '';
                        selectedFileName = item.fileName || '';
                        selectedFileMimeType = item.fileMimeType || 'application/octet-stream';
                        document.getElementById('fileInfo').textContent = selectedFileName ? ('已选择：' + selectedFileName + ' (' + selectedFileMimeType + ')') : '';
                    }
                    setStatus('已载入历史记录，可直接修改后发送');
                }
                
                function previewHistory(id) {
                    logDebug('preview history: ' + id);
                    var item = findInList(getHistory(), function(x) { return x.id === id; });
                    if (!item) return;
                    if (item.storagePayloadOmitted) {
                        setStatus('该记录数据未缓存，无法预览');
                        return;
                    }
                    if ((item.type || 'text') === 'text') {
                        showHistoryTextPreview(item.text || '(空文本)');
                    } else if ((item.type || 'text') === 'image' && item.imageDataUrl) {
                        showDataImagePreview(item.imageDataUrl);
                    } else if ((item.type || 'text') === 'file') {
                        showHistoryFilePreview(item);
                    }
                }
                
                function showDataImagePreview(dataUrl) {
                    var modal = document.getElementById('previewModal');
                    var title = document.getElementById('previewTitle');
                    var body = document.getElementById('previewBody');
                    title.textContent = '预览: 历史图片';
                    body.innerHTML = '<img src="' + dataUrl + '" class="preview-image" alt="history-image" onerror="handlePreviewError()">';
                    modal.classList.add('active');
                }
                
                function showHistoryTextPreview(text) {
                    var modal = document.getElementById('previewModal');
                    var title = document.getElementById('previewTitle');
                    var body = document.getElementById('previewBody');
                    title.textContent = '预览: 历史文本';
                    body.innerHTML = '<div class="preview-text">' + escapeHtml(text || '') + '</div>';
                    modal.classList.add('active');
                }
                
                function showHistoryFilePreview(item) {
                    var fileName = item.fileName || 'unknown';
                    var mimeType = item.fileMimeType || 'application/octet-stream';
                    var fileBase64 = item.fileDataBase64 || '';
                    if (!fileBase64) {
                        setStatus('预览失败：文件数据为空');
                        return;
                    }
                    var ext = '';
                    var dotIdx = fileName.lastIndexOf('.');
                    if (dotIdx >= 0 && dotIdx < fileName.length - 1) {
                        ext = fileName.substring(dotIdx + 1).toLowerCase();
                    }
                    var dataUrl = 'data:' + mimeType + ';base64,' + fileBase64;
                    var modal = document.getElementById('previewModal');
                    var title = document.getElementById('previewTitle');
                    var body = document.getElementById('previewBody');
                    title.textContent = '预览: ' + fileName;
                    
                    var isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].indexOf(ext) >= 0 || mimeType.indexOf('image/') === 0;
                    var isVideo = ['mp4', 'mov', 'webm'].indexOf(ext) >= 0 || mimeType.indexOf('video/') === 0;
                    var isPdf = ext === 'pdf' || mimeType === 'application/pdf';
                    var isText = ['txt', 'json', 'md', 'csv', 'log', 'xml', 'html', 'js', 'css', 'swift'].indexOf(ext) >= 0
                        || mimeType.indexOf('text/') === 0
                        || mimeType.indexOf('json') >= 0;
                    
                    if (isImage) {
                        body.innerHTML = '<img src="' + dataUrl + '" class="preview-image" alt="' + escapeHtml(fileName) + '" onerror="handlePreviewError()">';
                    } else if (isVideo) {
                        body.innerHTML = '<video src="' + dataUrl + '" class="preview-video" controls autoplay></video>';
                    } else if (isPdf) {
                        body.innerHTML = '<iframe src="' + dataUrl + '" class="preview-pdf"></iframe>';
                    } else if (isText) {
                        var decodedText = decodeBase64ToUtf8(fileBase64);
                        if (decodedText === null) {
                            body.innerHTML = '<div class="preview-unsupported"><div class="emoji">❌</div><h3>文本解码失败</h3><p>可复制 base64 后自行处理</p></div>';
                        } else {
                            body.innerHTML = '<div class="preview-text">' + escapeHtml(decodedText) + '</div>';
                        }
                    } else {
                        body.innerHTML = '<div class="preview-unsupported"><div class="emoji">📄</div><h3>暂不支持在线预览此文件</h3><p>文件类型: .' + escapeHtml(ext || 'unknown') + '</p><p>请下载后查看</p></div>';
                    }
                    modal.classList.add('active');
                }
                
                function decodeBase64ToUtf8(base64) {
                    try {
                        var binary = atob(base64);
                        var escaped = '';
                        for (var i = 0; i < binary.length; i++) {
                            var c = binary.charCodeAt(i).toString(16);
                            if (c.length < 2) c = '0' + c;
                            escaped += '%' + c;
                        }
                        return decodeURIComponent(escaped);
                    } catch (e) {
                        return null;
                    }
                }
                
                function copyTextCompat(text, callback) {
                    try {
                        var value = String(text || '');
                        if (!value) {
                            callback('内容为空');
                            return;
                        }
                        if (navigator.clipboard && navigator.clipboard.writeText) {
                            navigator.clipboard.writeText(value).then(function() {
                                callback(null);
                            }).catch(function() {
                                fallbackCopyText(value, callback);
                            });
                            return;
                        }
                        fallbackCopyText(value, callback);
                    } catch (e) {
                        callback((e && e.message) || '复制失败');
                    }
                }
                
                function fallbackCopyText(text, callback) {
                    try {
                        var textarea = document.createElement('textarea');
                        textarea.value = text;
                        textarea.style.position = 'fixed';
                        textarea.style.left = '-9999px';
                        document.body.appendChild(textarea);
                        textarea.focus();
                        textarea.select();
                        var ok = document.execCommand('copy');
                        document.body.removeChild(textarea);
                        callback(ok ? null : '浏览器不支持复制');
                    } catch (e) {
                        callback((e && e.message) || '复制失败');
                    }
                }
                
                function copyHistory(id) {
                    logDebug('copy history: ' + id);
                    var item = findInList(getHistory(), function(x) { return x.id === id; });
                    if (!item) {
                        setStatus('复制失败：未找到记录');
                        return;
                    }
                    if (item.storagePayloadOmitted) {
                        setStatus('复制失败：该记录数据未缓存');
                        return;
                    }
                    
                    if ((item.type || 'text') === 'text') {
                        copyTextCompat(item.text || '', function(err) {
                            if (err) {
                                setStatus('复制失败：' + err);
                            } else {
                                setStatus('复制成功');
                            }
                        });
                        return;
                    }
                    if ((item.type || 'text') === 'file') {
                        var fileBase64 = item.fileDataBase64 || '';
                        if (!fileBase64) {
                            setStatus('复制失败：文件数据为空');
                            return;
                        }
                        copyTextCompat(fileBase64, function(err) {
                            if (err) {
                                setStatus('复制失败：' + err);
                            } else {
                                setStatus('文件 base64 已复制');
                            }
                        });
                        return;
                    }
                    
                    var imageDataUrl = item.imageDataUrl || '';
                    if (!imageDataUrl) {
                        setStatus('复制失败：图片数据为空');
                        return;
                    }
                    var base64Content = imageDataUrl;
                    var commaIdx = imageDataUrl.indexOf(',');
                    if (commaIdx >= 0) {
                        base64Content = imageDataUrl.substring(commaIdx + 1);
                    }
                    copyTextCompat(base64Content, function(err) {
                        if (err) {
                            setStatus('复制失败：' + err);
                        } else {
                            setStatus('图片 base64 已复制');
                        }
                    });
                }
                
                function resendHistory(id) {
                    logDebug('resend history: ' + id);
                    var item = findInList(getHistory(), function(x) { return x.id === id; });
                    if (!item) return;
                    if (item.storagePayloadOmitted) {
                        setStatus('该记录数据未缓存，无法重新发送');
                        return;
                    }
                    sendPayload(item.type || 'text', item.text || '', item.imageDataUrl || '', id, item.fileName || '', item.fileMimeType || 'application/octet-stream', item.fileDataBase64 || '');
                }
                
                function clearEditor() {
                    logDebug('clear editor');
                    editingHistoryId = '';
                    document.getElementById('textInput').value = '';
                    document.getElementById('imageInput').value = '';
                    document.getElementById('fileInput').value = '';
                    selectedImageDataUrl = '';
                    selectedFileBase64 = '';
                    selectedFileName = '';
                    selectedFileMimeType = '';
                    var preview = document.getElementById('imagePreview');
                    preview.src = '';
                    preview.style.display = 'none';
                    document.getElementById('fileInfo').textContent = '';
                    setStatus('已清空输入内容');
                }
                
                function setStatus(text) {
                    logDebug('status: ' + (text || ''));
                    document.getElementById('sendStatus').textContent = text || '';
                }
                
                function sendCurrent() {
                    logDebug('click sendCurrent, type=' + uploadType);
                    if (uploadType === 'text') {
                        var text = (document.getElementById('textInput').value || '').trim();
                        if (!text) {
                            setStatus('请输入文本后再发送');
                            return;
                        }
                        sendPayload('text', text, '', editingHistoryId, '', '', '');
                    } else if (uploadType === 'image') {
                        if (!selectedImageDataUrl) {
                            setStatus('请先选择图片');
                            return;
                        }
                        sendPayload('image', '', selectedImageDataUrl, editingHistoryId, '', '', '');
                    } else {
                        if (!selectedFileBase64 || !selectedFileName) {
                            setStatus('请先选择文件');
                            return;
                        }
                        sendPayload('file', '', '', editingHistoryId, selectedFileName, selectedFileMimeType, selectedFileBase64);
                    }
                }
                
                function dataUrlToBlob(dataUrl) {
                    var parts = dataUrl.split(',');
                    var mime = parts[0].match(/:(.*?);/)[1];
                    var binary = atob(parts[1]);
                    var len = binary.length;
                    var u8arr = new Uint8Array(len);
                    for (var i = 0; i < len; i++) {
                        u8arr[i] = binary.charCodeAt(i);
                    }
                    return new Blob([u8arr], { type: mime });
                }
                
                function sendPayload(type, text, imageDataUrl, historyId, fileName, fileMimeType, fileDataBase64) {
                    setStatus('发送中...');
                    try {
                        logDebug('send payload start, type=' + type + ', historyId=' + (historyId || 'new'));
                        var payloadForHistory = { id: historyId || '', type: type, text: text, imageDataUrl: imageDataUrl, fileName: fileName || '', fileMimeType: fileMimeType || '', fileDataBase64: fileDataBase64 || '', createdAt: Date.now(), updatedAt: Date.now() };
                        var url = '/api/upload-text';
                        var body = JSON.stringify({ text: text });
                        if (type === 'image') {
                            url = '/api/upload-image';
                            body = JSON.stringify({ imageData: imageDataUrl });
                        } else if (type === 'file') {
                            url = '/api/upload-file';
                            body = JSON.stringify({ fileName: fileName || ('upload_' + Date.now()), mimeType: fileMimeType || 'application/octet-stream', fileData: fileDataBase64 || '' });
                        }
                        logDebug('POST ' + url + ', bodyLen=' + body.length);
                        postJson(url, body, function(err, json, status) {
                            if (err) {
                                logDebug('send payload error=' + err);
                                setStatus('发送失败：' + err);
                                return;
                            }
                            logDebug('response status=' + status);
                            logDebug('response json=' + JSON.stringify(json));
                            if (status < 200 || status >= 300 || !json || json.code !== 0) {
                                setStatus('发送失败：' + ((json && json.message) || '未知错误'));
                                return;
                            }
                            saveHistory(payloadForHistory);
                            editingHistoryId = '';
                            setStatus('发送成功：' + (json.message || '已到达 App'));
                        });
                    } catch (err) {
                        logDebug('send payload error=' + ((err && err.message) || String(err)));
                        setStatus('发送失败：' + ((err && err.message) || '未知错误'));
                    }
                }
                
                function postJson(url, body, callback) {
                    try {
                        var xhr = new XMLHttpRequest();
                        xhr.open('POST', url, true);
                        xhr.setRequestHeader('Content-Type', 'application/json');
                        xhr.onreadystatechange = function() {
                            if (xhr.readyState !== 4) return;
                            var status = xhr.status || 0;
                            var json = null;
                            try {
                                json = xhr.responseText ? JSON.parse(xhr.responseText) : null;
                            } catch (e) {
                                callback('响应不是有效JSON: ' + (xhr.responseText || ''), null, status);
                                return;
                            }
                            callback(null, json, status);
                        };
                        xhr.onerror = function() {
                            callback('网络请求失败', null, xhr.status || 0);
                        };
                        xhr.send(body);
                    } catch (e) {
                        callback((e && e.message) || '请求异常', null, 0);
                    }
                }
                
                setUploadType('text');
                renderHistory();
                setupDropZone();
                setupFileDropZone();
                logDebug('page ready');
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



