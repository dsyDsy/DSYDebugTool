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
    /// 最近一次截图的原始图片
    private var lastScreenshotImage: UIImage?
    /// 截图缩略图浮层
    private var screenshotPreviewContainer: UIView?
    
    public var screenshotHandler:((UIImage)->())?
 
    
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
    
    @objc public  func handleScreenDidChange(notification: NSNotification) {
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
        
        let container = UIView(frame: frame)
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
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(.black, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        cancelButton.addTarget(self, action: #selector(screenshotCancelTapped), for: .touchUpInside)
        
        let editButton = UIButton(type: .system)
        editButton.setTitle("编辑", for: .normal)
        editButton.setTitleColor(.yellow, for: .normal)
        editButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        editButton.addTarget(self, action: #selector(screenshotEditTapped), for: .touchUpInside)
        
        buttonContainer.addArrangedSubview(cancelButton)
        buttonContainer.addArrangedSubview(editButton)
        
        window.addSubview(container)
        window.bringSubviewToFront(container)
        screenshotPreviewContainer = container
       
        // 简单出现动画
        container.transform = CGAffineTransform(translationX: 0, y: 40)
        UIView.animate(withDuration: 0.25) {
            container.alpha = 1
            container.transform = .identity
        }
        
        // 若一段时间内未操作，自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
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
    
    /// 点击“取消”按钮
    @objc private func screenshotCancelTapped() {
        hideScreenshotPreview()
        lastScreenshotImage = nil
    }
    
    /// 点击“编辑”按钮 -> 进入 ZLImageEditor 编辑
    @objc private func screenshotEditTapped() {
        guard var image = lastScreenshotImage else {
            hideScreenshotPreview()
            return
        }
        hideScreenshotPreview()
        
        let editVC = ZLEditImageViewController(image: image)
        editVC.modalPresentationStyle = .fullScreen
        editVC.editFinishBlock = { [weak self] editedImage, _ in
            guard let self = self else { return }
            self.screenshotHandler?(editedImage)
        }
     
        
        if let topVC =  self.appWindow?.rootViewController?.topMostViewController {
            ZLImageEditorConfiguration.default()
                .editImageTools([.draw, .clip, .imageSticker, .textSticker, .mosaic, .filter, .adjust])
                .adjustTools([.brightness, .contrast, .saturation])
            let w = min(1500, image.zl.width)
            let h = w * image.zl.height / image.zl.width
            image = image.zl.resize(CGSize(width: w, height: h)) ?? image
            ZLEditImageViewController.showEditImageVC(parentVC: topVC, image: image) { resImage, editModel in
                self.screenshotHandler?(resImage)
            }
        } else {
            // 找不到可展示控制器时直接处理编辑结果为原图
            self.screenshotHandler?(image)
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
