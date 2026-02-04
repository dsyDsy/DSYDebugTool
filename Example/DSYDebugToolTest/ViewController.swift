//
//  ViewController.swift
//  DSYDebugToolTest
//
//  Created by code on 2026/2/4.
//

import UIKit
import DSYDebugTool
import SnapKit
class ViewController: UIViewController {

    lazy  var msgLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.systemFont(ofSize: 20)
        view.textColor = .red
        view.numberOfLines = 0
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        self.view.addSubview(msgLabel)
        msgLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(100)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        self.view.addSubview(clickBtn)
        clickBtn.snp.makeConstraints { make in
            make.top.equalTo(msgLabel.snp.bottom)
            make.width.equalTo(100)
            make.height.equalTo(44)
            make.centerX.equalToSuperview()
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
    
    class func initTool() {

        CocoaDebugSettings.shared.bubbleSettings = CocoaDebugSettings.BubbleSettings(
            size: CGSize(width: 36, height: 36),
            backgroundColor:  .black,
            numberLabelColor: .white)
        CocoaDebugSettings.shared.additionalViewController = ViewController()
        CocoaDebugSettings.shared.enableLogMonitoring = true
        CocoaDebugSettings.shared.disableNetworkMonitoring = false
        CocoaDebugSettings.shared.enableMemoryLeaksMonitoring_ViewController = true
        CocoaDebugSettings.shared.enableMemoryLeaksMonitoring_View = true
        CocoaDebugSettings.shared.enableMemoryLeaksMonitoring_MemberVariables = true
        CocoaDebugSettings.shared.enableUIBlockingMonitoring = false
        CocoaDebugSettings.shared.enableWKWebViewMonitoring = true
        CocoaDebugSettings.shared.enableCrashRecording = true
        CocoaDebugSettings.shared.logCount = 500;
        CocoaDebugSettings.shared.httpCount = 200
        // 配置自定义分享入口
        CocoaDebugSettings.shared.customNetworkShareTitle = "快速分享"
//        CocoaDebugSettings.shared.customNetworkShareImage = UIImage(named: "custom_icon")
        DebugFileTransferServer.shared.isDebugEnabled = true
        DebugFileTransferServer.shared.serverPort = 8089
        CocoaDebug.showBubble()
        CocoaDebugSettings.shared.customNetworkShareHandler = { messageBody, httpModel in
            // 自定义处理逻辑
            DebugFileTransferServer.shared.log("处理网络请求信息:信息内容长度\( messageBody.count)")
         
            let vc =  CocoaDebugSettings.shared.additionalViewController as? ViewController
            if  DebugFileTransferServer.shared.isRunning == false {
                vc?.msgLabel.text = "正在开启服务，请稍等......"
                DebugFileTransferServer.shared.startServer { success, address in
                    if success, let address = address {
                        DebugFileUploadViewController.uploadTextContent(messageBody)
                        vc?.msgLabel.text = "发送完成，🌐 服务器地址：\(address)"
                        UIPasteboard.general.string = address
                    }else {
                        vc?.msgLabel.text =   "服务开启失败，不支持发送。请再次尝试......"
                    }
                }
            }else{
                vc?.msgLabel.text =  "文件助手地址：\(DebugFileTransferServer.shared.getCompleteAddress() ?? "未开启")"
                UIPasteboard.general.string = DebugFileTransferServer.shared.getCompleteAddress()
                DebugFileUploadViewController.uploadTextContent(messageBody)
                vc?.msgLabel.text = "发送完成，🌐 服务器地址：\(DebugFileTransferServer.shared.getCompleteAddress() ?? "")"
            }
            
        }
    }


}

