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
        
        navigationBar.isTranslucent = false //liman
        
        navigationBar.tintColor = Color.mainGreen
        navigationBar.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                             .foregroundColor: Color.mainGreen]
        
        setupCloseButton()
        
        if #available(iOS 26.0, *) {
            // iOS 26+ 启用系统 Glass 材质
            navigationBar.isTranslucent = true
            navigationBar.overrideUserInterfaceStyle = .dark
            
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            if #available(iOS 27.0, *) {
                // iOS 27+ 系统强制 glass 材质由 appearance 决定暗色
                appearance.overrideUserInterfaceStyle = .dark
            }
            appearance.shadowColor = .clear
            appearance.titleTextAttributes = [.font: UIFont.boldSystemFont(ofSize: 20),
                                              .foregroundColor: Color.mainGreen]
            self.navigationBar.standardAppearance = appearance
            self.navigationBar.scrollEdgeAppearance = nil
        } else if #available(iOS 13.0, *) {
            // 原版样式：保持原有外观，不设置实色背景，避免将列表页面全部刷黑
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.shadowColor = .clear
            self.navigationBar.standardAppearance = appearance
            self.navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupCloseButton()
    }
    
    private func setupCloseButton() {
        guard let rootVC = viewControllers.first else { return }
        
        let selector = #selector(CocoaDebugNavigationController.exit)
        let image = UIImage(named: "_icon_file_type_close", in: Bundle(for: CocoaDebugNavigationController.self), compatibleWith: nil)
        
        let leftItem: UIBarButtonItem
        if #available(iOS 26.0, *) {
            // iOS 26+ 适配系统强制 glass 风格的顶部胶囊圆钮
            var config = UIButton.Configuration.tinted()
            config.image = image
            config.baseForegroundColor = Color.mainGreen
            config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.12)
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            
            let button = UIButton(configuration: config)
            button.addTarget(self, action: selector, for: .touchUpInside)
            leftItem = UIBarButtonItem(customView: button)
        } else {
            leftItem = UIBarButtonItem(image: image, style: .done, target: self, action: selector)
            leftItem.tintColor = Color.mainGreen
        }
        
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
