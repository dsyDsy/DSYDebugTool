//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit
extension _DirectoryContentsTableViewController:DebugTabBarDoubleTapHandler {
    public func handleTabBarDoubleTap() -> Bool {
        // 安全检查：确保视图已显示
        guard view.window != nil else {
            return false
        }
        WindowHelper.shared.screenshot()
        return true
    }
    
}


/// TabBar 双击处理协议
/// 实现此协议的页面可以响应双击 TabBar 的操作
public protocol DebugTabBarDoubleTapHandler: AnyObject {
    /// 处理双击 TabBar 事件
    /// - Returns: 是否已处理（返回 true 表示已处理，false 表示未处理或不需要处理）
    func handleTabBarDoubleTap() -> Bool
}

class CocoaDebugTabBarController: UITabBarController {
    /// 记录上次点击 tabbar 的时间
    private var lastTabBarTapTime: TimeInterval = 0
    /// 记录上次点击的 tabbar 索引
    private var lastTabBarIndex: Int = -1
    /// 双击时间间隔阈值（秒）
    private let doubleTapTimeInterval: TimeInterval = 0.5
    
    //MARK: - init
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { $0.endEditing(true) }
        } else {
            UIApplication.shared.keyWindow?.endEditing(true)
        }
        view.endEditing(true)
        
        setChildControllers()
        
        self.selectedIndex = CocoaDebugSettings.shared.tabBarSelectItem 
        self.tabBar.tintColor = Color.mainGreen
        self.view.backgroundColor = "#1f2124".hexColor
        
        configTabStyles()
    }
    
    private func configTabStyles() {
        if #available(iOS 26.0, *) {
            let appearance = UITabBarAppearance()
            // iOS 26+ 交给系统提供 TabBar 材质，避免固定背景覆盖内容层
            appearance.configureWithDefaultBackground()
            if #available(iOS 27.0, *) {
                // iOS 27+ 的系统材质由 bar appearance 决定界面样式
                appearance.overrideUserInterfaceStyle = .dark
            }
            appearance.shadowColor = .clear
            
            // 配置未选中状态
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .font: UIFont.systemFont(ofSize: 10)
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.6)
            
            // 配置选中状态
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: Color.mainGreen,
                .font: UIFont.systemFont(ofSize: 10, weight: .bold)
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            appearance.stackedLayoutAppearance.selected.iconColor = Color.mainGreen
            
            self.tabBar.standardAppearance = appearance
            self.tabBar.tintColor = Color.mainGreen
            self.tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.6)
            // 仅让 TabBar 使用暗色系统材质，不改变其他页面的界面样式
            self.tabBar.overrideUserInterfaceStyle = .dark
            self.tabBar.scrollEdgeAppearance = nil
            self.tabBar.isTranslucent = true
            // 保持根页面的导航层稳定，不跟随列表滚动自动收缩
            self.tabBarMinimizeBehavior = .never
        } else if #available(iOS 13, *) {
            // 原版样式：保持现有系统完全一致的外观
            self.tabBar.backgroundColor = "#1f2124".hexColor
            self.tabBar.barTintColor = "#1f2124".hexColor
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = "#1f2124".hexColor
            appearance.shadowColor = .clear
            self.tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                self.tabBar.scrollEdgeAppearance = appearance
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        CocoaDebugSettings.shared.visible = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CocoaDebugSettings.shared.visible = false
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        WindowHelper.shared.displayedList = false
        WindowHelper.shared.restoreKeyWindowToHostApp()
    }
    
    //MARK: - private
    func setChildControllers() {
        
        //1.
        let logs = UIStoryboard(name: "Logs", bundle: Bundle(for: CocoaDebug.self)).instantiateViewController(withIdentifier: "Logs")
        let network = UIStoryboard(name: "Network", bundle: Bundle(for: CocoaDebug.self)).instantiateViewController(withIdentifier: "Network")
        let app = UIStoryboard(name: "App", bundle: Bundle(for: CocoaDebug.self)).instantiateViewController(withIdentifier: "App")
        
        //2.
        _Sandboxer.shared.isSystemFilesHidden = false
        _Sandboxer.shared.isExtensionHidden = false
        _Sandboxer.shared.isShareable = true
        _Sandboxer.shared.isFileDeletable = true
        _Sandboxer.shared.isDirectoryDeletable = true
        _Sandboxer.shared.mainClor = Color.mainGreen
        guard let sandbox = _Sandboxer.shared.homeDirectoryNavigationController() else {return}
        sandbox.tabBarItem.title = "Sandbox"
        sandbox.tabBarItem.image = UIImage.init(named: "_icon_file_type_sandbox", in: Bundle.init(for: CocoaDebug.self), compatibleWith: nil)
        
        if #available(iOS 26.0, *) {
            // 对齐 sandbox 导航栏的 glass 材质风格
            sandbox.navigationBar.isTranslucent = true
            sandbox.navigationBar.overrideUserInterfaceStyle = .dark
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithDefaultBackground()
            if #available(iOS 27.0, *) {
                navAppearance.overrideUserInterfaceStyle = .dark
            }
            sandbox.navigationBar.standardAppearance = navAppearance
            sandbox.navigationBar.scrollEdgeAppearance = nil
        }
        
        //3.
        guard let additionalViewController = CocoaDebugSettings.shared.additionalViewController else {
            self.viewControllers = [network, logs, sandbox, app]
            return
        }
        
        //4.Add additional controller
        var temp = [network, logs, sandbox, app]
        
        let nav = UINavigationController(rootViewController: additionalViewController)
        nav.navigationBar.barTintColor = "#1f2124".hexColor
        nav.tabBarItem = UITabBarItem(tabBarSystemItem: .more, tag: 4)

        //****** copy codes from LogNavigationViewController.swift ******
        nav.navigationBar.isTranslucent = false
        
        nav.navigationBar.tintColor = Color.mainGreen
        nav.navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                                 .foregroundColor: Color.mainGreen]
        
        let selector = #selector(CocoaDebugNavigationController.exit)
        let leftItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: selector)
        leftItem.tintColor = Color.mainGreen
        nav.topViewController?.navigationItem.leftBarButtonItem = leftItem
        
        if #available(iOS 26.0, *) {
            nav.navigationBar.isTranslucent = true
            nav.navigationBar.overrideUserInterfaceStyle = .dark
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithDefaultBackground()
            if #available(iOS 27.0, *) {
                navAppearance.overrideUserInterfaceStyle = .dark
            }
            nav.navigationBar.standardAppearance = navAppearance
            nav.navigationBar.scrollEdgeAppearance = nil
        }
        //****** copy codes from LogNavigationViewController.swift ******
        
        temp.append(nav)
        
        self.viewControllers = temp
    }
    
    //MARK: - target action
    @objc func exit() {
        dismiss(animated: true, completion: nil)
    }

    /// 处理双击 TabBar 事件（通用方法）
    /// - Parameter index: 被双击的 TabBar 索引
    private func handleDoubleTap(at index: Int) {
        // 获取当前选中的导航控制器
        guard index < viewControllers?.count ?? 0,
              let navController = viewControllers?[index] as? UINavigationController,
              let topViewController = navController.topViewController else {
            return
        }
        
        // 检查 topViewController 是否实现了 TabBarDoubleTapHandler 协议
        if let handler = topViewController as? DebugTabBarDoubleTapHandler {
            // 调用处理器的双击处理方法
            _ = handler.handleTabBarDoubleTap()
        }
    }

}

//MARK: - UITabBarDelegate
extension CocoaDebugTabBarController {
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let items = self.tabBar.items else {return}
        
        for index in 0...items.count-1 {
            if item == items[index] {
                CocoaDebugSettings.shared.tabBarSelectItem = index
            }
        }
        
        // 检测双击 tabbar
        let currentTime = Date().timeIntervalSince1970
        let currentIndex = selectedIndex
        
        // 检测是否为双击（同一 tab 在时间间隔内连续点击）
        if currentIndex == lastTabBarIndex {
            let timeInterval = currentTime - lastTabBarTapTime
            if timeInterval < doubleTapTimeInterval {
                // 双击事件，尝试处理
                handleDoubleTap(at: currentIndex)
            }
        }
        
        // 更新记录
        lastTabBarTapTime = currentTime
        lastTabBarIndex = currentIndex
    }
}
