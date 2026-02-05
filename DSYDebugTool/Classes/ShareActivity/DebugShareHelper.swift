//
//  NetworkShareHelper.swift
//  DSYDebugTool
//
//  Created by code on 2025/01/XX.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import UIKit
import MessageUI

/// 自定义 UIActivity，用于在 UIActivityViewController 中提供自定义分享入口
class CustomShareActivity: UIActivity {
    
    var title: String
    var image: UIImage?
    var handler: (() -> Void)?
    
    init(title: String, image: UIImage? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.image = image
        self.handler = handler
        super.init()
    }
    
    override var activityTitle: String? {
        return title
    }
    
    override var activityImage: UIImage? {
        return image ?? UIImage(systemName: "square.and.arrow.up")
    }
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.cocoadebug.customNetworkShare")
    }
    
    override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }
    
    override func perform() {
        handler?()
        activityDidFinish(true)
    }
}
