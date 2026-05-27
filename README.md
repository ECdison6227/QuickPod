# QuickPod

[![Release](https://img.shields.io/github/v/release/ECdison6227/QuickPod)](https://github.com/ECdison6227/QuickPod/releases)
[![License](https://img.shields.io/github/license/ECdison6227/QuickPod)](LICENSE)

QuickPod 是一个为长时间 Coding、AI Agent 执行任务和深度专注场景设计的 macOS 菜单栏工具箱。它把防睡眠、休息提醒、快捷切换和桌面文件创建放到一个很轻的状态栏入口里。

[English Version](README.en.md) | [架构文档](ARCHITECTURE.md)

## 适合谁

- 长时间跑代码生成、构建、下载、推理任务的人
- 希望用菜单栏统一管理休息提醒和防睡眠的人
- 想快速创建常用空白文件的人

## 主要功能

### 防睡眠
- 一键保持 Mac 唤醒
- 支持 `15 分钟 / 30 分钟 / 1 小时 / 不限时`
- 菜单栏图标会显示当前状态

### 休息提醒
- 预设提醒间隔，也支持自定义分钟数
- 支持 `1 分钟测试`
- 开启时会先发一条确认通知
- 到点后除了系统通知，还会从右上角弹出 QuickPod 自己的提醒卡片
- 支持延后 `5 分钟 / 10 分钟`

### 快速切换器
- 全局快捷键呼出
- 方向键切换，`Enter` 确认
- 快速开关防睡眠、休息提醒、屏幕清洁和文件创建

### 新建文件到桌面
- 支持 `TXT / MD / DOCX / XLSX / PPTX`
- 支持自定义默认文件名
- 支持自定义文件后缀，比如 `log`、`json`、`todo`

### 检查更新
- 检查 GitHub Releases 最新版本
- 优先打开直接可下载的 `DMG/ZIP` 资源
- GitHub API 被限流时会自动回退到网页重定向检测

## 应用截图

### 主设置窗口
![QuickPod 主设置窗口](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/main-window.png)

### 快速切换器
![QuickPod 快速切换器](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/quick-switcher.png)

### 休息提醒弹窗
![QuickPod 休息提醒弹窗](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/break-reminder.png)

### 状态栏样式
![QuickPod 状态栏预览](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/status-bar-panel.png)

## 安装

### 方法 1：从 Releases 下载
1. 打开 [Releases](https://github.com/ECdison6227/QuickPod/releases)
2. 下载最新版本的 `.dmg`
3. 将 `QuickPod.app` 拖到 `Applications`

### 方法 2：本地编译
```bash
git clone https://github.com/ECdison6227/QuickPod.git
cd QuickPod
./build.sh
open build/QuickPod.app
```

## 系统要求

- macOS 13 Ventura 或更高版本

## 权限说明

QuickPod 当前主路径真正依赖的权限只有通知权限：

1. `通知权限`
用于休息提醒、测试通知和状态确认提醒。

2. `辅助功能（可选）`
当前全局快捷键基于 Carbon `RegisterEventHotKey`，不依赖辅助功能；这个权限只对某些可选键盘监听场景有帮助。

3. `开机启动`
如果你希望登录后自动运行 QuickPod，可以在设置里开启。

## 开发

### 技术栈
- Swift
- SwiftUI
- AppKit
- UserNotifications
- ServiceManagement

### 构建
```bash
./build.sh
```

### 打包 DMG
```bash
./create_dmg.sh
```

## 更新记录

### v1.2
- 修复通知权限识别不稳定的问题
- 新增右上角休息提醒卡片
- 新增自定义提醒分钟数和 `1 分钟测试`
- 新增自定义文件后缀
- 更新状态栏圆环样式与引导动画素材

### v1.0.0
- 初始版本

## License

MIT
