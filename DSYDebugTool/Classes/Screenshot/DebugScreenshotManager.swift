//
//  DebugScreenshotManager.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/5.
//

import UIKit

public class DebugScreenshotManager:NSObject {
    public  static let shared = DebugScreenshotManager()
    /// 当前截屏的视图，用户监听到截图时模拟用户截屏动作
    public var currentSreenshotHandle:(()->UIWindow?)?
    /// 背景颜色
    public var backgroundColor:UIColor = .white.withAlphaComponent(0.8)
    /// 距离底部距离
    public var containerBottomY:CGFloat = 150
    
    /// 自动隐藏事件
    public  var autoHideTime:Int = 8{
        didSet{
            currentInterval = autoHideTime
        }
    }
    /// 最近一次截图的原始图片
    private var lastScreenshotImage: UIImage?
    /// 截图缩略图浮层
    private var screenshotPreviewContainer: DebugScreenshotContentView?
 
    /// 开启系统截屏通知，默认开启
    public var isEnableSystemMonitoring:Bool {
        get{
            if  let value = DebugKeychainManager.load("debug_open_didTakeScreenshot") {
                return value == "1"
            }
            DebugKeychainManager.save("1", forKey: "debug_open_didTakeScreenshot")
            return true
        }
        set{
            if newValue == true {
                DebugKeychainManager.save("1", forKey: "debug_open_didTakeScreenshot")
            }else{
                DebugKeychainManager.save("0", forKey: "debug_open_didTakeScreenshot")
            }
        }
    }
    
    private  var appWindow:UIWindow?{
        currentSreenshotHandle?()
    }
    
    private var timer: Timer?
    private var currentInterval:Int = 0
    
    override init() {
        super.init()
        currentInterval = autoHideTime
        NotificationCenter.default.addObserver(self, selector: #selector(handleSystemScreenDidChange), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreenDidChange), name: NSNotification.Name(rawValue: "DebugScreenshotManager_screenshotName"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleVideoDidChange), name:  UIScreen.capturedDidChangeNotification, object: nil)
     
    }
    
    public func didScreenshot(){
       self.handleScreenDidChange(notification: NSNotification(name: UIApplication.userDidTakeScreenshotNotification, object: nil))
    }
    
    @objc  func handleVideoDidChange(notification: NSNotification) {
        guard isEnableSystemMonitoring == true else {return}
        if UIScreen.main.isCaptured == true { /// 正在录制屏幕
            
        }else {
            /// 可能结束录制
//            展示 弹框
            // 2. 更多选项（系统分享）
            if let topVC =  self.appWindow?.rootViewController?.topMostViewController {
                let moreAction = ActionItem(title: "快速上传", style: .default) {
                    let imagePicker = UIImagePickerController()
                    imagePicker.sourceType = .photoLibrary
                    imagePicker.delegate = self
                    imagePicker.allowsEditing = false
                    imagePicker.mediaTypes = ["public.movie"]
                    topVC.present(imagePicker, animated: true)
                }
                DebugActionSheetHelper.show(actions: [moreAction], presentingViewController: topVC)
            }
           
        }
    }
    
    @objc   func handleSystemScreenDidChange(notification: NSNotification) {
        guard isEnableSystemMonitoring == true else {return}
        self.handleScreenDidChange(notification: notification)
//        DebugScreenshotLastDetector.screenshotTaken { image in
//            if let image = image {
//                self.lastScreenshotImage = image
//                self.showScreenshotPreview(with: image)
//            }else {
//                self.handleScreenDidChange(notification: notification)
//            }
//        }
       
    }
    
    @objc   func handleScreenDidChange(notification: NSNotification) {
        guard let appWindow = appWindow else { return }
        // 确保在主线程执行截屏与 UI 操作
        DispatchQueue.main.async {
            // 使用 UIGraphicsImageRenderer 截取当前窗口内容，稳定性更好
            let renderer = UIGraphicsImageRenderer(bounds: appWindow.bounds)
            let screenshot = renderer.image { ctx in
                appWindow.drawHierarchy(in: appWindow.bounds, afterScreenUpdates: true)
            }
            self.lastScreenshotImage = screenshot
            self.showScreenshotPreview(with: screenshot)
        }
    }

}


// MARK: - 截图缩略图与编辑流程

extension DebugScreenshotManager {
    
