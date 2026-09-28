# GPT 翻译助手 · DongMugua 增强版

一个原生 macOS SwiftUI 翻译软件：常驻菜单栏，使用 ChatGPT OAuth 登录的本机 Codex CLI 会话进行翻译，并支持跨应用划词、截图和 OCR。

## 下载增强版

[最新 Release](https://github.com/DongMugua/GPT-Translator/releases/latest) · [DMG 安装包](https://github.com/DongMugua/GPT-Translator/releases/download/v1.2.5-local.2/GPT-Translator-1.2.5-local.2-macOS-arm64.dmg) · [ZIP 应用包](https://github.com/DongMugua/GPT-Translator/releases/download/v1.2.5-local.2/GPT-Translator-1.2.5-local.2-macOS-arm64.zip)

当前提供 Apple Silicon（M 系列，arm64）版本，要求 macOS 13 或更高版本；Apple 离线翻译要求 macOS 15 或更高版本。先退出旧版，再打开 DMG 将应用拖入 Applications，或解压 ZIP 后打开应用。该版本采用本地签名，未经 Apple Developer ID 公证；首次打开及辅助功能权限可能需要在系统设置中确认。下载校验值和具体验证范围见 Release 页面。

应用内更新检查仍指向上游，请通过本仓库 Releases 手动更新增强版。使用 OpenAI/ChatGPT OAuth 仍需在本机安装 Node.js、Codex CLI 并完成登录；发布包不附带 CLI 或个人登录凭据。

## 本分支优化（1.2.5-local.2，2026-09-28）

这是 [DongMugua](https://github.com/DongMugua) 维护的个人增强 fork，基于 [fuyao123/GPT-Translator](https://github.com/fuyao123/GPT-Translator) 的 v1.2.5，基线提交为 `192f4c4e88a9c8dab00572fc6d1997f48d86cb61`。原项目由 [fuyao123](https://github.com/fuyao123) 开发，原作者署名、提交历史及第三方声明保留。本分支主要改善阅读文献时的划词体验，并修复图形界面启动时的 CLI 登录问题。

- **可隐藏原文**：在“设置 → 划词翻译”中切换原文显示。默认隐藏原文，直接阅读结果；开关会保存，修改后立即影响已打开的结果窗。
- **图钉固定窗口位置**：钉住后，后续划词与翻译完成时的窗口尺寸调整保留窗口左上角位置。可以拖动到新位置，后续结果保留该位置；取消钉住后恢复随选词位置弹出。接近屏幕边缘时优先保证窗口留在屏幕内。
- **单词词典模式**：单个英语、西班牙语、法语或德语等拉丁字母单词自动显示词典式释义，支持重音字母、连字符和撇号；短语、句子继续普通翻译。主窗口、快捷输入框与截图保持原有翻译模式。中文、日文、韩文等连续书写文本继续普通翻译，避免把整句误判为一个词。
- **修复 Node.js 路径问题**：从 Finder 启动时也能找到 Homebrew 安装的 Node.js，解决登录时的 `env: node: No such file or directory`；登录状态检测及 CLI 翻译共用修复后的进程环境。

词典释义使用已启用的翻译源：LLM 来源按词性列出常见含义、可靠的音标与例句，并避免编造不存在的义项。Google 来源在接口提供词典数据时显示多义项，否则提示降级为普通翻译；Apple 离线翻译不提供词典义项，会明确提示这一限制。应用不会为查词擅自启用其他云端来源。模型生成的释义可能有误，并非授权词典原文。

### 1.2.5-local.2：修复从 Finder 启动时无法登录

修复 `env: node: No such file or directory`：macOS 图形应用可能没有终端中的完整 `PATH`。即使已经找到 Homebrew 安装的 `codex` 脚本，该脚本的 `#!/usr/bin/env node` 仍可能找不到 Node.js。

现在登录、登录状态检测、常驻翻译和单次 CLI 翻译共用进程环境处理：保留已有环境和 PATH 顺序，补充 CLI 所在目录、Homebrew、本地用户与系统命令目录。Codex 和 Antigravity 的所有启动路径均已接入，不修改 shell 配置、系统环境或登录凭据。

### 本地构建与验证

```bash
swift test --disable-xctest
APP_OUTPUT_DIR="$PWD/dist/local" APP_VERSION="1.2.5-local.2" SIGNING_IDENTITY="-" zsh scripts/build-app.sh
open "$PWD/dist/local/GPT翻译助手.app"
```

该命令把本地应用放入 `dist/local`。先退出原版，再打开本地构建；如 macOS 要求，重新为该应用授予辅助功能权限。图钉状态与位置保持到本次运行结束，不跨应用重启保存。

回归检查：关闭/开启原文显示并重启确认设置保存；钉住后在不同位置连续划词、拖动窗口后再次划词；选择 `bank`、`well-being` 与 `bank account`，分别检查词典与普通翻译。自动测试覆盖单词判定、提示词、缓存模式与窗口布局；实际云服务输出和 macOS 辅助功能划词需要在安装后验证。

本机已通过 27 项离线测试（Swift Testing，7 项窗口布局、12 项词典请求、8 项 CLI 进程环境），调试与 Release 构建通过；已打包 `1.2.5-local.2` Apple Silicon 应用并通过本地签名完整性验证。在精简 GUI PATH 下，用修复后的环境实际运行 `codex --version` 和 `codex login status` 均成功。实际模型输出、跨应用划词和多显示器实机操作尚未验证。

<details>
<summary>本机 Command Line Tools 环境的测试命令</summary>

本机为 Apple Silicon、Swift 6.4，使用已安装的 macOS 26.5 SDK。只有 Command Line Tools 时，可能需要显式提供 Testing 框架及宏插件路径。以下命令在本地执行了全部 27 项测试；SDK 路径应按实际安装情况调整。

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
swift test --disable-xctest --enable-swift-testing --disable-sandbox \
  --build-system native \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
  --cache-path "$PWD/.build/cache" --manifest-cache local \
  -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

</details>

### 许可证状态

截至此基线提交，未找到主程序的项目级许可证。`THIRD_PARTY_NOTICES.md` 中的 Apache-2.0 声明仅适用于图标中的 Google Material Symbols 字形，并不授权整个应用。

本 fork 未为上游代码另行添加 MIT、Apache 或其他项目许可证，也不声称已获得上游额外的修改与再分发授权。仓库公开及 GitHub 的 fork 功能不等于授予一般用途下的使用、修改或再分发许可；如需在 GitHub fork 功能之外使用或分发相关代码及应用，请先确认原作者授权。原作者署名与第三方声明不能替代项目许可证。相关说明见 [GitHub 仓库许可文档](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository)。

## 产品构想

做一个简洁的翻译软件与截图软件的融合版：不堆叠复杂界面，把划词翻译、快捷输入、截图标注、OCR 识别和截图翻译串联在同一条轻量工作流中。需要翻译时随手划词，需要记录或说明时直接截图标注，尽量减少应用切换和重复操作。

## 功能

- 菜单栏翻译图标
- 自动识别原文语言，支持中文、英语、日语、韩语、西班牙语、法语和德语
- 在任意应用选中文字后按 `⌘⇧T` 翻译
- 划词翻译默认在选中文字后直接翻译；也可切换为显示翻译图标，将鼠标移到图标上即可翻译
- 按 `⌘⇧S` 截图，拖动选择区域后用 macOS Vision OCR，再翻译识别结果
- 按 `⌘⇧A` 普通截图，使用微信式紧凑工具栏进行画笔、形状、箭头、文字、自由涂抹马赛克、置顶、复制和保存
- 按 `⌘⇧O` 截图 OCR，只识别选区文字并复制到剪贴板，不进行翻译
- 截图选区支持像素放大取色、HEX 与 RGB 色号和 `⌘C` 复制；截图下方可直接显示 OCR 翻译结果
- 截图标注支持手型工具移动画笔、形状、箭头和文字；文字可调整颜色与字号，选中标注后可按 `Delete` 或 `Backspace` 删除
- 画笔、矩形和圆形边框支持滑块无级调节粗细；颜色面板可在常用色卡与连续渐变色盘之间切换
- 可保留多张截图继续取景，置顶截图聚焦后可按 `Esc` 关闭
- 按 `⌘⇧D` 打开类似 Spotlight 的快捷翻译框，自动判断中英文并互译
- 快捷翻译框支持拖动、钉住、复制、写回原输入框，以及最近 20 条本机历史记录
- 划词、普通截图、截图 OCR、截图翻译和快捷翻译框均可在设置中自定义组合键与字母键，重复快捷键会提示冲突
- 主窗口停止输入后自动翻译：机器翻译约 0.28 秒触发，GPT 类翻译约 0.48 秒触发
- OAuth 翻译源在后台预热并复用常驻 CLI 进程，连续翻译不会重复启动 Codex 或 `agy`；Gemini 启用后会通过轻量 `agy` 请求主动唤醒并自动重试，不启动 Antigravity 桌面端及其音频组件
- 最近 100 条结果使用内存缓存，重复翻译可立即显示
- 保留段落、Markdown、标点和换行
- 使用 ChatGPT OAuth：应用不要求、不保存 OpenAI API Key
- 支持 OpenAI/ChatGPT OAuth、Gemini/Google OAuth（通过官方 Antigravity CLI）、DeepSeek、智谱 GLM，以及可重复添加的 OpenAI Chat Completions 兼容 API
- 支持 Apple 离线翻译；首次使用缺失语言时由 macOS 下载语言包，之后可离线使用且不消耗 API token（需要 macOS 15 或更高版本）
- 每个自定义 API 可独立设置显示名称、接口地址、模型和 API Key
- 划词和截图悬浮窗支持多来源并行对照、拖拽排序和顺序记忆
- 菜单栏显示所有已开启来源的连接状态，启动时检测，之后每小时检测，也可手动刷新
- 启动时自动检查 GitHub 正式版本，菜单栏右下角提示并可打开新版下载页
- 每个第三方服务和自定义配置的 API Key 独立保存在 macOS 钥匙串
- 可选择预设或自定义模型，并设置关闭、低、中、高、极高推理强度
- 可在菜单栏决定是否翻译中文内容，并可选择是否在 Dock 中显示应用
- 设置中支持隐藏 Dock 图标，并可选择登录 macOS 时自动启动

## 运行

需要 macOS 13 或更高版本和 Swift 6 / Xcode Command Line Tools。若使用 OpenAI/ChatGPT OAuth 翻译源，需要自行安装 Codex CLI 并完成 `codex login`；若使用 Gemini/Google OAuth 翻译源，需要自行安装 Antigravity CLI（`agy`）并完成 Google 登录。

```bash
swift run
```

第一次使用 OpenAI/ChatGPT OAuth 时，需先自行配置 Codex CLI，也可以打开应用“设置”点击“使用 ChatGPT 登录”，在浏览器完成 OAuth。Gemini/Google OAuth 源复用用户自行配置的 `agy` CLI 登录会话。本应用不附带这些 CLI，也不会读取、复制或打包 OAuth Token。DeepSeek、智谱或自定义兼容 API 需要填写对应 API Key。生成并安装应用：

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open "$HOME/Applications/GPT翻译助手.app"
```

构建脚本会把唯一的应用副本安装到 `~/Applications/GPT翻译助手.app`。首次划词翻译需要在“系统设置 → 隐私与安全性 → 辅助功能”中允许这一份应用；首次截图时需要允许屏幕录制。

应用图标采用自制蓝紫渐变双气泡设计；许可说明见 `THIRD_PARTY_NOTICES.md`。菜单栏图标为适配浅色和深色菜单栏的单色环形翻译标识。

## 上游原版 DMG 安装

从[原项目 Releases](https://github.com/fuyao123/GPT-Translator/releases) 下载 `GPT-Translator-1.2.5-macOS.dmg`，打开后把“GPT 翻译助手”拖入 Applications。该原版安装包不包含本 fork 的优化；使用增强版请从[本仓库 Releases](https://github.com/DongMugua/GPT-Translator/releases/latest) 下载，或按上面的命令从本分支源码构建。当前应用内更新检查仍指向上游版本，不会分发本分支的改动。原版公开构建未使用 Apple Developer ID 公证；macOS 首次打开时可能需要在 Finder 中右键应用并选择“打开”。

## 隐私与凭据

- 发布包不包含开发者或使用者的 API Key、ChatGPT/OpenAI 登录令牌、账号信息或本机偏好设置。
- OpenAI 登录由用户本机安装的 Codex CLI 管理，应用不会把 OAuth 凭据复制进应用目录。
- DeepSeek、智谱和自定义 API Key 仅写入当前用户的 macOS 钥匙串，不写入源码、配置文件或 DMG。
- 每位安装者需要在自己的 Mac 上完成登录并填写自己的 API Key。

## 支持原作者

以下为原项目保留的赞赏二维码，收款方为原作者 fuyao123，并非本 fork 维护者。如果这个小工具对你有帮助，可以自愿扫码支持原作者后续维护。

<img src="Assets/donate-wechat.jpg" alt="微信赞赏二维码" width="320">

## 认证边界

本项目通过安装者本机的 `codex login` 会话使用 OpenAI/ChatGPT OAuth，不把 ChatGPT token 伪装成普通 API Key。DeepSeek、智谱和自定义来源使用 OpenAI Chat Completions 兼容接口。
