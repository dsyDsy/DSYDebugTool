//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

protocol BubbleDelegate: AnyObject {
    func didTapBubble()
}

//https://httpcodes.co/status/
private var _successStatusCodes = ["200","201","202","203","204","205","206","207","208","226"]
private var _informationalStatusCodes = ["100","101","102","103","122"]
private var _redirectionStatusCodes = ["300","301","302","303","304","305","306","307","308"]

private var _width: CGFloat {
    CocoaDebugSettings.shared.bubbleSettings.size.width
}
private var _height: CGFloat {
    CocoaDebugSettings.shared.bubbleSettings.size.height
}

class Bubble: UIView {
    
    weak var delegate: BubbleDelegate?
    
    public var width: CGFloat = _width
    public var height: CGFloat = _height
    
    private var numberLabel: UILabel? = {
        return UILabel.init()
    }()
    private var networkNumber: Int = 0
    
    
    static var originalPosition: CGPoint {
        let screenBounds = UIScreen.main.bounds
        let safeAreaTop: CGFloat = 44.0
        let safeAreaBottom: CGFloat = 34.0
        
        let minX = _width / 2
        let maxX = max(minX, screenBounds.width - _width / 2)
        let minY = safeAreaTop + _height / 2
        let maxY = max(minY, screenBounds.height - safeAreaBottom - _height / 2)
        
        if CocoaDebugSettings.shared.bubbleFrameX != 0 && CocoaDebugSettings.shared.bubbleFrameY != 0 {
            var x = CGFloat(CocoaDebugSettings.shared.bubbleFrameX)
            var y = CGFloat(CocoaDebugSettings.shared.bubbleFrameY)
            
            // 严格做屏幕安全区边界 Clamp，防止拖动越界或换设备尺寸导致小球永久脱离屏幕
            x = max(minX, min(maxX, x))
            y = max(minY, min(maxY, y))
            
            return CGPoint(x: x, y: y)
        }
        
        let defaultY = max(minY, min(maxY, screenBounds.height / 2 - _height))
        return CGPoint(x: 1.875 + _width / 2, y: defaultY)
    }
    
