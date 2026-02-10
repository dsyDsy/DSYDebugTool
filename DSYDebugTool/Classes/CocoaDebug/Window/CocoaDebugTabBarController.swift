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
        
        UIApplication.shared.keyWindow?.endEditing(true)
        
        setChildControllers()
        
        self.selectedIndex = CocoaDebugSettings.shared.tabBarSelectItem 
        self.tabBar.tintColor = Color.mainGreen
        self.view.backgroundColor = "#1f2124".hexColor
        //bugfix #issues-158
        if #available(iOS 13, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = "#1f2124".hexColor
            appearance.shadowColor = .clear    //removing navigationbar 1 px bottom border.
//            self.tabBar.appearance().standardAppearance = appearance
//            self.tabBar.appearance().scrollEdgeAppearance = appearance
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
        
        //3.
        guard let additionalViewController = CocoaDebugSettings.shared.additionalViewController else {
            self.viewControllers = [network, logs, sandbox, app]
            return
        }
        
        //4.Add additional controller
        var temp = [network, logs, sandbox, app]
        
        let nav = UINavigationController.init(rootViewController: additionalViewController)
        nav.navigationBar.barTintColor = "#1f2124".hexColor
        nav.tabBarItem = UITabBarItem.init(tabBarSystemItem: .more, tag: 4)

        //****** copy codes from LogNavigationViewController.swift ******
        nav.navigationBar.isTranslucent = false
        
        nav.navigationBar.tintColor = Color.mainGreen
        nav.navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                                 .foregroundColor: Color.mainGreen]
        
        let selector = #selector(CocoaDebugNavigationController.exit)
        
        
        let image = UIImage(named: "_icon_file_type_close", in: Bundle(for: CocoaDebugNavigationController.self), compatibleWith: nil)
        let leftItem = UIBarButtonItem(image: image,
                                       style: .done, target: self, action: selector)
        leftItem.tintColor = Color.mainGreen
        nav.topViewController?.navigationItem.leftBarButtonItem = leftItem
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
