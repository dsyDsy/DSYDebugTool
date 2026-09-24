//
//  Example
//  man
//
//  Created by man 11/11/2018.
//  Copyright © 2020 man. All rights reserved.
//

import UIKit

class UIBlockingBubble: UIView {
    
    static var size: CGSize {return CGSize(width: 70, height: 20)}
    
    private var uiBlockingLabel: UILabel? = {
        return UILabel(frame: CGRect(x:0, y:0, width:size.width, height:size.height))
    }()
    
    fileprivate func initLayer() {
        if #available(iOS 13.0, *) {
            self.backgroundColor = .secondarySystemBackground
        } else {
            self.backgroundColor = .white
        }
        self.layer.cornerRadius = 4
        self.sizeToFit()
        
        if let uiBlockingLabel = uiBlockingLabel {
            self.addSubview(uiBlockingLabel)
        }
    }
    
    //MARK: - init
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: UIScreen.main.bounds.width/4.0, y:1, width: frame.width, height: frame.height))
        
        initLayer()
        
//        uiBlockingLabel?.attributedText = uiBlockingLabel?.uiBlockingAttributedString(with: 60)
        
//        WindowHelper.shared.uiBlockingCallback = { [weak self] value in
//            self?.uiBlockingLabel?.update(withValue: Float(value))
//        }
        
        uiBlockingLabel?.textAlignment = .center
        uiBlockingLabel?.adjustsFontSizeToFitWidth = true
        uiBlockingLabel?.text = "Normal"
        if #available(iOS 13.0, *) {
            uiBlockingLabel?.textColor = .label
        } else {
            uiBlockingLabel?.textColor = .black
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CocoaDebug_Detected_UI_Blocking"), object: nil, queue: OperationQueue.main) { [weak self] _ in
            self?.uiBlockingLabel?.text = "Blocking"
            self?.uiBlockingLabel?.textColor = .red
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {[weak self] in
                self?.uiBlockingLabel?.text = "Normal"
                if #available(iOS 13.0, *) {
                    self?.uiBlockingLabel?.textColor = .label
                } else {
                    self?.uiBlockingLabel?.textColor = .black
                }
            }
        }
    }
    
    func updateFrame() {
        let safeAreaInsetsTop = self.superview?.safeAreaInsets.top ?? self.window?.safeAreaInsets.top ?? 44.0
        if safeAreaInsetsTop > 24 { //全面屏刘海/灵动岛设备
            center.x = (self.superview?.bounds.width ?? UIScreen.main.bounds.width) / 2.0
            center.y = max(39.0, safeAreaInsetsTop / 2.0 + 10.0)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        //notification
        NotificationCenter.default.removeObserver(self)
    }
}
