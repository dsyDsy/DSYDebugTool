//
//  WKWebView+Swizzling.m
//  1233213
//
//  Created by man 2019/1/8.
//  Copyright © 2020 man. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "_ObjcLog.h"
#import "_NetworkHelper.h"

static NSString * const kCocoaDebugWKWebViewMonitoringKey = @"enableWKWebViewMonitoring_CocoaDebug";

static BOOL CocoaDebugWKWebViewMonitoringEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kCocoaDebugWKWebViewMonitoringKey];
}

static BOOL CocoaDebugSwizzleInstanceMethod(Class cls, SEL originalSelector, SEL replacedSelector) {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method replacedMethod = class_getInstanceMethod(cls, replacedSelector);
    if (originalMethod == NULL || replacedMethod == NULL) {
        return NO;
    }

    if (class_addMethod(cls,
                        originalSelector,
                        method_getImplementation(replacedMethod),
                        method_getTypeEncoding(replacedMethod))) {
        // 原方法可能来自父类，必须把父类实现保存到 replaced selector。
        class_replaceMethod(cls,
                            replacedSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, replacedMethod);
    }
    return YES;
}

@interface WKWebView () <WKScriptMessageHandler>
@end

@interface WKWebView (CocoaDebugSwizzlingPrivate)
- (void)installMessageHandlerNamed:(NSString *)name
                     configuration:(WKWebViewConfiguration *)configuration;
@end

/// WKUserContentController 会强持有 script message handler。
/// 不能直接把 WKWebView 自身作为 handler，否则会形成：
/// WKWebView -> configuration -> userContentController -> WKWebView。
@interface CocoaDebugWeakScriptMessageHandler : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> target;
- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target;
@end

@implementation CocoaDebugWeakScriptMessageHandler

- (instancetype)initWithTarget:(id<WKScriptMessageHandler>)target {
    self = [super init];
    if (self) {
        _target = target;
    }
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    // WebView 销毁后 target 会自动变为 nil，避免回调反向延长其生命周期。
    if (!CocoaDebugWKWebViewMonitoringEnabled()) {
        return;
    }
    id<WKScriptMessageHandler> target = self.target;
    if (target == nil) {
        return;
    }
    [target userContentController:userContentController didReceiveScriptMessage:message];
}

@end

@implementation WKWebView (_Swizzling)

#pragma mark - life
+ (void)load {
    // 保留在 +load 中完成一次性安装，但实际是否采集由运行时配置决定。
    // 这样首次启动时配置为 false、之后再打开开关时也不会错过 swizzle。
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CocoaDebugSwizzleInstanceMethod(self,
                                        @selector(initWithFrame:configuration:),
                                        @selector(replaced_initWithFrame:configuration:));
        CocoaDebugSwizzleInstanceMethod(self,
                                        NSSelectorFromString(@"dealloc"),
                                        @selector(replaced_dealloc));
    });
}

#pragma mark - replaced method

- (void)replaced_dealloc {
    //WKWebView
    if (CocoaDebugWKWebViewMonitoringEnabled()) {
        [_ObjcLog logWithFile:"[WKWebView]" function:"" line:0 color:[UIColor redColor] message:@"-------------------------------- dealloc --------------------------------"];
    }
    // method_exchangeImplementations 后，replaced_dealloc 指向原始 dealloc。
    // 必须继续转发，否则会导致 WebView 永远无法完成真正释放。
    [self replaced_dealloc];
}

- (instancetype)replaced_initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if (!CocoaDebugWKWebViewMonitoringEnabled()) {
        return [self replaced_initWithFrame:frame configuration:configuration];
    }

    //WKWebView
    [_ObjcLog logWithFile:"[WKWebView]" function:"" line:0 color:[_NetworkHelper shared].mainColor message:@"----------------------------------- init -----------------------------------"];
    
    [self log:configuration];
    [self error:configuration];
    [self warn:configuration];
    [self debug:configuration];
    [self info:configuration];
    
    return [self replaced_initWithFrame:frame configuration:configuration];
}

#pragma mark - private
- (void)log:(WKWebViewConfiguration *)configuration {
    [self installMessageHandlerNamed:@"log" configuration:configuration];
    //rewrite the method of console.log
    NSString *jsCode = @"console.log = (function(oriLogFunc){\
    return function(str)\
    {\
    window.webkit.messageHandlers.log.postMessage(str);\
    oriLogFunc.call(console,str);\
    }\
    })(console.log);";
    //injected the method when H5 starts to create the DOM tree
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
}

- (void)error:(WKWebViewConfiguration *)configuration {
    [self installMessageHandlerNamed:@"error" configuration:configuration];
    //rewrite the method of console.error
    NSString *jsCode = @"console.error = (function(oriLogFunc){\
    return function(str)\
    {\
    window.webkit.messageHandlers.error.postMessage(str);\
    oriLogFunc.call(console,str);\
    }\
    })(console.error);";
    //injected the method when H5 starts to create the DOM tree
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
}

- (void)warn:(WKWebViewConfiguration *)configuration {
    [self installMessageHandlerNamed:@"warn" configuration:configuration];
    //rewrite the method of console.warn
    NSString *jsCode = @"console.warn = (function(oriLogFunc){\
    return function(str)\
    {\
    window.webkit.messageHandlers.warn.postMessage(str);\
    oriLogFunc.call(console,str);\
    }\
    })(console.warn);";
    //injected the method when H5 starts to create the DOM tree
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
}

- (void)debug:(WKWebViewConfiguration *)configuration {
    [self installMessageHandlerNamed:@"debug" configuration:configuration];
    //rewrite the method of console.debug
    NSString *jsCode = @"console.debug = (function(oriLogFunc){\
    return function(str)\
    {\
    window.webkit.messageHandlers.debug.postMessage(str);\
    oriLogFunc.call(console,str);\
    }\
    })(console.debug);";
    //injected the method when H5 starts to create the DOM tree
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
}

- (void)info:(WKWebViewConfiguration *)configuration {
    [self installMessageHandlerNamed:@"info" configuration:configuration];
    //rewrite the method of console.info
    NSString *jsCode = @"console.info = (function(oriLogFunc){\
    return function(str)\
    {\
    window.webkit.messageHandlers.info.postMessage(str);\
    oriLogFunc.call(console,str);\
    }\
    })(console.info);";
    //injected the method when H5 starts to create the DOM tree
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:jsCode injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
}

- (void)installMessageHandlerNamed:(NSString *)name
                     configuration:(WKWebViewConfiguration *)configuration {
    WKUserContentController *userContentController = configuration.userContentController;
    [userContentController removeScriptMessageHandlerForName:name];
    CocoaDebugWeakScriptMessageHandler *handler =
        [[CocoaDebugWeakScriptMessageHandler alloc] initWithTarget:self];
    [userContentController addScriptMessageHandler:handler name:name];
}



#pragma mark - WKScriptMessageHandler
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    [_ObjcLog logWithFile:"[WKWebView]" function:[message.name UTF8String] line:0 color:[UIColor whiteColor] message:message.body];
}
#pragma clang diagnostic pop

@end
