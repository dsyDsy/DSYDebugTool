//
//  DebugDoubleTapDetector.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/3.
//

import UIKit

// 1. 智能双击识别器（核心组件）
public class DebugDoubleTapDetector: UITapGestureRecognizer {
    
    // 配置
    public struct Config {
        public init() {}
        var interval: TimeInterval = 0.25          // 双击间隔
        var maxDistance: CGFloat = 15.0           // 最大允许移动距离
        var visualFeedback: VisualFeedback = .scale(0.92, 0.1) // 视觉反馈类型
        var hapticFeedback: Bool = true          // 是否启用触觉反馈
        var cancelOtherGestures: Bool = false    // 是否取消其他手势
    }
    
   public enum VisualFeedback {
        case none
        case scale(CGFloat, TimeInterval)        // 缩放比例，动画时长
        case color(UIColor, TimeInterval)        // 颜色变化，动画时长
        case both(scale: CGFloat, color: UIColor, duration: TimeInterval)
    }
    
    // 状态
    private var firstTapTime: TimeInterval = 0
    private var firstTapLocation: CGPoint = .zero
    private var tapCount: Int = 0
    private var singleTapTimer: Timer?
    private var isProcessing = false
    
    // 配置
    var config = Config()
    
    // 回调
    var onDoubleTap: (() -> Void)?
    var onSingleTap: (() -> Void)?
    
