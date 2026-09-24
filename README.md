# DSYDebugTool

适用于 iOS 应用的轻量级应用内调试工具集（In-App Debugger）。

---

## 核心特性

- **网络监控 (Network)**：拦截并展示 HTTP/HTTPS 请求与响应详情，支持请求搜索、JSON 高亮与快速分享。
- **日志控制台 (Logs)**：实时捕获并展示控制台日志，支持快速检索与按日志级别筛选。
- **沙盒文件浏览 (Sandbox)**：图形化浏览应用沙盒目录（Documents、Library、tmp 等），支持文件预览、分享与清理。
- **应用信息与崩溃监控 (App & Crash)**：显示应用与设备基础环境参数，记录未捕获异常与 Crash 堆栈。
- **性能与内存监控**：支持主线程卡顿浮标提示，以及控制器与视图的内存泄漏检测。

---

## 现代 iOS 适配与优化

- **零侵入 Window 响应**：重构 `hitTest` 命中测试机制，悬浮球状态下透明区域完全穿透，不抢占宿主 App 的 `KeyWindow`。
- **UIWindowScene 动态生命周期**：废弃异步轮询机制，基于系统场景通知动态接入活跃窗口场景。
- **悬浮球停靠与持久化**：用户拖拽松手后平滑弹性贴边，自动持久化用户偏好坐标并在冷启动时精准恢复。
- **Modern Glass 材质适配**：针对现代 iOS（iOS 26+ / iOS 27+）全面适配系统原生 Glass 毛玻璃效果与顶部操作控件。

---

## 安装与快速开始

### CocoaPods

在 `Podfile` 中添加：

```ruby
pod 'DSYDebugTool'
```

如需本地开发调试：

```ruby
pod 'DSYDebugTool', :path => '../DSYDebugTool'
```

### 初始化与使用

在应用启动（如 `didFinishLaunchingWithOptions`）时初始化：

```swift
import DSYDebugTool

// 1. 自定义基础配置（可选）
CocoaDebugSettings.shared.serverURL = "https://api.example.com"
CocoaDebugSettings.shared.enableLogMonitoring = true
CocoaDebugSettings.shared.enableCrashRecording = true

// 2. 显示入口悬浮球
CocoaDebug.showBubble()
```

隐藏悬浮球：

```swift
CocoaDebug.hideBubble()
```

---

## 许可协议

本项目基于 MIT 协议分发。
