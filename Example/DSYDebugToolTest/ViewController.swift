//
//  ViewController.swift
//  DSYDebugToolTest
//
//  Created by code on 2026/2/4.
//

import UIKit
import DSYDebugTool
import SnapKit

extension UIViewController {
    
    /// 获取应用根控制器
    static var appRootViewController: UIViewController? {
        if #available(iOS 13.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first(where: {
                $0.activationState == .foregroundActive
            }) as? UIWindowScene else { return nil }
            
            return scene.windows.first { $0.isKeyWindow }?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }
    
    /// 获取当前控制器的根控制器（导航控制器的根等）
    var navigationRootViewController: UIViewController? {
        if let nav = self as? UINavigationController {
            return nav.viewControllers.first
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.navigationRootViewController
        }
        return self
    }
}

class ViewController: UIViewController {

    lazy  var webServerLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.systemFont(ofSize: 20)
        view.numberOfLines = 0
        view.textColor = .blue
        view.textAlignment = .center
        return view
    }()
    
    lazy  var msgLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.systemFont(ofSize: 20)
        view.textColor = .red
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }()
    
    lazy  var clickBtn: UIButton = {
        let view = UIButton()
        view.setTitle("test", for: .normal)
        view.setTitleColor(.blue, for: .normal)
        view.backgroundColor = .black
        view.addTarget(self, action: #selector(test(btn:)), for: .touchUpInside)
        return view
    }()
    
    lazy  var fileTransferBtn: UIButton = {
        let view = UIButton()
        view.setTitle("展示文件传输助手", for: .normal)
        view.setTitleColor(.blue, for: .normal)
        view.backgroundColor = .black
        view.addTarget(self, action: #selector(fileTransferBtn(btn:)), for: .touchUpInside)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(webServerLabel)
        webServerLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100)
            make.centerX.equalToSuperview()
        }
        
        self.view.addSubview(msgLabel)
        msgLabel.snp.makeConstraints { make in
            make.top.equalTo(webServerLabel.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        self.view.addSubview(clickBtn)
        clickBtn.snp.makeConstraints { make in
            make.top.equalTo(msgLabel.snp.bottom).offset(30)
            make.width.equalTo(100)
            make.height.equalTo(44)
            make.centerX.equalToSuperview()
        }
        
        self.view.addSubview(fileTransferBtn)
        fileTransferBtn.snp.makeConstraints { make in
            make.top.equalTo(clickBtn.snp.bottom).offset(30)
            make.width.equalTo(150)
            make.height.equalTo(44)
            make.centerX.equalToSuperview()
        }
        if  DebugFileTransferServer.shared.isRunning == false {
            webServerLabel.text = "文件助手未启动"
        }else {
            webServerLabel.text =  "文件助手地址：\(DebugFileTransferServer.shared.getCompleteAddress() ?? "未开启")"
        }
    }
   
    @objc func test(btn:UIButton){
        let url  = URLRequest(url: URL(string: "https://www.baidu.com")!)
        URLSession.shared.dataTask(with: url){[weak self] data, response, error in
            guard let self = self else {return }
            let responseText = "\(response, default: "")"
            print(responseText)
            print(error)
            DispatchQueue.main.async {
                let items: [Any] = [responseText]
                let activity = CustomShareActivity.init(title: "快速分享", image: nil) {
                    // 发送文字到web
                    CocoaDebugSettings.shared.customNetworkShareHandler?(responseText,nil)
                }
                DebugActionSheetHelper.showSystemShare(items: items,activities: [activity], presentingViewController: self)
                
            }
        }.resume()
       
        
    }
    
    @objc func fileTransferBtn(btn:UIButton){
        if  DebugFileTransferServer.shared.isRunning == false {
            DebugFileTransferServer.shared.startServer { [weak self] success, address in
                if success {
                    let uploadVC = DebugFileUploadViewController()
                    let navController = UINavigationController(rootViewController: uploadVC)
                    self?.present(navController, animated: true)
                }else {
                    self?.msgLabel.text = "服务开启失败，不支持发送。请再次尝试......"
                }
                if  DebugFileTransferServer.shared.isRunning == false {
                    self?.webServerLabel.text = "文件助手未启动"
                }else {
                    self?.webServerLabel.text =  "文件助手地址：\(DebugFileTransferServer.shared.getCompleteAddress() ?? "未开启")"
                }
            }
        }else {
            let uploadVC = DebugFileUploadViewController()
            let navController = UINavigationController(rootViewController: uploadVC)
            self.present(navController, animated: true)
            if  DebugFileTransferServer.shared.isRunning == false {
                self.webServerLabel.text = "文件助手未启动"
            }else {
                self.webServerLabel.text =  "文件助手地址：\(DebugFileTransferServer.shared.getCompleteAddress() ?? "未开启")"
            }
        }
     
       
    }
    
    
    class func initTool() {

        CocoaDebugSettings.shared.serverURL = "dsy.test.com"
        CocoaDebugSettings.shared.bubbleSettings = CocoaDebugSettings.BubbleSettings(
            size: CGSize(width: 36, height: 36),
            backgroundColor:  .black,
            numberLabelColor: .white)
        
        CocoaDebug.mainColor = "#FFD42A"
        CocoaDebugSettings.shared.enableLogMonitoring = true
        CocoaDebugSettings.shared.disableNetworkMonitoring = false
        CocoaDebugSettings.shared.enableMemoryLeaksMonitoring_ViewController = true
        CocoaDebugSettings.shared.enableMemoryLeaksMonitoring_View = true
        CocoaDebugSettings.shared.enableMemoryLeaksMonitoring_MemberVariables = true
        CocoaDebugSettings.shared.additionalViewController =  ViewController()
        CocoaDebugSettings.shared.enableUIBlockingMonitoring = false
        CocoaDebugSettings.shared.enableWKWebViewMonitoring = true
        CocoaDebugSettings.shared.enableCrashRecording = true
      
        // 配置自定义分享入口
        CocoaDebugSettings.shared.customNetworkShareTitle = "快速分享"
        CocoaDebugSettings.shared.customNetworkShareImage = UIImage(named: "app_icon_sm")
        CocoaDebug.showBubble()
        DebugFileTransferServer.shared.isDebugLogEnabled = true
        DebugFileTransferServer.shared.serverPort = 8080
     
        
        DebugScreenshotManager.shared.autoHideTime = 8
        DebugScreenshotManager.shared.currentSreenshotHandle = {
            if WindowHelper.shared.isListViewBeingDisplayed {
               return WindowHelper.shared.window
            }
            return UIApplication.shared.currentKeyWindow
        }
        CocoaDebugSettings.shared.customNetworkShareHandler = { messageBody, httpModel in
            NetworkShareHelper.quickShare(text: messageBody)
         
        }
    }


}


extension UIApplication {
    /// 安全获取当前活跃场景中的主窗口
    var currentKeyWindow: UIWindow? {
        // 1. 获取所有已连接的场景
        connectedScenes
            // 2. 只保留 UIWindowScene 类型
            .compactMap { $0 as? UIWindowScene }
            // 3. 只保留前台活跃状态的场景（用户正在交互）
            .first { $0.activationState == .foregroundActive }
            // 4. 取该场景下标记为 key 的窗口，若无则取第一个窗口
            .flatMap { $0.windows.first { $0.isKeyWindow } ?? $0.windows.first }
    }
}
