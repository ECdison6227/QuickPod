<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a>
</p>

<p align="center">
  <img src="assets/banner.svg" alt="QuickPod" width="100%"/>
</p>

<p align="center">
  一个 macOS 菜单栏小工具：防睡眠、休息提醒、快捷切换、桌面文件创建
</p>

<p align="center">
  <a href="#安装">🚀 安装</a> ·
  <a href="#使用场景">📖 场景</a> ·
  <a href="#功能清单">✨ 功能</a> ·
  <a href="#开发">🔧 开发</a>
</p>

<p align="center">
  <a href="https://github.com/ECdison6227/QuickPod/releases"><img src="https://img.shields.io/github/v/release/ECdison6227/QuickPod" alt="Release" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/ECdison6227/QuickPod" alt="License" /></a>
</p>

---

## 一键使用

如果你不想手动下载，直接把下面这段 prompt 发给你的 Coding Agent（Trae / Codex / Claude Code），它会解释用法并引导你完成本地编译：

```text
请帮我本地编译并配置 https://github.com/ECdison6227/QuickPod 这个 macOS 菜单栏工具：

1. 先 git clone 到临时目录
2. 运行 ./build.sh 编译
3. 打开 build/QuickPod.app 并告诉我主界面怎么用
4. 引导我设置通知权限和全局快捷键
5. 演示如何开启防睡眠、设置休息提醒，以及新建一个桌面文件
```

---

## 目录

- [适合谁](#适合谁)
- [功能清单](#功能清单)
- [使用场景](#使用场景)
- [安装](#安装)
- [权限说明](#权限说明)
- [开发](#开发)
- [踩坑记录](#踩坑记录)
- [更新记录](#更新记录)
- [交流和反馈](#交流和反馈)

## 适合谁

- 长时间跑代码生成、构建、下载、推理任务，需要保持 Mac 不醒的人
- 用 AI Agent 跑长任务时，容易忘记休息的人
- 希望用菜单栏统一管理休息提醒、防睡眠和常用文件创建的人

## 功能清单

| 功能 | 说明 |
|------|------|
| **防睡眠** | 一键保持 Mac 唤醒，支持 15/30/60 分钟或不限时 |
| **休息提醒** | 可自定义间隔，支持 1 分钟测试，到点弹右上角提醒卡片 |
| **延后提醒** | 支持延后 5 分钟 / 10 分钟 |
| **快速切换器** | 全局快捷键呼出，方向键选择，Enter 确认 |
| **桌面新建文件** | TXT / MD / DOCX / XLSX / PPTX，支持自定义后缀 |
| **检查更新** | 优先读取 Releases 的 DMG/ZIP，API 限流时回退到网页检测 |

## 使用场景

### 场景 1：跑长任务时不让 Mac 睡眠

你在本地跑一个大模型推理或视频导出，合上盖子或锁屏后 Mac 可能自动睡眠。打开 QuickPod，选择防睡眠时长，菜单栏图标会显示当前状态。

### 场景 2：AI Agent 执行任务时的番茄钟

把休息提醒设成 25 分钟或 45 分钟。到点后不只是系统通知，还会从右上角弹出 QuickPod 自己的提醒卡片，防止你错过。

### 场景 3：讲课或现场演示时的循环计时

开启休息提醒后，每次提醒结束可以延后 5/10 分钟继续。这个功能也适合讲课、演讲或现场演示时作为循环计时器使用。

### 场景 4：快速在桌面创建文件

临时需要一个 `todo.md`、`note.txt` 或 `log.json`，按快捷键呼出切换器，选中文件类型即可在桌面创建。

## 安装

### 方法 1：从 Releases 下载（推荐）

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

QuickPod 核心功能只需要**通知权限**：

1. **通知权限**：用于休息提醒、测试通知和状态确认提醒。
2. **辅助功能（可选）**：当前全局快捷键基于 Carbon `RegisterEventHotKey`，不强制需要辅助功能；只在某些额外键盘监听场景下有帮助。
3. **开机启动（可选）**：如果你希望登录后自动运行，可以在设置里开启。

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

更多实现细节见 [ARCHITECTURE.md](ARCHITECTURE.md)。

## 踩坑记录

**通知权限识别不稳定**

早期版本依赖 `UNUserNotificationCenter` 的授权状态做判断，但在用户手动关闭通知后再打开时状态同步有延迟。v1.2 里改为在关键路径主动请求授权并做兜底处理。

**全局快捷键不响应**

如果快捷键被其他应用占用，QuickPod 不会提示冲突。建议先在设置里换一个组合键测试，比如 `Cmd+Shift+Space`。

**状态栏弹窗被其他窗口挡住**

休息提醒卡片使用 NSPanel 显示在屏幕右上角。如果开启了某些全屏辅助工具或窗口管理器，可能会覆盖层级。一般切到普通桌面即可恢复。

## 更新记录

### v1.2

- 修复通知权限识别不稳定的问题
- 新增右上角休息提醒卡片
- 新增自定义提醒分钟数和 `1 分钟测试`
- 新增自定义文件后缀
- 更新状态栏圆环样式与引导动画素材

### v1.0.0

- 初始版本

## 交流和反馈

- 发现 bug 或功能建议：开 [Issue](https://github.com/ECdison6227/QuickPod/issues)
- 安全漏洞：请邮件到 `2014184720@qq.com`，不要公开 Issue
- 架构和开发问题：见 [ARCHITECTURE.md](ARCHITECTURE.md) 和 [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT License. 见 [LICENSE](LICENSE)。
