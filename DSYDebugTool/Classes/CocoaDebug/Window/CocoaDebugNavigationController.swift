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