    // 缓存视图的原始属性（用于动画恢复）
    private weak var targetView: UIView?
    private var originalTransform: CGAffineTransform = .identity
    private var originalBackgroundColor: UIColor?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        setup()
    }
    

    
    private func setup() {
        numberOfTapsRequired = 1
        numberOfTouchesRequired = 1
        // 重要：设置不取消触摸事件，让其他手势也能正常工作
       cancelsTouchesInView = config.cancelOtherGestures
       delaysTouchesBegan = false
       delaysTouchesEnded = false
        
        // 添加目标
        addTarget(self, action: #selector(handleGesture))
    }
    
    @objc private func handleGesture(_ gesture: UITapGestureRecognizer) {
        // 使用gesture的触摸事件进行处理
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard !isProcessing, let touch = touches.first else { return }
        
        let currentTime = CACurrentMediaTime() // 使用高精度时间
        let currentLocation = touch.location(in: view)
        
        // 第一次点击
        if tapCount == 0 {
            tapCount = 1
            firstTapTime = currentTime
            firstTapLocation = currentLocation
            
            // 记录目标视图（用于视觉反馈）
            targetView = view
            
            // 启动单击计时器
            scheduleSingleTapTimer()
        }
        // 第二次点击
        else if tapCount == 1 {
            let timeDiff = currentTime - firstTapTime
            let distance = hypot(currentLocation.x - firstTapLocation.x,
                               currentLocation.y - firstTapLocation.y)
            
            // 检查是否在有效范围内
            if timeDiff < config.interval && distance < config.maxDistance {
                tapCount = 2
                cancelSingleTapTimer()
                triggerDoubleTap()
            } else {
                // 无效的第二次点击，重新开始
                resetAndStartNew(firstTapTime: currentTime, location: currentLocation)
            }
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        resetState()
    }
    
    // MARK: - 定时器管理
    private func scheduleSingleTapTimer() {
        singleTapTimer?.invalidate()
        
        // 使用CADisplayLink代替Timer以获得更好的性能
        singleTapTimer = Timer.scheduledTimer(withTimeInterval: config.interval * 1.5, repeats: false) { [weak self] _ in
            self?.triggerSingleTap()
        }
    }
    
    private func cancelSingleTapTimer() {
        singleTapTimer?.invalidate()
        singleTapTimer = nil
    }
    
    // MARK: - 触发事件
    private func triggerSingleTap() {
        guard tapCount == 1 else { return }
        
        // 执行单击回调（如果有）
        DispatchQueue.main.async { [weak self] in
            self?.onSingleTap?()
        }
        
        resetState()
    }
    
    private func triggerDoubleTap() {
        guard !isProcessing else { return }
        isProcessing = true
        
        // 视觉反馈
        applyVisualFeedback()
        
        // 触觉反馈
        if config.hapticFeedback {
            provideHapticFeedback()
        }
        
        // 执行双击回调
        DispatchQueue.main.async { [weak self] in
            self?.onDoubleTap?()
        }
        
        // 恢复视觉状态
        DispatchQueue.main.asyncAfter(deadline: .now() + getFeedbackDuration()) { [weak self] in
            self?.restoreVisualFeedback()
            self?.resetState()
        }
    }
    
    // MARK: - 视觉反馈
    private func applyVisualFeedback() {
        guard let view = targetView else { return }
        
        // 保存原始状态
        originalTransform = view.transform
        originalBackgroundColor = view.backgroundColor
        
        switch config.visualFeedback {
        case .scale(let scale, let duration):
            UIView.animate(withDuration: duration,
                          delay: 0,
                          usingSpringWithDamping: 0.6,
                          initialSpringVelocity: 0.5,
                          options: [.curveEaseInOut, .allowUserInteraction],
                          animations: {
                view.transform = self.originalTransform.scaledBy(x: scale, y: scale)
            })
            
        case .color(let color, let duration):
            UIView.animate(withDuration: duration,
                          delay: 0,
                          options: [.curveEaseInOut, .allowUserInteraction],
                          animations: {
                view.backgroundColor = color
            })
            
        case .both(let scale, let color, let duration):
            UIView.animate(withDuration: duration,
                          delay: 0,
                          usingSpringWithDamping: 0.6,
                          initialSpringVelocity: 0.5,
                          options: [.curveEaseInOut, .allowUserInteraction],
                          animations: {
                view.transform = self.originalTransform.scaledBy(x: scale, y: scale)
                view.backgroundColor = color
            })
            
        case .none:
            break
        }
    }
    
    private func restoreVisualFeedback() {
        guard let view = targetView else { return }
        
        switch config.visualFeedback {
        case .scale(_, let duration):
            UIView.animate(withDuration: duration,
                          delay: 0,
                          usingSpringWithDamping: 0.7,
                          initialSpringVelocity: 0.3,
                          options: [.curveEaseInOut, .allowUserInteraction],
                          animations: {
                view.transform = self.originalTransform
            })
            
        case .color(_, let duration):
            UIView.animate(withDuration: duration,
                          delay: 0,
                          options: [.curveEaseInOut, .allowUserInteraction],
                          animations: {
                view.backgroundColor = self.originalBackgroundColor
            })
            
        case .both(_, _, let duration):
            UIView.animate(withDuration: duration,
                          delay: 0,
                          usingSpringWithDamping: 0.7,
                          initialSpringVelocity: 0.3,
                          options: [.curveEaseInOut, .allowUserInteraction],
                          animations: {
                view.transform = self.originalTransform
                view.backgroundColor = self.originalBackgroundColor
            })
            
        case .none:
            break
        }
    }
    
    private func getFeedbackDuration() -> TimeInterval {
        switch config.visualFeedback {
        case .scale(_, let duration): return duration
        case .color(_, let duration): return duration
        case .both(_, _, let duration): return duration
        case .none: return 0.1
        }
    }
    
    private func provideHapticFeedback() {
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
    }
    
    // MARK: - 状态管理
    private func resetAndStartNew(firstTapTime: TimeInterval, location: CGPoint) {
        cancelSingleTapTimer()
        tapCount = 1
        self.firstTapTime = firstTapTime
        self.firstTapLocation = location
        scheduleSingleTapTimer()
    }
    
    private func resetState() {
        tapCount = 0
        firstTapTime = 0
        firstTapLocation = .zero
        cancelSingleTapTimer()
        isProcessing = false
        targetView = nil
    }
    
    deinit {
        cancelSingleTapTimer()
    }
}

// 2. UIView扩展（简单API）
public extension UIView {
    func debug_addSmartDoubleTap(
        interval: TimeInterval = 0.25,
        visualFeedback: DebugDoubleTapDetector.VisualFeedback = .scale(0.92, 0.1),
        doubleTap: @escaping () -> Void,
        singleTap: (() -> Void)? = nil
    ) {
        // 移除现有双击手势
        if let existing = gestureRecognizers?.first(where: { $0 is DebugDoubleTapDetector }) {
            removeGestureRecognizer(existing)
        }
        
        let recognizer = DebugDoubleTapDetector()
        recognizer.config.interval = interval
        recognizer.config.visualFeedback = visualFeedback
        recognizer.onDoubleTap = doubleTap
        recognizer.onSingleTap = singleTap
        
        addGestureRecognizer(recognizer)
        isUserInteractionEnabled = true
    }
    
    // 高性能批量添加（用于UICollectionView/UITableView）
    func debug_addOptimizedDoubleTap(
        doubleTap: @escaping () -> Void,
        config: DebugDoubleTapDetector.Config = DebugDoubleTapDetector.Config()
    ) {
        let recognizer = DebugDoubleTapDetector()
        recognizer.config = config
        recognizer.onDoubleTap = doubleTap
        recognizer.onSingleTap = nil // 不处理单击以提升性能
        
        addGestureRecognizer(recognizer)
    }
}