    static var size: CGSize {return CGSize(width: _width, height: _height)}
    
    
    //MARK: - tool
    fileprivate func initLabelEvent(_ content: String, _ foo: Bool) {
        if content == "🚀" || content == "❌"
        {
            //step 0
            let WH: CGFloat = 20
            //step 1
            let label = UILabel()
            label.text = content
            label.font = UIFont.boldSystemFont(ofSize: 14)
            
            //step 2
            if foo == true {
                label.frame = CGRect(x: self.frame.size.width/2 - WH/2, y: self.frame.size.height/2 - WH/2, width: WH, height: WH)
                self.addSubview(label)
            } else {
                label.frame = CGRect(x: self.center.x - WH/2, y: self.center.y - WH/2, width: WH, height: WH)
                self.superview?.addSubview(label)
            }
            //step 3
            UIView.animate(withDuration: 0.8, animations: {
                label.frame.origin.y = foo ? -100 : (self.center.y - 100)
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        }
        else
        {
            //step 0
            let WH: CGFloat = 35
            //step 1
            let label = UILabel()
            label.text = content
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.font = UIFont.boldSystemFont(ofSize: 14)
            
            if _informationalStatusCodes.contains(content) {
                label.textColor = "#4b8af7".hexColor
            }
            else if _redirectionStatusCodes.contains(content) {
                label.textColor = "#ff9800".hexColor
            }
            else {
                label.textColor = .red
            }
            
            //step 3
            if foo == true {
                label.frame = CGRect(x: self.frame.size.width/2 - WH/2, y: self.frame.size.height/2 - WH/2, width: WH, height: WH)
                self.addSubview(label)
            } else {
                label.frame = CGRect(x: self.center.x - WH/2, y: self.center.y - WH/2, width: WH, height: WH)
                self.superview?.addSubview(label)
            }
            //step 4
            UIView.animate(withDuration: 0.8, animations: {
                label.frame.origin.y = foo ? -100 : (self.center.y - 100)
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        }
    }
    
    
    fileprivate func initLayer() {
        applySettings()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(Bubble.tap))
        tapGesture.numberOfTapsRequired = 1
        self.addGestureRecognizer(tapGesture)
        
        let longTap = UILongPressGestureRecognizer.init(target: self, action: #selector(Bubble.longTap))
        longTap.minimumPressDuration = 0.5
        self.addGestureRecognizer(longTap)
        
        let doubleGesture = UITapGestureRecognizer(target: self, action: #selector(Bubble.doubletap))
        doubleGesture.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleGesture)
        tapGesture.require(toFail: doubleGesture)

    }

    fileprivate func  applySettings() {
        width = _width
        height = _height
        
        self.backgroundColor = CocoaDebugSettings.shared.bubbleSettings.backgroundColor
        self.layer.cornerRadius = width / 2
        
        if let numberLabel = numberLabel {
            numberLabel.text = String(networkNumber)
            numberLabel.textColor = CocoaDebugSettings.shared.bubbleSettings.numberLabelColor
            numberLabel.textAlignment = .center
            numberLabel.adjustsFontSizeToFitWidth = true
            numberLabel.isHidden = networkNumber == 0
            numberLabel.frame = CGRect(x: 0, y: 0, width: width, height: height)
            if numberLabel.superview == nil {
                self.addSubview(numberLabel)
            }
        }
        
        // 同步当前 frame 尺寸（保持中心不变）
        let currentCenter = self.center
        self.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        self.center = currentCenter
    }
    
    func changeSideDisplay() {
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 5, options: .curveEaseInOut, animations: {
                       }, completion: nil)
    }
    
    func updateOrientation(newSize: CGSize, oldSize: CGSize? = nil) {
        guard newSize.width > 0 && newSize.height > 0 else { return }
        
        let containerBounds = self.superview?.bounds.size ?? UIScreen.main.bounds.size
        let referenceOldSize = oldSize ?? containerBounds
        
        // 尺寸未发生变化时直接忽略，避免启动期触发非旋转事件导致坐标被误算
        if referenceOldSize.width == newSize.width && referenceOldSize.height == newSize.height {
            return
        }
        
        // Y 轴比例计算：以旧高度为参考，严格限制在 [0, 1] 比例内
        let safeOldHeight = referenceOldSize.height > 0 ? referenceOldSize.height : UIScreen.main.bounds.height
        let ratioY = max(0.0, min(1.0, center.y / safeOldHeight))
        var newY = newSize.height * ratioY
        
        // X 轴贴边计算：保留原有靠左或靠右的倾向
        let isRightSide = center.x > (referenceOldSize.width / 2.0)
        let margin = width / 8.0 * 4.25
        let newX = isRightSide ? (newSize.width - margin) : margin
        
        // 安全区边界 Clamp
        let safeTop = self.superview?.safeAreaInsets.top ?? self.window?.safeAreaInsets.top ?? 44.0
        let safeBottom = self.superview?.safeAreaInsets.bottom ?? self.window?.safeAreaInsets.bottom ?? 34.0
        let effectiveTop = safeTop > 0 ? safeTop : 44.0
        let effectiveBottom = safeBottom > 0 ? safeBottom : 34.0
        
        let minY = effectiveTop + height / 2.0
        let maxY = max(minY, newSize.height - effectiveBottom - height / 2.0)
        newY = max(minY, min(maxY, newY))
        
        self.center = CGPoint(x: newX, y: newY)
        
        // 旋转后同步更新持久化位置
        CocoaDebugSettings.shared.bubbleFrameX = Float(newX)
        CocoaDebugSettings.shared.bubbleFrameY = Float(newY)
    }
    
    //MARK: - init
    override init(frame: CGRect) {
        super.init(frame: frame)
        initLayer()
        
        //添加手势
        let selector = #selector(Bubble.panDidFire(panner:))
        let panGesture = UIPanGestureRecognizer(target: self, action: selector)
        self.addGestureRecognizer(panGesture)
        
        //notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "reloadHttp_CocoaDebug"), object: nil, queue: OperationQueue.main) { [weak self] notification in
            self?.reloadHttp_notification(notification)
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "deleteAllLogs_CocoaDebug"), object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.deleteAllLogs_notification()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "SHOW_COCOADEBUG_FORCE"), object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.show_cocoadebug_force()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("COCOADEBUG_BUBBLE_SETTINGS_CHANGED"), object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.applySettings()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        //notification
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - notification
    //网络通知
    @objc func reloadHttp_notification(_ notification: Notification) {
        
        guard let userInfo = notification.userInfo else {return}
        let statusCode = userInfo["statusCode"] as? String
        
        if _successStatusCodes.contains(statusCode ?? "") {
            self.initLabelEvent("🚀", true)
        }
        else if statusCode == "0" { //"0" means network unavailable
            self.initLabelEvent("❌", true)
        }
        else {
            guard let statusCode = statusCode else {return}
            self.initLabelEvent(statusCode, true)
        }
        
        
        self.networkNumber = (self.networkNumber ) + 1
        self.numberLabel?.text = String(networkNumber)
        
        
        if self.networkNumber == 0 {
            self.numberLabel?.isHidden = true
        } else {
            self.numberLabel?.isHidden = false
        }
        
        if networkNumber >= 0 && networkNumber < 10 {
            self.numberLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        } else if networkNumber >= 10 && networkNumber < 100 {
            self.numberLabel?.font = UIFont.boldSystemFont(ofSize: 11)
        } else if networkNumber >= 100 && networkNumber < 1000 {
            self.numberLabel?.font = UIFont.boldSystemFont(ofSize: 9)
        } else if networkNumber >= 1000 && networkNumber < 10000 {
            self.numberLabel?.font = UIFont.boldSystemFont(ofSize: 7.5)
        } else {
            self.numberLabel?.font = UIFont.boldSystemFont(ofSize: 7)
        }
    }
    
    
    @objc func deleteAllLogs_notification() {
        self.networkNumber = 0
        
        self.numberLabel?.text = String(networkNumber)
        self.numberLabel?.isHidden = false
//        if self.networkNumber == 0 {
//            self.numberLabel?.isHidden = true
//        } else {
//            self.numberLabel?.isHidden = false
//        }
    }
    
    @objc func show_cocoadebug_force() {
        CocoaDebugSettings.shared.showBubbleAndWindow = !CocoaDebugSettings.shared.showBubbleAndWindow
        CocoaDebugSettings.shared.showBubbleAndWindow = !CocoaDebugSettings.shared.showBubbleAndWindow
    }
    
    
    //MARK: - target action
    @objc func tap() {
        delegate?.didTapBubble()
    }
    
    @objc func longTap() {
        _HttpDatasource.shared().reset()
        CocoaDebugSettings.shared.networkLastIndex = 0
        NotificationCenter.default.post(name: NSNotification.Name("deleteAllLogs_CocoaDebug"), object: nil, userInfo: nil)
    }
    //MARK: - target action
    @objc func doubletap() {
        WindowHelper.shared.screenshot()
    }
    
    @objc func panDidFire(panner: UIPanGestureRecognizer) {
        if panner.state == .began {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveLinear, animations: { [weak self] in
                self?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: nil)
        }
        
        let offset = panner.translation(in: self.superview)
        panner.setTranslation(CGPoint.zero, in: self.superview)
        self.center = CGPoint(x: self.center.x + offset.x, y: self.center.y + offset.y)
        
        if panner.state == .ended || panner.state == .cancelled {
            let containerSize = self.superview?.bounds.size ?? UIScreen.main.bounds.size
            let containerWidth = containerSize.width > 0 ? containerSize.width : UIScreen.main.bounds.width
            let containerHeight = containerSize.height > 0 ? containerSize.height : UIScreen.main.bounds.height
            
            let safeInsets = self.superview?.safeAreaInsets ?? self.window?.safeAreaInsets ?? UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
            let effectiveTop = safeInsets.top > 0 ? safeInsets.top : 44.0
            let effectiveBottom = safeInsets.bottom > 0 ? safeInsets.bottom : 34.0
            
            // X 轴贴边计算：用户停在左半屏则贴左，右半屏则贴右
            let margin = self.width / 8.0 * 4.25
            let finalX = self.center.x > (containerWidth / 2.0)
                ? (containerWidth - margin)
                : margin
            
            // Y 轴真实停靠：用户松手在哪个高度就停留在哪个高度，严格限制在安全区域内，彻底杜绝速度公式把小球甩到底部
            let minY = effectiveTop + self.height / 2.0
            let maxY = max(minY, containerHeight - effectiveBottom - self.height / 2.0)
            let finalY = max(minY, min(maxY, self.center.y))
            
            // 真实持久化保存用户最终停靠坐标
            CocoaDebugSettings.shared.bubbleFrameX = Float(finalX)
            CocoaDebugSettings.shared.bubbleFrameY = Float(finalY)
            
            // 平滑弹性贴边动画
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: { [weak self] in
                self?.center = CGPoint(x: finalX, y: finalY)
                self?.transform = .identity
            }, completion: nil)
        }
    }
}

