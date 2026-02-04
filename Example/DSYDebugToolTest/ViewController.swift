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
        URLSession.shared.dataTask(with: url){ data, response, error in
            print(response)
            print(error)
            DispatchQueue.main.async {
                /// 发送文字到web
                CocoaDebugSettings.shared.customNetworkShareHandler?("\(response)",nil)
            }
        }.resume()
       
        
    }
    
    @objc func fileTransferBtn(btn:UIButton){
        if  DebugFileTransferServer.shared.isRunning == false {
            DebugFileTransferServer.shared.startServer { [weak self] success, address in
                if success, let address = address {
                    let uploadVC = DebugFileUploadViewController()
                    let navController = UINavigationController(rootViewController: uploadVC)
                    self?.present(navController, animated: true)
                }else {
                    self?.msgLabel.text = "服务开启失败，不支持发送。请再次尝试......"
                }
            }
        }else {
            let uploadVC = DebugFileUploadViewController()
            let navController = UINavigationController(rootViewController: uploadVC)
            self.present(navController, animated: true)
        }
     
       
    }
    
    
    class func initTool() {

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
        CocoaDebugSettings.shared.enableRNMonitoring  = false
        CocoaDebugSettings.shared.logCount = 500;
        CocoaDebugSettings.shared.httpCount = 200
        // 配置自定义分享入口
        CocoaDebugSettings.shared.customNetworkShareTitle = "快速分享"
//        CocoaDebugSettings.shared.customNetworkShareImage = UIImage(named: "custom_icon")
        DebugFileTransferServer.shared.isDebugEnabled = true
        DebugFileTransferServer.shared.serverPort = 8080
        CocoaDebug.showBubble()
        CocoaDebugSettings.shared.customNetworkShareHandler = { messageBody, httpModel in
            // 自定义处理逻辑
            DebugFileTransferServer.shared.log("处理网络请求信息:信息内容长度\( messageBody.count)")
         
            let vc =  UIViewController.appRootViewController as? ViewController
            if  DebugFileTransferServer.shared.isRunning == false {
                vc?.msgLabel.text = "正在开启服务，请稍等......"
                DebugFileTransferServer.shared.startServer { success, address in
                    if success, let address = address {
                        
                        DebugFileUploadViewController.uploadTextContent(messageBody)
                        vc?.msgLabel.text = "发送完成，打开浏览器查看"
                        vc?.webServerLabel.text = address
                        UIPasteboard.general.string = address
                    }else {
                        vc?.msgLabel.text =   "服务开启失败，不支持发送。请再次尝试......"
                    }
                }
            }else{
                vc?.webServerLabel.text =  "文件助手地址：\(DebugFileTransferServer.shared.getCompleteAddress() ?? "未开启")"
                UIPasteboard.general.string = DebugFileTransferServer.shared.getCompleteAddress()
                DebugFileUploadViewController.uploadTextContent(messageBody)
                vc?.msgLabel.text = "发送完成，打开浏览器查看"
            }
            
        }
    }


}

