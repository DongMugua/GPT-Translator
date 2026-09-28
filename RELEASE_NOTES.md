# v1.2.5-local.3 · 格式化翻译与可调结果窗口

改进阅读论文时的格式与公式保留，修复译文撑宽窗口、窗口高度跳变及末尾内容不完整的问题。保留 v1.2.5-local.2 的原文开关、图钉固定、单词词典和 GUI 登录修复。

## 本次更新

- **保留基本格式**：优先读取选区的辅助功能富文本或 RTF，保留粗体、斜体与上下标，并让翻译保留段落、标题和列表结构。
- **保护公式与代码**：翻译前保护可识别的公式、代码和数字引用，返回后恢复原内容，避免把论文变量误译成汉字。若翻译源破坏或遗漏保护内容，则提示失败，避免静默显示缺失的公式。
- **原生格式显示**：结果支持基本 Markdown、可选中文本及自动换行；简单上下标与常见希腊字母可直接显示。复杂 LaTeX 保留为可读源码，表格保留结构化文本。
- **用户控制窗口宽高**：拖动边框可调整两个方向。内容区默认宽 500 点、最小宽 320 点；调整后的宽度会保存，翻译过程不再自动改变宽度。手动高度作为可见区域上限保存，高度在上限内随内容调整，长结果可滚动查看全部内容。
- **稳定钉住后的布局**：内容从固定的左上角向下增长，到达屏幕边缘或用户设置的高度上限后滚动；长单词、代码及公式在当前宽度内换行。

## 下载与安装

- `GPT-Translator-1.2.5-local.3-macOS-arm64.dmg`：打开后将应用拖入 Applications。
- `GPT-Translator-1.2.5-local.3-macOS-arm64.zip`：解压即得应用。
- `SHA256SUMS.txt` 与 `BUILD_INFO.txt`：下载校验值、源码提交及构建信息。

适用于 **Apple Silicon（M 系列，arm64）Mac、macOS 13 或更高版本**；Apple 离线翻译要求 macOS 15 或更高版本。先退出旧版再安装。当前构建采用本地 ad-hoc 签名，**未经 Apple Developer ID 公证**；首次打开及辅助功能权限可能需要在系统设置中确认。

OpenAI/ChatGPT OAuth 仍需本机 Node.js、Codex CLI 与登录会话；Gemini 来源需自行配置 Antigravity CLI。安装包不附带 CLI、API Key、OAuth 凭据或个人偏好设置。内置更新检查仍指向上游，请从本仓库 Releases 手动更新。

## 验证范围与限制

- 63 项离线自动测试通过，涵盖 7 个测试套件；包括实际 AppKit/SwiftUI 承载视图、TextKit 高度计算、固定宽度换行及滚动到末尾的检查。
- 这不是完整的数学排版引擎。未支持的 LaTeX 命令保留原文，不会猜测公式含义。
- 格式保留取决于来源应用提供的选区属性；无法恢复 PDF 已损坏的文字提取，也不保证复现复杂多栏或表格版式。
- 本次真实云端模型、跨应用选区及多显示器拖动尚未完成实机验证。
- 图钉状态与位置仍只在本次运行中保留；用户调整的窗口宽度和高度上限会保存。Google、Apple 的词典能力限制延续上一版本。

原作者署名、上游基线和许可证状态沿用以下版本说明及仓库 README；本次未变更项目许可。

---

# v1.2.5-local.2 · 划词体验增强与登录修复

