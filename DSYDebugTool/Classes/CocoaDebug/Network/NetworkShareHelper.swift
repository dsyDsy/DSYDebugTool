

/// 网络请求分享工具类，提供统一的分享功能
public class NetworkShareHelper {
    /// 分享配置参数
    public struct ShareConfig {
        /// 要分享的内容文本
        public let messageBody: String
        /// 可选的 用于自定义处理
        public let data: Any?
        /// 可选的图片附件
        public let image: UIImage?
        /// 邮件主题（如果使用邮件分享）
        public let emailSubject: String?
        
        public init(messageBody: String,
                    data: Any? = nil,
                   image: UIImage? = nil,
                   emailSubject: String? = nil) {
            self.messageBody = messageBody
            self.data = data
            self.image = image
            self.emailSubject = emailSubject
        }
    }
    
    /// 展示分享选项
    /// - Parameters:
    ///   - config: 分享配置
    ///   - presentingViewController: 用于展示分享界面的视图控制器
    ///   - sourceView: iPad 上 popover 的源视图（可选）
    ///   - sourceRect: iPad 上 popover 的源矩形（可选）
    public static func showShareOptions(
        config: ShareConfig,
        presentingViewController: UIViewController,
        sourceView: UIView? = nil,
        sourceRect: CGRect? = nil
    ) {
        // 构建自定义操作项数组
        var customActions: [ActionItem] = []
        
        // 1. 自定义快速分享（如果配置了）
        if let customNetworkShareHandler = CocoaDebugSettings.shared.customNetworkShareHandler {
            let quickAction = ActionItem(
                title: CocoaDebugSettings.shared.customNetworkShareTitle,
                style: .default
            ) {
                customNetworkShareHandler(config.messageBody, config.data as? _HttpModel)
            }
            customActions.append(quickAction)
        }
        
        // 2. 更多选项（系统分享）
        let moreAction = ActionItem(title: "more", style: .default) {
            showSystemShare(
                config: config,
                presentingViewController: presentingViewController,
                sourceView: sourceView,
                sourceRect: sourceRect
            )
        }
        customActions.append(moreAction)
        
        // 3. 构建邮件配置（如果配置了收件人）
        var emailConfig: EmailConfig? = nil
        if let emailRecipients = CocoaDebugSettings.shared.emailToRecipients,
           !emailRecipients.isEmpty,
           let firstRecipient = emailRecipients.first,
           !firstRecipient.isEmpty {
            var imageAttachments: [UIImage]? = nil
            if let image = config.image {
                imageAttachments = [image]
            }
            
            let subject = config.emailSubject ?? {
                if let httpModel = config.data as? _HttpModel,
                   let url = httpModel.url {
                    return url.absoluteString
                }
                return "Network Request"
            }()
            
            emailConfig = EmailConfig(
                subject: subject,
                messageBody: config.messageBody,
                recipients: emailRecipients,
                ccRecipients: CocoaDebugSettings.shared.emailCcRecipients,
                imageAttachments: imageAttachments
            )
        }
        
        // 4. 使用 ActionSheetHelper 展示弹框
        DebugActionSheetHelper.show(
            actions: customActions,
            emailConfig: emailConfig,
            includeCopyAction: true,
            copyText: config.messageBody,
            presentingViewController: presentingViewController,
            sourceView: sourceView,
            sourceRect: sourceRect
        )
    }
    
    /// 展示系统分享界面
    private static func showSystemShare(
        config: ShareConfig,
        presentingViewController: UIViewController,
        sourceView: UIView?,
        sourceRect: CGRect?
    ) {
        var items: [Any] = [config.messageBody]
        
        // 如果有图片，也添加到分享项中
        if let image = config.image {
            items.append(image)
        }
        
        // 创建自定义 activity 数组
        var applicationActivities: [CustomShareActivity] = []
        
        // 如果设置了自定义处理回调，创建自定义 activity
        let settings = CocoaDebugSettings.shared
        if let customHandler = settings.customNetworkShareHandler {
            let customActivity = CustomShareActivity(
                title: settings.customNetworkShareTitle,
                image: settings.customNetworkShareImage,
                handler: {
                    customHandler(config.messageBody, config.data as? _HttpModel)
                }
            )
            applicationActivities.append(customActivity)
        }
        
        DebugActionSheetHelper.showSystemShare(items: items,
                                          activities: applicationActivities,
                                          presentingViewController: presentingViewController,
                                          sourceView: sourceView,
                                          sourceRect: sourceRect)
    }
}
