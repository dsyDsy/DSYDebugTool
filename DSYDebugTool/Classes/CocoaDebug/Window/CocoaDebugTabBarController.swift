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
            self.overrideUserInterfaceStyle = .dark
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
            self.tabBar.scrollEdgeAppearance = appearance
            self.tabBar.tintColor = Color.mainGreen
            self.tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.6)
            // 确保 TabBar 始终使用暗色系统材质
            self.tabBar.overrideUserInterfaceStyle = .dark
            self.tabBar.isTranslucent = true
            self.tabBar.backgroundColor = .clear
            self.tabBar.barTintColor = nil
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
        
        if #available(iOS 13.0, *) {
            // 对齐 sandbox 导航栏的 glass 半透材质风格
            sandbox.navigationBar.isTranslucent = true
            sandbox.navigationBar.overrideUserInterfaceStyle = .dark
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithDefaultBackground()
            navAppearance.shadowColor = .clear
            if #available(iOS 27.0, *) {
                navAppearance.overrideUserInterfaceStyle = .dark
            }
            sandbox.navigationBar.standardAppearance = navAppearance
            sandbox.navigationBar.scrollEdgeAppearance = navAppearance
        }
        
        //3. 统一配置系统自带的 moreNavigationController 样式（防御性适配超过5个页面的场景）
        if #available(iOS 13.0, *) {
            moreNavigationController.navigationBar.overrideUserInterfaceStyle = .dark
            moreNavigationController.navigationBar.isTranslucent = true
            moreNavigationController.navigationBar.barTintColor = nil
            moreNavigationController.navigationBar.backgroundColor = .clear
            moreNavigationController.navigationBar.tintColor = Color.mainGreen
            moreNavigationController.navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                                                         .foregroundColor: Color.mainGreen]
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                              .foregroundColor: Color.mainGreen]
            if #available(iOS 27.0, *) {
                appearance.overrideUserInterfaceStyle = .dark
            }
            moreNavigationController.navigationBar.standardAppearance = appearance
            moreNavigationController.navigationBar.scrollEdgeAppearance = appearance
            moreNavigationController.navigationBar.compactAppearance = appearance
            if #available(iOS 15.0, *) {
                moreNavigationController.navigationBar.compactScrollEdgeAppearance = appearance
            }
        }
        
        //4.
        guard let additionalViewController = CocoaDebugSettings.shared.additionalViewController else {
            self.viewControllers = [network, logs, sandbox, app]
            return
        }
        
        // 允许 additionalViewController 穿透扩展至顶部导航栏和底部 TabBar 安全区
        additionalViewController.extendedLayoutIncludesOpaqueBars = true
        additionalViewController.edgesForExtendedLayout = .all
        
        //5. 使用统一的 CocoaDebugNavigationController，具备完整 Glass 材质、关闭按钮及安全区自适应能力
        let nav = CocoaDebugNavigationController(rootViewController: additionalViewController)
        nav.tabBarItem = UITabBarItem(tabBarSystemItem: .more, tag: 4)
        
        var temp = [network, logs, sandbox, app]
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