DongMugua 增强分支的首个发布版本，基于 [fuyao123/GPT-Translator](https://github.com/fuyao123/GPT-Translator) v1.2.5。保留原作者署名、提交历史及第三方声明。

## 四项优化

- **原文显示开关**：新增“划词翻译显示原文”设置，默认隐藏原文，设置会保存并立即生效。
- **钉住窗口保留位置**：连续划词与结果大小变化时保留窗口左上角；拖动后使用新位置，取消钉住后恢复随鼠标弹出。屏幕边缘会适当调整位置以保证可见，钉住状态不跨重启保存。
- **单词词典模式**：单个拉丁字母单词显示词性、常见多义项及例句，支持重音、连字符和撇号；短语、句子照常翻译。主窗口、快捷输入和截图仍使用普通翻译。
- **修复 GUI 登录环境**：补齐 CLI 进程查找路径，解决 Finder 启动时的 `env: node: No such file or directory`。登录、状态检测和翻译进程均使用修复后的环境。

## 下载与安装

- `GPT-Translator-1.2.5-local.2-macOS-arm64.dmg`：推荐，打开后将应用拖入 Applications。
- `GPT-Translator-1.2.5-local.2-macOS-arm64.zip`：解压即得应用。
- `SHA256SUMS.txt`：下载文件的 SHA-256 校验值。
- `BUILD_INFO.txt`：构建对应的源码提交、架构和签名说明。

安装包适用于 **Apple Silicon（M 系列，arm64）Mac**，不适用于 Intel Mac。最低要求 macOS 13；Apple 离线翻译要求 macOS 15 或更高版本。

先退出旧版再安装。当前构建采用本地 ad-hoc 签名，**未经 Apple Developer ID 公证**；若系统拦截首次打开，请在“系统设置 → 隐私与安全性”中查看提示。划词需辅助功能权限，截图需屏幕录制权限。

OpenAI/ChatGPT OAuth 来源仍需自行安装 Node.js、Codex CLI 并完成登录；Gemini 来源需自行配置 Antigravity CLI。安装包不包含这些 CLI、API Key、OAuth 登录凭据或本机偏好设置。

## 验证范围与已知限制

- 27 项离线自动测试通过：7 项窗口布局、12 项词典请求、8 项 CLI 环境测试。
- 调试及 Release 构建通过；应用签名完整性、安装包内容和校验值已检查。这不等于 Apple 公证。
- 模拟精简 GUI PATH 后，真实 Codex CLI 版本查询和登录状态检测通过。
- 实际云端释义、跨应用划词及真实多屏拖动尚未完成实机验证。
- Google 词典义项依赖接口返回；Apple 离线翻译仍仅给出译文并提示能力限制。模型释义可能有误。
- 内置更新检查仍指向上游。请从 [DongMugua/GPT-Translator Releases](https://github.com/DongMugua/GPT-Translator/releases) 手动更新本增强版。

## 来源与许可证状态

原项目作者为 [fuyao123](https://github.com/fuyao123)，上游基线为 `192f4c4e88a9c8dab00572fc6d1997f48d86cb61`。上游尚未提供主程序的项目级许可证，本 fork 未为其代码另行添加许可证或声称获得额外授权；具体状态见仓库 README。

Google Material Symbols 图标对应的 Apache 2.0 许可证和第三方声明已随应用附带；该许可证仅针对相应素材，不适用于整个应用。


---

# GPT 翻译助手 1.2.5

1.2.5 将 OpenAI/ChatGPT OAuth 翻译源的默认模型切换到 GPT-6 Luna。

## 本次更新

- OpenAI/ChatGPT OAuth 源默认使用 `gpt-6-luna`，继续复用本机 `codex login` 的登录会话。
- 已保存的默认模型或 `gpt-5.6-luna` 会自动迁移到 `gpt-6-luna`；其他自选模型保持原设置。
- 模型设置中可选择 GPT-6 Luna、Sol 和 Astra。

## 安装

下载 `GPT-Translator-1.2.5-macOS.dmg`，打开后将“GPT 翻译助手”拖入 Applications。

当前构建未经过 Apple Developer ID 公证。若 macOS 阻止首次打开，请在 Finder 中右键应用并选择“打开”。Apple 离线翻译需要 macOS 15 或更高版本；其他翻译源仍支持 macOS 13 或更高版本。

使用 OpenAI/ChatGPT OAuth 翻译源前，需要自行安装 Codex CLI 并完成 `codex login`；使用 Gemini/Google OAuth 翻译源前，需要自行安装 Antigravity CLI（`agy`）并完成 Google 登录。应用不会附带 CLI，也不会读取、复制或打包用户的 OAuth Token。

发布包不包含开发者或使用者的 OAuth 登录信息、API Key、钥匙串内容及本机配置。所有使用者需要自行登录或配置翻译服务。

# GPT 翻译助手 1.2.2

1.2.2 主要修复启用划词翻译后，其他应用菜单无法保持展开的问题。

## 产品构想

GPT 翻译助手希望成为一个简洁的翻译软件与截图软件的融合版：将划词翻译、快捷输入、截图标注、OCR 识别和截图翻译放进同一条轻量工作流，减少应用切换，不用在多个工具之间来回复制粘贴。

## 本次更新

- 修复启用划词翻译后，点击其他应用菜单栏时菜单显示后自动消失的问题。
- 菜单交互期间跳过划词翻译的全局鼠标监听和模拟 `⌘C`，不再干扰其他应用。

## 1.2.1 的截图修复

- 普通截图按 `⌘C` 后复制图片并关闭截图编辑窗口，即使鼠标已移出截图区域或焦点切换到其他应用也有效。
- 置顶截图按 `⌘C` 只复制图片，不关闭置顶截图，方便继续查看和重复复制。
- 置顶截图可从图面任意位置自由拖动，并修复拖动时画面抖动。
- 保留置顶截图的 `Esc` 和右上角关闭按钮；普通截图仍可通过 `Esc` 取消或关闭。

## 安装

下载 `GPT-Translator-1.2.2-macOS.dmg`，打开后将“GPT 翻译助手”拖入 Applications。

当前构建未经过 Apple Developer ID 公证。若 macOS 阻止首次打开，请在 Finder 中右键应用并选择“打开”。Apple 离线翻译需要 macOS 15 或更高版本；其他翻译源仍支持 macOS 13 或更高版本。

使用 OpenAI/ChatGPT OAuth 翻译源前，需要自行安装 Codex CLI 并完成 `codex login`；使用 Gemini/Google OAuth 翻译源前，需要自行安装 Antigravity CLI（`agy`）并完成 Google 登录。应用不会附带 CLI，也不会读取、复制或打包用户的 OAuth Token。

发布包不包含开发者或使用者的 OAuth 登录信息、API Key、钥匙串内容及本机配置。所有使用者需要自行登录或配置翻译服务。
