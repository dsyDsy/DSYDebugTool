//
//  DebugActionSheetHelper.swift
//  DSYDebugTool
//
//  Created by code on 2025/01/XX.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import UIKit
import MessageUI
import ObjectiveC

/// 操作项配置
public struct ActionItem {
    /// 操作标题
    public let title: String
    /// 操作样式
    public let style: UIAlertAction.Style
    /// 操作回调
    public let handler: (() -> Void)?
    
    public init(title: String, style: UIAlertAction.Style = .default, handler: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}

/// 邮件配置
public struct EmailConfig {
    /// 邮件主题
    public let subject: String
    /// 邮件正文
    public let messageBody: String
    /// 收件人列表
    public let recipients: [String]?
    /// 抄送人列表
    public let ccRecipients: [String]?
    /// 图片附件
    public let imageAttachments: [UIImage]?
    /// 其他附件（Data 数组，需要指定文件名和 MIME 类型）
    public let otherAttachments: [(data: Data, mimeType: String, fileName: String)]?
    
    public init(
        subject: String,
        messageBody: String,
        recipients: [String]? = nil,
        ccRecipients: [String]? = nil,
        imageAttachments: [UIImage]? = nil,
        otherAttachments: [(data: Data, mimeType: String, fileName: String)]? = nil
    ) {
        self.subject = subject
        self.messageBody = messageBody
        self.recipients = recipients
        self.ccRecipients = ccRecipients
        self.imageAttachments = imageAttachments
        self.otherAttachments = otherAttachments
    }
}

/// 邮件发送结果回调
public protocol ActionSheetMailDelegate: AnyObject {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
}

/// 自定义 UIActivity，用于在 UIActivityViewController 中提供自定义分享入口
public class CustomShareActivity: UIActivity {
    
    var title: String
    var image: UIImage?
    var handler: (() -> Void)?
    
    init(title: String, image: UIImage? = nil, handler: @escaping () -> Void) {
        self.title = title
        self.image = image
        self.handler = handler
        super.init()
    }
    
    public override var activityTitle: String? {
        return title
    }
    
    public override var activityImage: UIImage? {
        return image ?? UIImage(systemName: "square.and.arrow.up")
    }
    
    public override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.cocoadebug.customNetworkShare")
    }
    
    public override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    public  override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }
    
    public override func perform() {
        handler?()
        activityDidFinish(true)
    }
}



/// 通用的操作弹框工具类
/// 支持动态添加多个自定义操作项，以及邮件分享功能
public class DebugActionSheetHelper {
    
    /// 展示操作弹框
    /// - Parameters:
    ///   - title: 弹框标题（可选）
    ///   - message: 弹框消息（可选）
    ///   - actions: 自定义操作项数组
    ///   - emailConfig: 邮件配置（如果提供，会自动添加邮件分享选项）
    ///   - includeCopyAction: 是否包含复制到剪贴板操作（默认 false）
    ///   - copyText: 复制到剪贴板的文本（如果 includeCopyAction 为 true）
    ///   - includeCancelAction: 是否包含取消操作（默认 true）
    ///   - cancelTitle: 取消按钮标题（默认 "Cancel"）
    ///   - presentingViewController: 用于展示弹框的视图控制器
    ///   - sourceView: iPad 上 popover 的源视图（可选）
    ///   - sourceRect: iPad 上 popover 的源矩形（可选）
    ///   - mailDelegate: 邮件发送结果回调代理（可选）
    public static func show(
        title: String? = nil,
        message: String? = nil,
        actions: [ActionItem] = [],
        emailConfig: EmailConfig? = nil,
        includeCopyAction: Bool = false,
        copyText: String? = nil,
        includeCancelAction: Bool = true,
        cancelTitle: String = "Cancel",
        presentingViewController: UIViewController,
        sourceView: UIView? = nil,
        sourceRect: CGRect? = nil,
        mailDelegate: ActionSheetMailDelegate? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        // 1. 添加自定义操作项
        for actionItem in actions {
            let alertAction = UIAlertAction(title: actionItem.title, style: actionItem.style) { _ in
                actionItem.handler?()
            }
            alert.addAction(alertAction)
        }
        
        // 2. 添加邮件分享选项（如果配置了）
        if let emailConfig = emailConfig {
            let emailAction = UIAlertAction(title: "share via email", style: .default) { _ in
                if let mailComposeVC = createMailComposer(
                    config: emailConfig,
                    delegate: mailDelegate
                ) {
                    presentingViewController.present(mailComposeVC, animated: true, completion: nil)
                } else {
                    // 如果无法发送邮件，显示提示
                    showMailUnavailableAlert(presentingViewController: presentingViewController)
                }
            }
            alert.addAction(emailAction)
        }
        
        // 3. 添加复制到剪贴板操作（如果需要）
        if includeCopyAction, let copyText = copyText {
            let copyAction = UIAlertAction(title: "copy to clipboard", style: .default) { _ in
                UIPasteboard.general.string = copyText
            }
            alert.addAction(copyAction)
        }
        
        // 4. 添加取消操作（如果需要）
        if includeCancelAction {
            alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
        }
        
        // 配置 popover（iPad）
        configurePopover(
            alertController: alert,
            presentingViewController: presentingViewController,
            sourceView: sourceView,
            sourceRect: sourceRect
        )
        
        presentingViewController.present(alert, animated: true, completion: nil)
    }
    