    /// 展示截图缩略图浮层，右上角显示，底部带“取消 / 编辑”按钮
    /// 预览视图尺寸根据屏幕等比计算，不使用固定宽高
    private func showScreenshotPreview(with image: UIImage) {
        guard let window = appWindow else {
            screenshotPreviewContainer?.removeFromSuperview()
            screenshotPreviewContainer = nil
            self.stopTimer()
            return
        }
        self.stopTimer()

        // 若已存在旧的预览视图，先移除
        if let container = screenshotPreviewContainer {
            container.removeFromSuperview()
            screenshotPreviewContainer = nil
        }
        
        // 按屏幕尺寸等比计算缩略图尺寸，例如占用宽高的 35%
        let screenSize = window.bounds.size
        let scale: CGFloat = 0.35
        let containerWidth: CGFloat = screenSize.width * scale
        let containerHeight: CGFloat = screenSize.height * scale
        
        let frame = CGRect(
            // 右上角：考虑 safeAreaInsets
            x: window.bounds.width - containerWidth - 16 - window.safeAreaInsets.right,
            y: window.bounds.size.height-containerHeight-containerBottomY,
            width: containerWidth,
            height: containerHeight
        )
        
        let container = DebugScreenshotContentView(frame: frame)
        container.config.hideThreshold = 0.3 // 30%
        container.config.supportedDirections = [.left, .right,.up,.down] // 只支持左右滑动
        // 回调
        container.onHide = { [weak self] direction in
            print("视图隐藏，方向: \(direction)")
            self?.hideScreenshotPreview()
        }
        container.backgroundColor = backgroundColor
        container.layer.cornerRadius = 6
        container.clipsToBounds = true
        container.alpha = 0
        
        let imageView = UIImageView(image: image)
        // 按宽高比完整展示截图
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.clipsToBounds = true
        container.addSubview(imageView)
        
        let buttonHeight: CGFloat = 40
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor,constant:5),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor,constant:5),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor,constant:-5),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -buttonHeight)
        ])
        
        let buttonContainer = UIStackView()
        buttonContainer.axis = .horizontal
        buttonContainer.distribution = .fillEqually
        buttonContainer.alignment = .fill
        buttonContainer.spacing = 0
        container.addSubview(buttonContainer)
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            buttonContainer.heightAnchor.constraint(equalToConstant: buttonHeight)
        ])
        
        let sendButton = UIButton(type: .system)
        sendButton.setTitle("发送", for: .normal)
        sendButton.setTitleColor(.green, for: .normal)
        sendButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        sendButton.addTarget(self, action: #selector(screenshotSendTapped), for: .touchUpInside)
        
        let editButton = UIButton(type: .system)
        editButton.setTitle("编辑", for: .normal)
        editButton.setTitleColor(.red, for: .normal)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        editButton.addTarget(self, action: #selector(screenshotEditTapped), for: .touchUpInside)
        
        buttonContainer.addArrangedSubview(editButton)
        buttonContainer.addArrangedSubview(sendButton)
        
        window.addSubview(container)
        window.bringSubviewToFront(container)
        screenshotPreviewContainer = container
       
//        // 简单出现动画
        container.transform = CGAffineTransform(translationX: 0, y: 40)
        container.show()
        
        // 若一段时间内未操作，自动隐藏
        currentInterval = autoHideTime
        startTimer()
       
    }
    
    /// 隐藏并移除截图预览视图
    private func hideScreenshotPreview() {
        guard let container = screenshotPreviewContainer else { return }
        screenshotPreviewContainer = nil
        UIView.animate(withDuration: 0.2, animations: {
            container.alpha = 0
        }) { _ in
            container.removeFromSuperview()
        }
    }
    
    /// 点击“发送”按钮
    @objc private func screenshotSendTapped() {
        hideScreenshotPreview()
        if let image = lastScreenshotImage {
            self.screenshotUpload(image: image)
        }
        lastScreenshotImage = nil
       
    }
    
    /// 点击“编辑”按钮
    @objc private func screenshotEditTapped() {
        guard var image = lastScreenshotImage else {
            hideScreenshotPreview()
            return
        }
        hideScreenshotPreview()
        
        if let topVC =  self.appWindow?.rootViewController?.topMostViewController {
         
            let configuration = ZLImageEditorConfiguration.default()
                .editImageTools([.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter, .adjust])
                .adjustTools([.brightness, .contrast, .saturation])
//            var colors = ZLImageEditorConfiguration.default().drawColors
//            colors.removeFirst()
//            colors.removeFirst()
//            colors.insert(.black, at: 1)
//            colors.insert(.white, at: 1)
//            configuration.drawColors(colors)
//            configuration.textStickerTextColors(colors)
            configuration.textStickerDefaultTextColor =   .zl.rgba(249, 80, 81)
            configuration.defaultDrawColor =    configuration.textStickerDefaultTextColor
            
            let w = min(1500, image.zl.width)
            let h = w * image.zl.height / image.zl.width
            image = image.zl.resize(CGSize(width: w, height: h)) ?? image
            let vc = ZLEditImageViewController(image: image, editModel: nil)
            vc.editFinishBlock = {[weak self] resImage, editImageModel in
                self?.screenshotUpload(image: resImage)
            }
            vc.cancelBlock = { [weak self] in
                if let image = self?.lastScreenshotImage {
                    self?.showScreenshotPreview(with: image)
                }
            }
            vc.modalPresentationStyle = .custom
            topVC.present(vc, animated: true, completion: nil)
        }
    }

    func screenshotUpload(image:UIImage){
        // 保存
        self.saveImage(image) { result in
            switch result {
            case .success:
                print("保存成功")
            case .failure(let error):
                print("保存失败: \(error.localizedDescription)")
            }
        }
        
        if let topVC =  self.appWindow?.rootViewController?.topMostViewController {
            // 1. 快速分享
            let fastAction = ActionItem(title: "快速分享", style: .default) {
                if let fileData = image.jpegData(compressionQuality: 1) {
                    let fileName =  DebugFileTransferServer.shared.imageName()
                    if  DebugFileTransferServer.shared.isRunning {
                        DebugFileTransferServer.shared.uploadFile(name: fileName, data: fileData )
                        let address = DebugFileTransferServer.shared.getCompleteAddress() ?? ""
                        DebugActionSheetHelper.showAlert(message: "发送完成，🌐 服务器地址：\(address)",actions: [UIAlertAction.init(title: "复制链接", style: .default,handler: { _ in
                            UIPasteboard.general.string = address
                        })],presentingViewController: topVC)
                    }else{
                        DebugFileTransferServer.shared.startServer { success, address in
                            if success, let address = address {
                                DebugFileTransferServer.shared.uploadFile(name: fileName, data: fileData)
                                DebugActionSheetHelper.showAlert(message: "发送完成，🌐 服务器地址：\(address)",actions: [UIAlertAction.init(title: "复制链接", style: .default,handler: { _ in
                                    UIPasteboard.general.string = address
                                })],presentingViewController: topVC)
                            }else {
                                DebugActionSheetHelper.showAlert(message: "服务开启失败，不支持发送。请再次尝试......", presentingViewController: topVC)
                            }
                        }
                    }
                  
                }else {
                    DebugActionSheetHelper.showAlert(message: "图片处理失败", presentingViewController: topVC)
                }
            }
            // 2. 更多选项（系统分享）
            let moreAction = ActionItem(title: "more", style: .default) {
                let items: [Any] = [image]
                let activity = CustomShareActivity.init(title: "快速分享", image: nil) {
                    fastAction.handler?()
                }
                DebugActionSheetHelper.showSystemShare(items: items,activities: [activity], presentingViewController: topVC)
            }
            DebugActionSheetHelper.show(actions: [fastAction,moreAction], presentingViewController: topVC)
        }
    }

}

