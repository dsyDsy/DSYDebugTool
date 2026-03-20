//
//  DebugFileUploadViewController.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/3.
//

import UIKit

// MARK: - 文件上传页面控制器
public class DebugFileUploadViewController: UIViewController, UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    
    public  override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    private func setupNavigationBar() {
        title = "文件上传"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissVC)
        )
    }
    
    @objc private func dismissVC() {
        dismiss(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // 设置滚动视图
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        setupContent()
    }
    
    private func setupContent() {
        // 标题
        titleLabel.text = "📤 文件上传"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // 服务器地址显示
        let serverAddressLabel = UILabel()
        if let ipAddress = DebugFileTransferServer.shared.getCompleteAddress() {
            serverAddressLabel.text = "🌐 服务器地址：\(ipAddress)"
        } else {
            serverAddressLabel.text = "🌐 服务器地址：获取中..."
        }
        serverAddressLabel.font = .systemFont(ofSize: 14, weight: .medium)
        serverAddressLabel.textAlignment = .center
        serverAddressLabel.textColor = .systemBlue
        serverAddressLabel.numberOfLines = 0
        serverAddressLabel.isUserInteractionEnabled = true
        contentView.addSubview(serverAddressLabel)
        serverAddressLabel.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(serverLableClick)))
        // 说明信息
        infoLabel.text = """
        选择要上传的文件类型：
        
        • 图片：支持JPG、PNG等格式，可从相册或拍照
        • 视频：支持MP4、MOV等格式，可从相册或录制
        • 文字：输入文字内容，自动保存为TXT文件
        • 文档：支持PDF、TXT等格式
        • 其他：支持所有文件类型
        
        上传的文件会发送到电脑端，
        测试人员可在浏览器中下载。
        """
        infoLabel.font = .systemFont(ofSize: 16)
        infoLabel.numberOfLines = 0
        infoLabel.textColor = .secondaryLabel
        contentView.addSubview(infoLabel)
        
        // 上传按钮
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 16
        buttonStackView.distribution = .fillEqually
        contentView.addSubview(buttonStackView)
        
        let imageButton = createUploadButton(title: "📷 上传图片", action: #selector(uploadImage))
        let videoButton = createUploadButton(title: "🎥 上传视频", action: #selector(uploadVideo))
        let textButton = createUploadButton(title: "📝 上传文字", action: #selector(uploadText))
        let documentButton = createUploadButton(title: "📄 上传文档", action: #selector(uploadDocument))
        let anyFileButton = createUploadButton(title: "📁 上传任意文件", action: #selector(uploadAnyFile))
        
        buttonStackView.addArrangedSubview(imageButton)
        buttonStackView.addArrangedSubview(videoButton)
        buttonStackView.addArrangedSubview(textButton)
        buttonStackView.addArrangedSubview(documentButton)
        buttonStackView.addArrangedSubview(anyFileButton)
        
        // 布局约束
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        serverAddressLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            serverAddressLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            serverAddressLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            serverAddressLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            infoLabel.topAnchor.constraint(equalTo: serverAddressLabel.bottomAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            buttonStackView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 40),
            buttonStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),
            buttonStackView.heightAnchor.constraint(equalToConstant: 300) // 5个按钮 * 50高度 + 4个间距 * 16
        ])
    }
    
    private func createUploadButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: action, for: .touchUpInside)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        return button
    }
    
    @objc private func uploadImage() {
        showImageVideoSourcePicker(isVideo: false)
    }
    
    @objc private func uploadVideo() {
        showImageVideoSourcePicker(isVideo: true)
    }
    
    private func showImageVideoSourcePicker(isVideo: Bool) {
        let title = isVideo ? "选择视频" : "选择图片"
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        // 相册选项
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let photoLibraryAction = UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
                self?.presentImageVideoPicker(sourceType: .photoLibrary, isVideo: isVideo)
            }
            alertController.addAction(photoLibraryAction)
        }
        
        // 拍照/录像选项
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let cameraTitle = isVideo ? "录制视频" : "拍照"
            let cameraAction = UIAlertAction(title: cameraTitle, style: .default) { [weak self] _ in
                self?.presentImageVideoPicker(sourceType: .camera, isVideo: isVideo)
            }
            alertController.addAction(cameraAction)
        }
        
        // 文件选择器选项
        let filePickerAction = UIAlertAction(title: "从文件选择", style: .default) { [weak self] _ in
            let types = isVideo ? ["public.movie"] : ["public.image"]
            self?.presentDocumentPicker(for: types)
        }
        alertController.addAction(filePickerAction)
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        alertController.addAction(cancelAction)
        
        // iPad 适配
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alertController, animated: true)
    }
    
    private func presentImageVideoPicker(sourceType: UIImagePickerController.SourceType, isVideo: Bool) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        
        if isVideo {
            imagePicker.mediaTypes = ["public.movie"]
        } else {
            imagePicker.mediaTypes = ["public.image"]
        }
        
        present(imagePicker, animated: true)
    }
    
    @objc private func uploadDocument() {
        presentDocumentPicker(for: ["public.data"])
    }
    
    @objc private func uploadAnyFile() {
        presentDocumentPicker(for: ["public.item"])
    }
    
    @objc private func uploadText() {
        showTextInputAlert()
    }
    
    @objc private func serverLableClick() {
        let ipAddress = DebugFileTransferServer.shared.getCompleteAddress()
        showAlert(title: "🌐 服务器复制成功", message: ipAddress ?? "") {
            UIPasteboard.general.string = ipAddress
        }
    }
    
    
    private func showTextInputAlert() {
        let alertController = UIAlertController(title: "上传文字", message: "输入要上传的文字内容", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "请输入文字内容..."
            textField.clearButtonMode = .whileEditing
        }
        
        let uploadAction = UIAlertAction(title: "上传", style: .default) { [weak self, weak alertController] _ in
            guard let textField = alertController?.textFields?.first,
                  let text = textField.text,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self?.showAlert(title: "错误", message: "文字内容不能为空")
                return
            }
            
            self?.uploadTextContent(text)
        }
        
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        
        alertController.addAction(uploadAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    
    private  func uploadTextContent(_ text: String) {
        DebugFileTransferServer.shared.uploadTextContent(text) {[weak self] fileName, textData in
            self?.showAlert(title: "上传成功", message: "文字内容已上传为文件：\(fileName)\n大小：\(textData.count) bytes")
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            self?.handleSelectedMedia(info: info)
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func handleSelectedMedia(info: [UIImagePickerController.InfoKey : Any]) {
        // 显示上传进度
        let progressAlert = UIAlertController(title: "正在处理文件", message: "请稍候...", preferredStyle: .alert)
        present(progressAlert, animated: true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var fileName: String = ""
            var fileData: Data?
            
            // 处理图片
            if let image = info[.originalImage] as? UIImage {
                fileName = DebugFileTransferServer.shared.imageName()
                fileData = image.jpegData(compressionQuality: 0.8)
                 DebugFileTransferServer.shared.log("web_test📷 处理图片: \(fileName), 原始尺寸: \(image.size), 数据大小: \(fileData?.count ?? 0) bytes")
            }
            // 处理视频
            else if let videoURL = info[.mediaURL] as? URL {
                fileName = "视频_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)).\(videoURL.pathExtension)"
                do {
                    fileData = try Data(contentsOf: videoURL)
                     DebugFileTransferServer.shared.log("web_test🎥 处理视频: \(fileName), 数据大小: \(fileData?.count ?? 0) bytes")
                } catch {
                     DebugFileTransferServer.shared.log("web_test❌ 读取视频失败: \(error)")
                    DispatchQueue.main.async {
                        progressAlert.dismiss(animated: true) {
                            self?.showAlert(title: "错误", message: "读取视频文件失败: \(error.localizedDescription)")
                        }
                    }
                    return
                }
            }
            
            guard let data = fileData else {
                DispatchQueue.main.async {
                    progressAlert.dismiss(animated: true) {
                        self?.showAlert(title: "错误", message: "无法处理选择的文件")
                    }
                }
                return
            }
            
            // 上传文件
            DebugFileTransferServer.shared.uploadFile(name: fileName, data: data)
            
            DispatchQueue.main.async {
                progressAlert.dismiss(animated: true) {
                    self?.showAlert(title: "上传成功", message: "文件 \(fileName) 已上传到服务器\n大小: \(self?.formatFileSize(data.count) ?? "未知")")
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
 
    
    private func presentDocumentPicker(for types: [String]) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: types, in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = true
        present(documentPicker, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate
extension DebugFileUploadViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            uploadFile(at: url)
        }
    }
    
    private func uploadFile(at url: URL) {
         DebugFileTransferServer.shared.log("web_test📄 尝试上传文件: \(url.path)")
         DebugFileTransferServer.shared.log("web_test📄 文件URL: \(url)")
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: url.path) else {
             DebugFileTransferServer.shared.log("web_test❌ 文件不存在: \(url.path)")
            showAlert(title: "错误", message: "文件不存在")
            return
        }
        
        // 尝试访问安全作用域资源
        let hasAccess = url.startAccessingSecurityScopedResource()
         DebugFileTransferServer.shared.log("web_test📄 安全作用域访问: \(hasAccess)")
        
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            // 尝试多种方式读取文件
            var data: Data?
            var fileName: String = url.lastPathComponent
            
            // 方法1: 直接读取
            if let directData = try? Data(contentsOf: url) {
                data = directData
                 DebugFileTransferServer.shared.log("web_test✅ 直接读取成功")
            }
            // 方法2: 通过文件协调器读取
            else {
                var coordinatorError: NSError?
                var coordinatedData: Data?
                
                let coordinator = NSFileCoordinator()
                coordinator.coordinate(readingItemAt: url, options: [], error: &coordinatorError) { (readingURL) in
                    do {
                        coordinatedData = try Data(contentsOf: readingURL)
                         DebugFileTransferServer.shared.log("web_test✅ 协调器读取成功")
                    } catch {
                         DebugFileTransferServer.shared.log("web_test❌ 协调器读取失败: \(error)")
                    }
                }
                
                if let error = coordinatorError {
                     DebugFileTransferServer.shared.log("web_test❌ 文件协调器错误: \(error)")
                }
                
                data = coordinatedData
            }
            
            guard let fileData = data else {
                throw NSError(domain: "FileReadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取文件数据"])
            }
            
            // URL解码文件名
            if let decodedName = fileName.removingPercentEncoding {
                fileName = decodedName
            }
            
             DebugFileTransferServer.shared.log("web_test📄 上传文档: \(fileName), 大小: \(fileData.count) bytes")
            
            DebugFileTransferServer.shared.uploadFile(name: fileName, data: fileData)
            
            showAlert(title: "上传成功", message: "文件 \(fileName) 已上传到服务器\n大小：\(formatFileSize(fileData.count))")
            
        } catch {
             DebugFileTransferServer.shared.log("web_test❌ 读取文档失败: \(error)")
            showAlert(title: "上传失败", message: "读取文件失败: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - String Extension for Regex
extension String {
  fileprivate  func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.compactMap {
                guard let range = Range($0.range, in: self) else { return nil }
                return String(self[range])
            }
        } catch {
             DebugFileTransferServer.shared.log("web_test❌ 正则表达式错误: \(error)")
            return []
        }
    }
}