    /// 展示系统分享
    /// - Parameters:
    ///   - items: 分享内容
    ///   - activities: 自定义分享按钮
    ///   - presentingViewController: 用于展示弹框的视图控制器
    ///   - sourceView: iPad 上 popover 的源视图（可选）
    ///   - sourceRect: iPad 上 popover 的源矩形（可选）
    public static func showSystemShare(items:[Any],
                         activities:[CustomShareActivity]? = nil,
                         presentingViewController: UIViewController,
                         sourceView: UIView? = nil,
                         sourceRect: CGRect? = nil){
        
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: activities
        )
        // 配置 popover（iPad）
        if  UIDevice.current.userInterfaceIdiom == .pad {
            if let sourceView = sourceView ?? presentingViewController.view {
                activityVC.popoverPresentationController?.sourceView = sourceView
                activityVC.popoverPresentationController?.sourceRect = sourceRect ?? CGRect(
                    x: sourceView.bounds.midX,
                    y: sourceView.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        
        presentingViewController.present(activityVC, animated: true, completion: nil)
    }
    
    
    /// 系统弹框
    /// - Parameters:
    ///   - title: 标题
    ///   - message: 文案
    ///   - actions: 按钮组
    ///   - style: 样式
    ///   - presentingViewController: 用于展示弹框的视图控制器
    ///   - sourceView: iPad 上 popover 的源视图（可选）
    ///   - sourceRect: iPad 上 popover 的源矩形（可选）
    static func showAlert(title:String? = nil,
                                message:String?,
                          actions: [UIAlertAction] = [],
                                style:UIAlertController.Style = .alert,
                         presentingViewController: UIViewController,
                         sourceView: UIView? = nil,
                                sourceRect: CGRect? = nil){
        let activityVC = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
        var actions = actions
        if actions.count == 0 || actions.first(where: {$0.style == .cancel}) == nil  {
            actions.append(UIAlertAction.init(title: "确定", style: .cancel))
        }
        actions.forEach { a in
            activityVC.addAction(a)
        }
        // 配置 popover（iPad）
        if  UIDevice.current.userInterfaceIdiom == .pad {
            if let sourceView = sourceView ?? presentingViewController.view {
                activityVC.popoverPresentationController?.sourceView = sourceView
                activityVC.popoverPresentationController?.sourceRect = sourceRect ?? CGRect(
                    x: sourceView.bounds.midX,
                    y: sourceView.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
        }
        presentingViewController.present(activityVC, animated: true, completion: nil)
    }
    
    /// 创建邮件 composer
    private static func createMailComposer(
        config: EmailConfig,
        delegate: ActionSheetMailDelegate?
    ) -> MFMailComposeViewController? {
        guard MFMailComposeViewController.canSendMail() else {
            return nil
        }
        
        let mailComposeVC = MFMailComposeViewController()
        
        // 设置代理（如果需要）
        if let delegate = delegate {
            // 创建一个内部代理来处理回调
            let internalDelegate = MailComposeDelegateWrapper(delegate: delegate)
            mailComposeVC.mailComposeDelegate = internalDelegate
            // 保持强引用，避免代理被释放
            objc_setAssociatedObject(
                mailComposeVC,
                &AssociatedKeys.mailDelegate,
                internalDelegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
        
        // 设置收件人
        if let recipients = config.recipients, !recipients.isEmpty {
            mailComposeVC.setToRecipients(recipients)
        }
        
        // 设置抄送人
        if let ccRecipients = config.ccRecipients, !ccRecipients.isEmpty {
            mailComposeVC.setCcRecipients(ccRecipients)
        }
        
        // 添加图片附件
        if let imageAttachments = config.imageAttachments {
            for (index, image) in imageAttachments.enumerated() {
                if let imageData = image.pngData() {
                    let fileName = "image_\(index + 1).png"
                    mailComposeVC.addAttachmentData(imageData, mimeType: "image/png", fileName: fileName)
                }
            }
        }
        
        // 添加其他附件
        if let otherAttachments = config.otherAttachments {
            for attachment in otherAttachments {
                mailComposeVC.addAttachmentData(
                    attachment.data,
                    mimeType: attachment.mimeType,
                    fileName: attachment.fileName
                )
            }
        }
        
        // 设置邮件正文
        mailComposeVC.setMessageBody(config.messageBody, isHTML: false)
        
        // 设置邮件主题
        mailComposeVC.setSubject(config.subject)
        
        return mailComposeVC
    }
    
    /// 显示邮件不可用提示
    private static func showMailUnavailableAlert(presentingViewController: UIViewController) {
        let alert = UIAlertController(
            title: "No Mail Accounts",
            message: "Please set up a Mail account in order to send email.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        presentingViewController.present(alert, animated: true)
    }
    
    /// 配置 popover（iPad）
    private static func configurePopover(
        alertController: UIAlertController,
        presentingViewController: UIViewController,
        sourceView: UIView?,
        sourceRect: CGRect?
    ) {
        guard let popoverController = alertController.popoverPresentationController else {
            return
        }
        
        if let sourceView = sourceView ?? presentingViewController.view {
            popoverController.sourceView = sourceView
            popoverController.sourceRect = sourceRect ?? CGRect(
                x: sourceView.bounds.midX,
                y: sourceView.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = .init(rawValue: 0)
        }
    }
}

// MARK: - 邮件代理包装器
private class MailComposeDelegateWrapper: NSObject, MFMailComposeViewControllerDelegate {
    weak var delegate: ActionSheetMailDelegate?
    
    init(delegate: ActionSheetMailDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        delegate?.mailComposeController(controller, didFinishWith: result, error: error)
        controller.dismiss(animated: true)
    }
}

// MARK: - Associated Keys
private struct AssociatedKeys {
    static var mailDelegate = "mailDelegate"
}
