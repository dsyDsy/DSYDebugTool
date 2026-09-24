//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit

public class WindowHelper: NSObject {
    public static let shared = WindowHelper()
    
    public var window: CocoaDebugWindow
    var displayedList = false
    lazy var vc = CocoaDebugViewController() //must lazy init, otherwise crash
    
    //UIBlocking
//    fileprivate var uiBlockingCounter = UIBlockingCounter()
//    var uiBlockingCallback:((Int) -> Void)?
    
    
    private override init() {
        // 初始 fallback 使用屏幕物理尺寸，防止 Scene 接入前 window 为 0x0
        window = CocoaDebugWindow(frame: UIScreen.main.bounds)
        super.init()
    }
    
    public func enable() {
        // 1. 尝试绑定活跃 Scene 与几何尺寸
        attachToActiveScene()
        
        if window.rootViewController != vc {
            window.rootViewController = vc
            window.delegate = self
        }
        window.isHidden = false
        
        // 2. 注册系统场景生命周期与激活通知，应对启动时序问题
        if #available(iOS 13.0, *) {
            NotificationCenter.default.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIScene.willConnectNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSceneActivated),
                name: UIScene.didActivateNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSceneActivated),
                name: UIScene.willConnectNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSceneActivated),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        
        // 3. 在下一个 Runloop 异步兜底（此时 SceneDelegate.willConnectTo 通常已执行完成）
        DispatchQueue.main.async { [weak self] in
            self?.attachToActiveScene()
            self?.window.isHidden = false
        }
        
        if CocoaDebugSettings.shared.enableUIBlockingMonitoring == true {
            startUIBlockingMonitoring()
        }
    }
    
    public func disable() {
        if window.rootViewController == nil {
            return
        }
        window.rootViewController = nil
        window.delegate = nil
        window.isHidden = true
        NotificationCenter.default.removeObserver(self)
        stopUIBlockingMonitoring()
    }
    
    @available(iOS 13.0, *)
    @objc private func handleSceneActivated() {
        attachToActiveScene()
        window.isHidden = false
    }
    
    private func attachToActiveScene() {
        if #available(iOS 13.0, *) {
            // 优先查找处于 foregroundActive 的窗口场景，次选任意可用 UIWindowScene
            let activeScene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }
                ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            
            if let targetScene = activeScene {
                if window.windowScene != targetScene {
                    window.windowScene = targetScene
                }
                let sceneBounds = targetScene.coordinateSpace.bounds
                window.frame = sceneBounds != .zero ? sceneBounds : UIScreen.main.bounds
                window.rootViewController?.view.setNeedsLayout()
                return
            }
        }
        // 兜底尺寸，确保启动初期的 window 始终有可视物理尺寸
        if window.frame == .zero {
            window.frame = UIScreen.main.bounds
        }
    }
    
    public func startUIBlockingMonitoring() {
//        uiBlockingCounter.startMonitoring()
        _RunloopMonitor.shared().begin()
    }

    public func stopUIBlockingMonitoring() {
//        uiBlockingCounter.stopMonitoring()
        _RunloopMonitor.shared().end()
    }
    
    
    public var isListViewBeingDisplayed:Bool {
        return self.displayedList
    }
    
    /// 将 KeyWindow 显式归还给主工程主窗口，防止输入法焦点或系统弹窗失效
    public func restoreKeyWindowToHostApp() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 13.0, *) {
                let hostWindow = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0 != self.window && $0.windowLevel == .normal }
                hostWindow?.makeKey()
            } else {
                UIApplication.shared.delegate?.window??.makeKey()
            }
        }
    }
    
  public  func screenshot(){
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DebugScreenshotManager_screenshotName"), object: nil, userInfo: nil)
    }
}


// MARK: - UIBlockingCounterDelegate
//extension WindowHelper: UIBlockingCounterDelegate {
//    @objc public func uiBlockingCounter(_ counter: UIBlockingCounter, didUpdateFramesPerSecond uiBlocking: Int) {
//        if let uiBlockingCallback = uiBlockingCallback {
//            uiBlockingCallback(uiBlocking)
//        }
//    }
//}

