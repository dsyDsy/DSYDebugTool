
Pod::Spec.new do |s|
  s.name             = 'DSYDebugTool'
  s.version          = '1.0.2'
  s.summary          = 'A short description of DSYDebugTool.'

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/dsy/DSYDebugTool'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'dsy' => 'dsy.ds@qq.com' }
  s.source           = { :git => 'https://github.com/dsyDsy/DSYDebugTool.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '12.0'
  
  # 基于CocoaDebug改动 原项目地址 https://github.com/CocoaDebug/CocoaDebug
  s.subspec 'CocoaDebug' do |ss|
    ss.requires_arc        = false
    ss.requires_arc        =
                            [
                            'DSYDebugTool/Classes/CocoaDebug/App/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Categories/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Core/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/CustomHTTPProtocol/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Logs/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Network/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Sandbox/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Swizzling/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/Window/**/*.m',
                            'DSYDebugTool/Classes/CocoaDebug/fishhook/**/*.c',
                            ]
        ss.source_files        = "DSYDebugTool/Classes/CocoaDebug", "DSYDebugTool/Classes/CocoaDebug/**/*.{h,m,mm,swift,c}"
        ss.public_header_files = "DSYDebugTool/Classes/CocoaDebug/**/*.h"
        ss.resources           = "DSYDebugTool/Classes/CocoaDebug/**/*.{png,xib,storyboard}"
        ss.frameworks          = 'UIKit', 'Foundation', 'JavaScriptCore', 'QuickLook'
  end
  
    s.subspec 'TransferServer' do |ss|
            ss.source_files        = "DSYDebugTool/Classes/TransferServer", "DSYDebugTool/Classes/TransferServer/**/*.{h,m,mm,swift,c}"
            ss.resources           = "DSYDebugTool/Classes/TransferServer/**/*.{png,xib,storyboard}"
            ss.frameworks          = 'UIKit', 'Foundation'
            ss.dependency  'GCDWebServer'
      end
end
