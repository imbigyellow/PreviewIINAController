# PreviewIINAController

一个极轻量、原生的 macOS 后台小工具。在 Preview（预览）阅读时，用自定义裸键控制后台的 IINA，默认如下：

| 按键 | 操作 |
| --- | --- |
| Q | 后退 5 秒 |
| W | 播放 / 暂停 |
| E | 前进 5 秒 |

**仅在 Preview 位于前台时生效。** 切换到其他应用后，Q/W/E 正常输入。Command、Option、Control、Shift 等修饰键组合原样放行。无 Dock 图标、菜单栏图标或常驻主窗口；不自动设置登录启动。

## Requirements

- Apple Silicon Mac（arm64，M 系列）；不支持 Intel Mac。
- macOS：构建最低版本为 13.0，实际使用验证环境为 macOS 26.6.2；其他版本尚未验证。
- [IINA](https://iina.io/)。
- macOS 自带 Preview（预览）。

## IINA 设置

在 IINA 的 **设置 → 高级 → Additional mpv options** 中添加：

| 名称 | 值 |
| --- | --- |
| `input-ipc-server` | `/tmp/iina-socket` |

如高级设置尚未启用，先启用高级设置。保存后重新启动 IINA。

## Installation

1. 从 [GitHub Releases](https://github.com/imbigyellow/PreviewIINAController/releases/latest) 下载 **`PreviewIINAController-arm64.zip`**。不要下载 GitHub 自动生成的 **Source code (zip/tar.gz)**，它们只有源码，不能直接运行。
2. 解压，把 `PreviewIINAController.app` 拖入 `/Applications`（应用程序）。
3. 双击启动。本版本只有本地 ad-hoc 代码签名，**没有 Apple Developer ID 签名，也没有经过 Apple notarization（公证）**，Gatekeeper 可能阻止首次打开。
4. 如果被阻止，在确认下载来源后，打开 **系统设置 → 隐私与安全性**，找到该应用被阻止的提示，点击 **仍要打开 / Open Anyway**，按系统要求认证并确认打开。应先尝试打开应用，相关按钮才会出现；不需要关闭 Gatekeeper。参见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。
5. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 `PreviewIINAController`。如列表中没有它，用“+”添加 `/Applications/PreviewIINAController.app`。
6. 关闭应用的权限提示，然后重新启动应用。无须授予 Input Monitoring（输入监控）权限。

只运行一份应用。移动应用或更新/重新构建后，macOS 可能要求重新授予辅助功能权限。

## Usage

打开 IINA 并播放音频，然后切换到 Preview 阅读：Q = -5s，W = Play/Pause，E = +5s。切换到其他 App 后，Q/W/E 正常输入。

应用在后台常驻，正常运行不会弹窗或抢前台焦点。退出时，在“活动监视器”中找到 `PreviewIINAController` 并退出。

### 自定义按键和秒数（v1.1.0）

应用运行后，**再次双击 `/Applications/PreviewIINAController.app`** 打开设置窗口。若应用尚未运行，第一次双击只会在后台启动，再次双击才打开设置。

- 点击一行的按键按钮，按下要使用的字母或数字裸键；Esc 取消录入。
- 后退、前进秒数可分别设置为 1–3600 的整数，例如 3 秒和 5 秒。
- 三个按键不能重复。Command、Option、Control、Shift、Fn 等组合不接受绑定，并继续原样放行。
- 点击“保存”后立即生效并保存在本机；关闭窗口不保存尚未提交的更改。
- “恢复默认”将表单恢复为 Q/W/E 和 5 秒，再点“保存”确认。

窗口按需创建、关闭后释放。没有新增后台轮询或 timer；设置仅在启动时读取、保存时更新，按键回调不读写配置文件。配置通过 macOS UserDefaults 存放在 `local.PreviewIINAController` 域，不会上传。

更新时先退出旧版本，再用新版替换应用程序中的 App。可能需要重新授予辅助功能权限。历史 [v1.0.0](https://github.com/imbigyellow/PreviewIINAController/releases/tag/v1.0.0) 及其下载文件继续保留；回退旧版会恢复固定 Q/W/E + 5 秒行为。

### 已知限制

- Preview 搜索框和其他文本输入场景中的已绑定裸键也会被拦截。
- 使用物理键位，不随键盘布局变化；界面字母/数字标签按 ANSI 键位显示，默认键码为 12/13/14。
- Caps Lock 或 Fn 等标志存在时放行；按住裸键会按系统设置重复触发，包括 W。
- IINA 未运行、socket 不存在或忙碌时静默丢弃命令；Preview 中已绑定的裸键仍会被吞掉。
- macOS 安全输入模式可能阻止 EventTap 接收按键。

## Privacy

无 analytics、telemetry 或键盘输入上传。不建立互联网连接；仅通过本机 Unix Domain Socket `/tmp/iina-socket` 向 IINA 发送固定命令。EventTap 只用于本地快捷键过滤：非已绑定按键立即放行，带修饰键或 Preview 不在前台时也返回原始事件。不模拟或重新注入键盘事件，不持续写日志。

## Build from source

需要 Apple Silicon Mac 和 Xcode Command Line Tools（或 Xcode），没有第三方依赖：

```bash
git clone https://github.com/imbigyellow/PreviewIINAController.git
cd PreviewIINAController
./build.sh
```

输出为 `build/PreviewIINAController.app`。脚本固定构建 arm64 Release（`-O`、whole-module optimization），并将编译警告视作错误。默认使用 ad-hoc 签名和固定 bundle identifier `local.PreviewIINAController`。本地签名不是 Apple 认证的发布身份。

生成独立发行包，不覆盖 `build`：

```bash
./release.sh
```

输出为 `dist/PreviewIINAController-arm64.zip`；用 macOS `ditto` 保留 app bundle、可执行权限和必要 metadata。可通过 `SIGNING_IDENTITY` 指定自己的代码签名证书；脚本不会执行 notarization。

运行过滤逻辑测试：

```bash
./test.sh
./test-ui.sh  # 原生窗口校验；会短暂打开独立测试窗口，不启动 EventTap
```

## 实现与维护

Swift + AppKit/NSWorkspace + CoreGraphics CGEventTap + GCD + Darwin Unix socket。启动时读取一次前台应用，此后通过应用激活通知更新缓存。通知和 EventTap 共享主 RunLoop，IPC 在专用串行队列上执行；无空闲轮询或 timer。

EventTap callback 只过滤、投递命令并返回；非阻塞 socket、partial write、SIGPIPE 和错误路径在 IPC 队列处理。运行时不依赖 shell、AppleScript、osascript、nc、skhd、Karabiner 或外部控制脚本。仓库中的 shell 脚本只负责构建、打包、测试或清理。

核心功能已在 Apple Silicon / macOS 26.6.2 实际使用验证。v1.1.0 自动测试覆盖默认/自定义键位、255 种修饰键组合、JSON 命令、配置持久化、无效配置回退和设置窗口的校验/保存流程；未通过模拟键盘验证真实录键或 IINA 联动。未来修改以本仓库为基础。

## Uninstall

1. 在“活动监视器”退出 `PreviewIINAController`。
2. 将 `/Applications/PreviewIINAController.app` 移到废纸篓。
3. 如需要，在 **系统设置 → 隐私与安全性 → 辅助功能** 中选中本应用并点击“−”移除授权。

不会删除或修改 IINA、IINA 设置或 `/tmp/iina-socket`。是否删除 IINA 的 IPC 配置由你自行决定。

源码用户可在退出本地构建后执行 `./uninstall.sh` 清理本项目 `build` / `dist` 中列出的生成文件；脚本保留源码、用户设置和 Git 历史，不操作 `/Applications` 或权限数据库。不再需要源码时，可自行将整个仓库目录移到废纸篓。

## License

[MIT](LICENSE)
