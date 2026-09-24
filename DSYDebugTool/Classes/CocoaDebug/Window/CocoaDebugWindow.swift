//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit

protocol WindowDelegate: AnyObject {
    func isPointEvent(point: CGPoint) -> Bool
}

public class CocoaDebugWindow: UIWindow {
    
    weak var delegate: WindowDelegate?
    
    // 只有在全屏列表展开时才允许成为 Key Window，浮标状态下绝不抢占 Key Window
    public override var canBecomeKey: Bool {
        return WindowHelper.shared.isListViewBeingDisplayed
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWindow()
    }
    
    @available(iOS 13.0, *)
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setupWindow()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupWindow() {
        self.backgroundColor = .clear
        // 使用 statusBar + 100（约 1100），既能在普通视图之上，又不会干扰系统 Alert(2000)
        self.windowLevel = UIWindow.Level(UIWindow.Level.statusBar.rawValue + 100)
    }
    
    // 精确命中测试：仅在点击自身子控件时消费，背景透明区域彻底穿透给主 App
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        // 如果点击的是 Window 本身或 rootViewController 的透明根 View，直接穿透
        if hitView == self || hitView == rootViewController?.view {
            return nil
        }
        return hitView
    }
}

extension WindowHelper: WindowDelegate {
    func isPointEvent(point: CGPoint) -> Bool {
        return self.vc.shouldReceive(point: point)
    }
}
