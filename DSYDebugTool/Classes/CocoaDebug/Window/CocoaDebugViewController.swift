//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit

class CocoaDebugViewController: UIViewController {
    
    var bubble = Bubble(frame: CGRect(origin: .zero, size: Bubble.size))
    var uiBlockingBubble = UIBlockingBubble(frame: CGRect(origin: .zero, size: UIBlockingBubble.size))
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // 尺寸未发生变化（如冷启动初次触发非旋转事件）时不执行横竖屏重排
        guard size != view.bounds.size else { return }
        let oldBounds = view.bounds
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.bubble.updateOrientation(newSize: size, oldSize: oldBounds.size)
        }, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear

        bubble.center = Bubble.originalPosition
        bubble.delegate = self
        view.addSubview(bubble)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 防御性保护：确保 bubble 始终在可视安全区内，防止因旋转或持久化脏数据越界丢失
        let safeBounds = view.bounds
        if safeBounds.width > 0 && safeBounds.height > 0 {
            let center = bubble.center
            let topInset = view.safeAreaInsets.top > 0 ? view.safeAreaInsets.top : 44.0
            let bottomInset = view.safeAreaInsets.bottom > 0 ? view.safeAreaInsets.bottom : 34.0
            
            let minX = bubble.bounds.width / 2
            let maxX = max(minX, safeBounds.width - bubble.bounds.width / 2)
            let minY = topInset + bubble.bounds.height / 2
            let maxY = max(minY, safeBounds.height - bottomInset - bubble.bounds.height / 2)
            
            let clampedX = max(minX, min(maxX, center.x))
            let clampedY = max(minY, min(maxY, center.y))
            
            if clampedX != center.x || clampedY != center.y {
                bubble.center = CGPoint(x: clampedX, y: clampedY)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WindowHelper.shared.displayedList = false
        // 浮标重新出现时，显式将 KeyWindow 归还给主工程窗口
        WindowHelper.shared.restoreKeyWindowToHostApp()
        
        if CocoaDebugSettings.shared.enableUIBlockingMonitoring {
            view.addSubview(uiBlockingBubble)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if CocoaDebugSettings.shared.enableUIBlockingMonitoring {
            uiBlockingBubble.updateFrame()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if CocoaDebugSettings.shared.enableUIBlockingMonitoring {
            uiBlockingBubble.removeFromSuperview()
        }
    }
    
    func shouldReceive(point: CGPoint) -> Bool {
        if WindowHelper.shared.displayedList {
            return true
        }
        if CocoaDebugSettings.shared.enableUIBlockingMonitoring && uiBlockingBubble.superview != nil {
            return bubble.frame.contains(point) || uiBlockingBubble.frame.contains(point)
        }
        return bubble.frame.contains(point)
    }
}

//MARK: - BubbleDelegate
extension CocoaDebugViewController: BubbleDelegate {
    
    func didTapBubble() {
        WindowHelper.shared.displayedList = true
        let storyboard = UIStoryboard(name: "Manager", bundle: Bundle(for: CocoaDebug.self))
        guard let vc = storyboard.instantiateInitialViewController() else {return}
        if #available(iOS 13.0, *) {
            vc.overrideUserInterfaceStyle = .dark
        }
        vc.view.backgroundColor = "#1f2124".hexColor
        vc.modalPresentationStyle = .fullScreen
        self.present(vc, animated: true) { [weak self] in
            // 进入全屏后，临时激活为 KeyWindow 以便在控制台搜索栏内输入过滤文字
            self?.view.window?.makeKey()
        }
    }
}
