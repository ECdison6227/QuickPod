# QuickPod

[![Download](https://img.shields.io/github/v/release/ECdison6227/QuickPod)](https://github.com/ECdison6227/QuickPod/releases)
[![License](https://img.shields.io/github/license/ECdison6227/QuickPod)](LICENSE)

macOS 菜单栏效率工具集 - 专为 AI Coding Agent 长时间运行设计

[English Version](README.en.md) | [架构文档](ARCHITECTURE.md)

## 🎯 主要用途

**专为 AI Coding Agent（如 Claude、CodeLlama、StarCoder 等）设计**，确保在执行长时间代码生成任务时：

- ✅ 防止 Mac 自动休眠中断任务
- ✅ 保持系统唤醒状态直到任务完成
- ✅ 支持定时防睡眠，避免不必要的功耗
- ✅ 休息提醒帮助保护视力和健康

## 功能特点

### 🔋 防睡眠
- 防止 Mac 自动休眠，确保长时间任务顺利完成
- 支持定时关闭（15分钟/30分钟/1小时/无限）
- 状态栏图标实时显示防睡眠状态
- 完美适配 AI coding agent 长时间运行场景

### ⏰ 休息提醒
- 自定义提醒间隔
- 支持系统通知和弹窗提醒
- 延后5分钟/10分钟功能

### 🧹 屏幕清洁
- 全屏黑色清洁模式
- 按任意键或点击退出

### ⚡ 快速切换器
- 全局快捷键呼出
- 快速访问常用功能

### 📝 新建文件
- 支持 TXT、MD、DOCX、XLSX、PPTX
- 自定义默认文件名

### 🔄 自动更新
- 支持检查 GitHub 最新版本
- 一键下载更新

## 📷 应用截图

### 主设置窗口
![QuickPod 设置窗口](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/main-window.png)

### 快速切换器
![QuickPod 快速切换器](https://raw.githubusercontent.com/ECdison6227/QuickPod/main/screenshots/quick-switcher.png)

## 安装

### 方法1：下载 DMG（推荐）
1. 从 [Releases](https://github.com/ECdison6227/QuickPod/releases) 下载最新版本
2. 双击 `.dmg` 文件
3. 将 `QuickPod.app` 拖到 Applications 文件夹

### 方法2：源码编译
```bash
git clone https://github.com/edison/QuickPod.git
cd QuickPod
./build.sh
open build/QuickPod.app
```

## 系统要求

- macOS 13.0 (Ventura) 或更高版本

## 权限说明

首次使用时，QuickPod 需要以下权限：

1. **通知权限** - 用于休息提醒
2. **辅助功能** - 用于全局快捷键
3. **完全磁盘访问** - （可选）用于某些高级功能

## 使用方法

1. 运行应用后，QuickPod 会显示在菜单栏
2. 点击菜单栏图标打开快捷面板
3. 点击齿轮图标打开设置窗口

## 开发

### 技术栈
- Swift 5.9+
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

## 更新日志

### v1.0.0 (2026-05-26)
- 初始版本
- 防睡眠功能
- 休息提醒
- 屏幕清洁
- 快速切换器
- 新建文件模板
- 自动检查更新

## License

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