extension DebugScreenshotManager {
    internal func startTimer() {
        if self.currentInterval == 0 {
            stopTimer()
            return
        }
        let currentTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentInterval -= 1
            if  self.currentInterval <= 0 {
                self.hideScreenshotPreview()
            }
        }
        RunLoop.current.add(currentTimer, forMode: .common)
        timer = currentTimer
    }
    
    internal func stopTimer() {
        currentInterval = 0
        timer?.invalidate()
        timer = nil
    }
}


import UIKit
import Photos

extension DebugScreenshotManager {
    
    func saveImage(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        // 检查权限
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        if status == .authorized || status == .limited {
            saveToPhotoLibrary(image, completion: completion)
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self.saveToPhotoLibrary(image, completion: completion)
                    } else {
                        completion(.failure(NSError(domain: "PhotoLibrary",
                                                   code: -1,
                                                   userInfo: [NSLocalizedDescriptionKey: "相册权限被拒绝"])))
                    }
                }
            }
        } else {
            completion(.failure(NSError(domain: "PhotoLibrary",
                                       code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "没有相册权限"])))
        }
    }
    
    private  func saveToPhotoLibrary(_ image: UIImage, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            // 创建保存请求
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }
}

extension DebugScreenshotManager:UIImagePickerControllerDelegate & UINavigationControllerDelegate{
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            self?.handleSelectedMedia(info: info)
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    private func handleSelectedMedia(info: [UIImagePickerController.InfoKey : Any]) {
        guard let  topVC = self.appWindow?.rootViewController?.topMostViewController else { return }
        // 显示上传进度
        let progressAlert = UIAlertController(title: "正在处理文件", message: "请稍候...", preferredStyle: .alert)
        topVC.present(progressAlert, animated: true)
        
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
            DispatchQueue.main.async {
                if  DebugFileTransferServer.shared.isRunning {
                    DebugFileTransferServer.shared.uploadFile(name: fileName, data: data)
                    let address = DebugFileTransferServer.shared.getCompleteAddress() ?? ""
                    progressAlert.dismiss(animated: true) {
                        self?.showAlert(title: "上传成功,🌐 服务器地址：\(address)", message: "文件 \(fileName) 已上传到服务器\n大小: \(self?.formatFileSize(data.count) ?? "未知")") {
                            UIPasteboard.general.string = address
                        }
                    }
                }else{
                    DebugFileTransferServer.shared.startServer {[weak self] success, address in
                        if success, let address = address {
                            // 上传文件
                            DebugFileTransferServer.shared.uploadFile(name: fileName, data: data)
                            let address = DebugFileTransferServer.shared.getCompleteAddress() ?? ""
                            progressAlert.dismiss(animated: true) {
                                self?.showAlert(title: "上传成功,🌐 服务器地址：\(address)", message: "文件 \(fileName) 已上传到服务器\n大小: \(self?.formatFileSize(data.count) ?? "未知")") {
                                    UIPasteboard.general.string = address
                                }
                            }
                        }else {
                            let address = DebugFileTransferServer.shared.getCompleteAddress() ?? ""
                            progressAlert.dismiss(animated: true) {
                                self?.showAlert(title: "服务开启失败，不支持发送。请再次尝试......", message: "")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        guard let  topvc = self.appWindow?.rootViewController?.topMostViewController else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completion?()
        })
        topvc.present(alert, animated: true)
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
 
}

extension UIViewController {
    
    var topMostViewController: UIViewController {
        
        if let presented = self.presentedViewController {
            return presented.topMostViewController
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController ?? tab
        }
        
        return self
    }
}


