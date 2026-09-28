//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit

class CocoaDebugNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            self.overrideUserInterfaceStyle = .dark
        }
        
        navigationBar.isTranslucent = true
        navigationBar.barTintColor = nil
        navigationBar.backgroundColor = .clear
        navigationBar.tintColor = Color.mainGreen
        navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                             .foregroundColor: Color.mainGreen]
        
        setupCloseButton()
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                              .foregroundColor: Color.mainGreen]
            if #available(iOS 26.0, *) {
                navigationBar.overrideUserInterfaceStyle = .dark
                if #available(iOS 27.0, *) {
                    appearance.overrideUserInterfaceStyle = .dark
                }
            }
            
            self.navigationBar.standardAppearance = appearance
            self.navigationBar.scrollEdgeAppearance = appearance
            self.navigationBar.compactAppearance = appearance
            if #available(iOS 15.0, *) {
                self.navigationBar.compactScrollEdgeAppearance = appearance
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupCloseButton()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        adaptChildSafeAreaAndInsets()
    }
    
    /// 自动为当前子页面（尤其是外部传入的 additionalViewController / more 页面）
    /// 适配顶部导航栏穿透与底部 TabBar 安全区防遮挡、防多余空白
    private func adaptChildSafeAreaAndInsets() {
        guard let currentVC = topViewController else { return }
        
        if !currentVC.extendedLayoutIncludesOpaqueBars {
            currentVC.extendedLayoutIncludesOpaqueBars = true
        }
        if currentVC.edgesForExtendedLayout != .all {
            currentVC.edgesForExtendedLayout = .all
        }
        
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        let safeBottom = currentVC.view.safeAreaInsets.bottom
        let extraBottom = max(0, tabBarHeight - safeBottom)
        
        let scrollViews = findAllScrollViews(in: currentVC.view)
        for sv in scrollViews {
            if #available(iOS 11.0, *) {
                if sv.contentInsetAdjustmentBehavior != .always {
                    sv.contentInsetAdjustmentBehavior = .always
                }
            }
            if sv.contentInset.bottom != extraBottom {
                sv.contentInset.bottom = extraBottom
                sv.scrollIndicatorInsets.bottom = extraBottom
            }
        }
    }
    
    private func findAllScrollViews(in view: UIView) -> [UIScrollView] {
        var results = [UIScrollView]()
        if let sv = view as? UIScrollView {
            results.append(sv)
        }
        for subview in view.subviews {
            results.append(contentsOf: findAllScrollViews(in: subview))
        }
        return results
    }
    
    private func setupCloseButton() {
        guard let rootVC = viewControllers.first else { return }
        
        let selector = #selector(CocoaDebugNavigationController.exit)
        let leftItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: selector)
        leftItem.tintColor = Color.mainGreen
        
        if let items = rootVC.navigationItem.leftBarButtonItems, items.count > 1 {
            var newItems = items
            newItems[0] = leftItem
            rootVC.navigationItem.leftBarButtonItems = newItems
        } else {
            rootVC.navigationItem.leftBarButtonItem = leftItem
        }
    }
    
    @objc func exit() {
        dismiss(animated: true, completion: nil)
    }
}
