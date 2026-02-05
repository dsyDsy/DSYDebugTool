//
//  DebugScreenshotManager.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/5.
//

import UIKit

public class DebugScreenshotManager {
    public  static let shared = DebugScreenshotManager()
    public weak var appWindow:UIWindow?
    /// 自动隐藏事件
    public  var autoHideTime:Double = 8
    /// 最近一次截图的原始图片
    private var lastScreenshotImage: UIImage?
    /// 截图缩略图浮层
    private var screenshotPreviewContainer: DebugScreenshotContentView?
 
    
    public var isEnableMonitoring:Bool {
        get{
            if UserDefaults.standard.value(forKey: "debug_open_didTakeScreenshot") == nil {
                return true /// 默认开启
            }
            return UserDefaults.standard.bool(forKey: "debug_open_didTakeScreenshot")
        }
        set{
            UserDefaults.standard.set(newValue, forKey: "debug_open_didTakeScreenshot")
            UserDefaults.standard.synchronize()
        }
       
    }
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreenDidChange), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }
    
    public func didScreenshot(){
       self.handleScreenDidChange(notification: NSNotification(name: UIApplication.userDidTakeScreenshotNotification, object: nil))
    }
    
    @objc   func handleScreenDidChange(notification: NSNotification) {
        guard isEnableMonitoring == true,let appWindow = appWindow else { return }
        // 确保在主线程执行截屏与 UI 操作
        DispatchQueue.main.async {
            // 使用 UIGraphicsImageRenderer 截取当前窗口内容，稳定性更好
            let renderer = UIGraphicsImageRenderer(bounds: appWindow.bounds)
            let screenshot = renderer.image { ctx in
                appWindow.layer.render(in: ctx.cgContext)
            }
            self.lastScreenshotImage = screenshot
            self.showScreenshotPreview(with: screenshot)
        }
    }

}


// MARK: - 截图缩略图与编辑流程
import ZLImageEditor
extension DebugScreenshotManager {
    
    /// 展示截图缩略图浮层，右上角显示，底部带“取消 / 编辑”按钮
    /// 预览视图尺寸根据屏幕等比计算，不使用固定宽高
    private func showScreenshotPreview(with image: UIImage) {
        guard let window = appWindow else { return }
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
            y: window.safeAreaInsets.top + 40,
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
        container.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        container.layer.cornerRadius = 6
        container.clipsToBounds = true
        container.alpha = 0
        
        let imageView = UIImageView(image: image)
        // 按宽高比完整展示截图
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
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
        editButton.setTitleColor(.yellow, for: .normal)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideTime) { [weak self] in
            self?.hideScreenshotPreview()
        }
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
            self.screenshotUpload(isSend: true, image: image)
        }
        lastScreenshotImage = nil
       
    }
    
    /// 点击“编辑”按钮 -> 进入 ZLImageEditor 编辑
    @objc private func screenshotEditTapped() {
        guard var image = lastScreenshotImage else {
            hideScreenshotPreview()
            return
        }
        hideScreenshotPreview()
        
        
        if let topVC =  self.appWindow?.rootViewController?.topMostViewController {
            ZLImageEditorConfiguration.default()
                .editImageTools([.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter, .adjust])
                .adjustTools([.brightness, .contrast, .saturation])
            let w = min(1500, image.zl.width)
            let h = w * image.zl.height / image.zl.width
            image = image.zl.resize(CGSize(width: w, height: h)) ?? image
            ZLEditImageViewController.showEditImageVC(parentVC: topVC, image: image) { resImage, editModel in
                self.screenshotUpload(isSend: false, image: resImage)
            }
        }
    }

    func screenshotUpload(isSend:Bool,image:UIImage){
        if isSend {
            // 使用方式
            self.saveImage(image) { result in
                switch result {
                case .success:
                    print("保存成功")
                case .failure(let error):
                    print("保存失败: \(error.localizedDescription)")
                }
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


