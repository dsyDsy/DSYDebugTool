//
//  DebugScreenshotContentView.swift
//  DSYDebugTool
//
//  Created by code on 2026/2/5.
//

import UIKit

class DebugScreenshotContentView: UIView {
    
    // MARK: - 配置
    struct Configuration {
        /// 触发隐藏的阈值比例
        var hideThreshold: CGFloat = 0.3
        /// 动画持续时间
        var animationDuration: TimeInterval = 0.3
        /// 弹性效果阻尼系数
        var dampingRatio: CGFloat = 0.7
        /// 初始弹簧速度
        var initialSpringVelocity: CGFloat = 0.5
        /// 支持的方向
        var supportedDirections: Set<Direction> = [.left, .right, .up, .down]
        /// 是否启用弹性效果
        var enableBounceEffect: Bool = true
        /// 是否启用边缘吸附效果
        var enableEdgeSnap: Bool = true
        /// 是否允许拖拽超出边界
        var allowOverdrag: Bool = true
        
        static let `default` = Configuration()
    }
    
    enum Direction {
        case left, right, up, down
    }
    
    // MARK: - 属性
    private var originalCenter: CGPoint = .zero
    private var panGesture: UIPanGestureRecognizer!
    
    /// 当前配置
    var config = Configuration.default
    
    /// 隐藏回调
    var onHide: ((Direction) -> Void)?
    
    /// 拖拽进度回调 (0-1)
    var onDragProgress: ((CGFloat, Direction) -> Void)?
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(panGesture)
        self.isUserInteractionEnabled = true
    }
    
    // MARK: - 手势处理
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.superview)
        
        switch gesture.state {
        case .began:
            originalCenter = self.center
            notifyDragProgress(0, direction: .right)
            
        case .changed:
            updateViewPosition(with: translation, gesture: gesture)
            
        case .ended, .cancelled:
            handleGestureEnd(with: translation, velocity: gesture.velocity(in: self.superview))
            
        default:
            break
        }
    }
    
    // MARK: - 更新视图位置
    private func updateViewPosition(with translation: CGPoint, gesture: UIPanGestureRecognizer) {
        var newCenter = CGPoint(x: originalCenter.x + translation.x,
                               y: originalCenter.y + translation.y)
        
        // 如果不允许拖拽超出边界
        if !config.allowOverdrag, let superview = self.superview {
            let minX = self.bounds.width / 2
            let maxX = superview.bounds.width - self.bounds.width / 2
            let minY = self.bounds.height / 2
            let maxY = superview.bounds.height - self.bounds.height / 2
            
            newCenter.x = max(minX, min(maxX, newCenter.x))
            newCenter.y = max(minY, min(maxY, newCenter.y))
        }
        
        // 弹性效果
        if config.enableBounceEffect {
            applyBounceEffect(to: &newCenter, translation: translation)
        }
        
        self.center = newCenter
        
        // 通知拖拽进度
        let (progress, direction) = calculateDragProgress(with: translation)
        notifyDragProgress(progress, direction: direction)
    }
    
    // MARK: - 计算拖拽进度
    private func calculateDragProgress(with translation: CGPoint) -> (progress: CGFloat, direction: Direction) {
        let horizontalProgress = abs(translation.x) / (self.bounds.width * config.hideThreshold)
        let verticalProgress = abs(translation.y) / (self.bounds.height * config.hideThreshold)
        
        if horizontalProgress > verticalProgress {
            let direction: Direction = translation.x > 0 ? .right : .left
            let progress = min(horizontalProgress, 1.0)
            return (progress, direction)
        } else {
            let direction: Direction = translation.y > 0 ? .down : .up
            let progress = min(verticalProgress, 1.0)
            return (progress, direction)
        }
    }
    
    // MARK: - 通知拖拽进度
    private func notifyDragProgress(_ progress: CGFloat, direction: Direction) {
        onDragProgress?(progress, direction)
        
        // 视觉反馈
        let scale = 1.0 - progress * 0.1
        self.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    
    // MARK: - 弹性效果
    private func applyBounceEffect(to center: inout CGPoint, translation: CGPoint) {
        let maxDistanceX = self.bounds.width * config.hideThreshold
        let maxDistanceY = self.bounds.height * config.hideThreshold
        
        let dragRatioX = min(abs(translation.x) / maxDistanceX, 1.0)
        let dragRatioY = min(abs(translation.y) / maxDistanceY, 1.0)
        
        let resistance: CGFloat = 0.4
        let resistanceFactor = 1.0 - (max(dragRatioX, dragRatioY) * resistance)
        
        center.x = originalCenter.x + translation.x * resistanceFactor
        center.y = originalCenter.y + translation.y * resistanceFactor
    }
    
    // MARK: - 手势结束处理
    private func handleGestureEnd(with translation: CGPoint, velocity: CGPoint) {
        let (progress, direction) = calculateDragProgress(with: translation)
        
        // 检查是否支持该方向
        guard config.supportedDirections.contains(direction) else {
            resetViewPosition()
            return
        }
        
        let shouldHide = shouldHideView(progress: progress, velocity: velocity)
        
        if shouldHide {
            hideView(in: direction, velocity: velocity)
        } else {
            resetViewPosition()
        }
    }
    
    // MARK: - 判断是否应该隐藏
    private func shouldHideView(progress: CGFloat, velocity: CGPoint) -> Bool {
        // 进度超过阈值
        let distanceCondition = progress >= 1.0
        
        // 速度超过阈值（快速滑动）
        let speedThreshold: CGFloat = 600
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        let speedCondition = speed > speedThreshold
        
        return distanceCondition || speedCondition
    }
    
    // MARK: - 隐藏视图
    private func hideView(in direction: Direction, velocity: CGPoint) {
        let finalCenter = calculateFinalCenter(for: direction)
        
        // 根据速度调整动画时间
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        let duration = config.animationDuration * max(0.3, min(1.0, 800 / speed))
        
        UIView.animate(withDuration: duration,
                      delay: 0,
                      usingSpringWithDamping: config.dampingRatio,
                      initialSpringVelocity: config.initialSpringVelocity,
                      options: [.curveEaseOut]) {
            self.center = finalCenter
            self.alpha = 0.0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { _ in
            self.isHidden = true
            self.onHide?(direction)
        }
    }
    
    // MARK: - 计算最终位置
    private func calculateFinalCenter(for direction: Direction) -> CGPoint {
        guard let superview = self.superview else { return self.center }
        
        let padding: CGFloat = 50
        
        switch direction {
        case .left:
            return CGPoint(x: -self.bounds.width - padding, y: self.center.y)
        case .right:
            return CGPoint(x: superview.bounds.width + self.bounds.width + padding, y: self.center.y)
        case .up:
            return CGPoint(x: self.center.x, y: -self.bounds.height - padding)
        case .down:
            return CGPoint(x: self.center.x, y: superview.bounds.height + self.bounds.height + padding)
        }
    }
    
    // MARK: - 重置位置
    private func resetViewPosition() {
        UIView.animate(withDuration: 0.25,
                      delay: 0,
                      usingSpringWithDamping: 0.7,
                      initialSpringVelocity: 0.5,
                      options: [.curveEaseOut]) {
            if self.originalCenter != .zero {
                self.center = self.originalCenter
            }
            self.transform = .identity
            self.alpha = 1.0
            self.notifyDragProgress(0, direction: .right)
        }
    }
    
    // MARK: - 公开方法
    func show(animated: Bool = true) {
        self.isHidden = false
        self.alpha = 1.0
        
        if animated {
            resetViewPosition()
        } else {
            self.center = originalCenter
            self.transform = .identity
        }
    }
    
    func hide(in direction: Direction? = nil, animated: Bool = true) {
        let hideDirection = direction ?? .right
        
        if animated {
            hideView(in: hideDirection, velocity: .zero)
        } else {
            self.isHidden = true
            self.onHide?(hideDirection)
        }
    }
}
