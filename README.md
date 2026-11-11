# 纸条儿 · Zhitiao

把文字做成一张排版精美的图片卡片。原生 iOS 应用，SwiftUI + Core Graphics，没有 WebView。

同一份产品的 H5 原型在同级的 `../zhitiao-h5/`；这一份是原生重写。

## 它做什么

输入一段文字，程序按「一行 = 一行大字」切行，排成一张卡片，导出成图片。

**画幅**：宽度固定 1080，默认 3:4（1080×1440）。文字放不下时**卡片自动变高**，没有上限——长文就是一张长图。

**Emoji**：卡片顶部单独一行，字号是**正文的 3.5 倍**（字号很大且 emoji 多时会自动收窄，避免超出卡宽），对齐跟随「对齐」tab，与正文的间距是 emoji 尺寸的 0.34 倍（emoji 越大空隙越松）。
可选 0–5 个，**允许重复选同一个**（点几次就叠几个），上限由 `EmojiCatalog.maxSelection` 控制。列表是运行时枚举出来的——iOS 没有「全部 emoji」的公开 API，
所以扫描 Unicode 码点后用「CoreText 是否真用 Apple Color Emoji 渲染」来验证；iOS 26.5 上得到 1178 个，分 9 组。
组合 emoji（👨‍👩‍👧‍👦 这类 ZWJ 序列）单个码点扫不到，本版本不提供。

**当前版本暂时下线了 AI**：元素装饰、强调、插画三块（它们都依赖模型输出）已从界面和卡片渲染里注释掉，代码保留，随时可以恢复。
现在卡片只有文字 + 背景 + 对齐 + 字号，全部在本地完成，不联网。

## 跑起来

```bash
open Zhitiao.xcodeproj
# 选一台模拟器，⌘R
```

命令行构建：

```bash
xcodebuild -project Zhitiao.xcodeproj -scheme Zhitiao \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build build
```

要求 iOS 17+，Xcode 27。

工程开了 iCloud（CloudKit）能力，容器是 `iCloud.com.jiangweiku.zhitiao`。
第一次换机器构建前，先在 Xcode → Settings → Accounts 登录付费开发者账号，
让 Xcode 自动把容器注册到开发者后台；没登录时构建会在签名这一步失败。

## 用起来

**首页**：纸条列表。每行显示正文第一行 + 后面两行，右侧是相对时间（今天 / 昨天 / 11月6日）。点一行直接进文字编辑页，左滑一行删除，右上角 ＋ 新建。有未处理的同步冲突时，列表顶部会出现一条提示，点开逐条选「保留本机 / 保留其他设备 / 两个都留」。

**文字编辑页**：顶部一条 63×84 的迷你预览 + 当前样式摘要 + 「卡片 ›」。点迷你预览看大图（点任意处返回），点「卡片 ›」收起编辑、进入卡片选项页。编辑区拿到全宽和剩余高度（17px / 1.9 行高，一屏 9–10 行），每敲一个字迷你预览即时重排。默认不聚焦，点正文才弹键盘；「正文」那一行右侧有复制按钮（把正文全文放进剪贴板，弹「已复制」提示），一直显示。键盘弹起时它左边多一个收起键盘的图标，点它只收键盘、不离开编辑页。拖动正文也能收起。

**卡片页 · 选项模式**：从「完成」进入。上方是卡片预览（点它回到编辑），底部 tab 切换选项，不再是长滚动。左上角返回回到文字编辑页。

预览的显示规则：不超过 3:4 的卡片按高度整张显示；比 3:4 更长的卡片按屏幕宽度显示，上下滚动着看，**不缩小**。

预览按 1.2 倍渲染（1296px 宽），对齐屏幕像素密度，所以和导出的 2 倍图一样清晰。

| tab | 里面有什么 |
| --- | --- |
| Emoji | 从分组列表里选 0–5 个，排在正文第一行上方，字号和对齐跟随正文 |
| 背景 | 8 种底纹 + 8 套配色 |
| 对齐 | 水平（左 / 中 / 右）、垂直（上 / 中 / 下） |
| 字号 | 四档快捷（较小 40 / 小 50 / 中 60 / 大 80）+ 24–140px 滑杆，界面上只显示档位名 |

右上角「导出」出 2160×2880 的图片，走系统分享面板。



## 配置模型（已下线）

> AI 相关功能当前已注释掉，设置页只显示版本号。下面这段保留，恢复时按 `.ai/notes/` 里的说明操作。

**原生 App 不读 `.env`。** H5 版靠 Vite 在构建期把 `MODEL_BASE_URL` / `MODEL_API_KEY` / `MODEL_NAME` 注入进去，iOS 没有这一层，改成在 App 里填、存在设备上。

入口：**首页右上角齿轮** → 设置。

| 段落 | 字段 | 说明 |
| --- | --- | --- |
| 调试模式 | 开关 | 打开时不发请求，强调词和插画由本地规则给。默认开，所以不配 Key 也能跑通全流程 |
| 文本模型 | 请求地址 / 模型名称 / API Key | OpenAI 兼容格式。默认 `https://dashscope.aliyuncs.com/compatible-mode/v1` + `qwen-plus` |
| 插画模型（可留空） | 请求地址 / 模型名称 / API Key | 默认 `https://dashscope.aliyuncs.com/api/v1` + `wan2.7-image`。填了 Key 才会真的画插画，留空就用内置 18 个简笔画 |
| 测试 | 测试连接 | 关掉调试模式后可用，返回强调词和插画主体的数量，或者错误信息 |

和 `.env` 对照：

| H5 的 `.env.local` | iOS 设置页 |
| --- | --- |
| `MODEL_BASE_URL` | 文本模型 → 请求地址 |
| `MODEL_API_KEY` | 文本模型 → API Key |
| `MODEL_NAME` | 文本模型 → 模型名称 |
| `MODEL_MOCK` | 调试模式开关（`true` = 打开） |
| `MODEL_IMAGE_*` | 插画模型三个字段 |

**区别**：`.env` 是构建期常量，改完要重启 dev server；App 里是运行期可改，存 `UserDefaults`，不进代码库，也不随安装包分发。

模型只做两件事：挑强调词、给插画主体。返回：

```json
{
  "emphasis": ["注意力"],
  "illustrationSubjects": ["a small potted plant", "an open book"]
}
```

校验规则：强调词必须在原文里连续出现（否则丢掉），插画主体最多 5 个。模型挂了或没配 Key，自动退回本地规则，卡片照样出。

## 数据

- 纸条列表存在 `Application Support/Zhitiao/documents.json`，整份列表一个文件，写入用原子写，带一个格式版本号。**删掉 App 数据就没了。**
- 每条记录外面包了一层 `SyncedDocument`：里面是纸条本身，外面是同步元数据（墓碑时间、CloudKit 变更标签、同步基线、有没有未上传的改动）。变更标签和基线要等同步引擎接上才会写。
- 删除：已经同步过的纸条留一条带 `deletedAt` 的墓碑（否则另一台设备拉增量时看不到删除，会把记录推回来）；从没同步过的直接移除。
- 纸条通过 CloudKit 私有数据库同步，登录同一 Apple ID 的设备自动保持一致。API Key 不同步。
- 合并规则：正文和样式分开比。样式冲突取较新的；正文两边都改过才进冲突队列，默认先把本机版本传上去，等用户处理。
- 冲突在列表页顶部提示，点开逐条处理：保留本机、保留其他设备、两个都留。删除冲突只有「保留本机」和「接受删除」两个选择。
- 设置页有 App 内同步开关。关掉后不联网、数据只留本机；再打开会做一次对账。系统层面的 iCloud 开关关着时，这个开关不可用。
- 同步触发：本地改完 2 秒、启动、回到前台、CloudKit 静默推送、系统后台刷新（时间不保证）。
- 删除留 30 天墓碑，之后连服务端记录一起删掉。
- 每张纸条带自己的卡片设置（背景、对齐、元素、强调样式、字体、配色）。
- 空纸条不会被保存（退出时删掉）。
- Key 只在本机，不上传。

## 目录

```
Info.plist        构建用的 Info.plist：后台任务标识、静默推送需要的后台模式
Zhitiao/
├─ App/            界面：ContentView、ListView、CardScreen、CardTabBar、OptionsPanel、FullPreview、Controls、SettingsSheet、ConflictSheet、WrapRow；AppDelegate、BackgroundSync
├─ Core/           排版引擎：Renderer、Drawing（背景/元素/强调）、Illustrations（18 个简笔画）、CardSpec、Document、TextSplit
├─ AI/             AIClient（只挑强调词和插画主体）、IllustrationGenerator（图像模型，可选）
├─ Store/          AppModel（状态）、DocumentStore（文件存储）、SyncedDocument（纸条 + 同步元数据）、CardSnapshot（可存储快照）
├─ Sync/           CloudKit 配置、账号状态、同步引擎、三方合并、冲突队列
├─ PrivacyInfo.xcprivacy   隐私清单（UserDefaults 的 required reason）
.ai/               AI 产物与设计稿（不进版本库，见 .ai/README.md）
```

引擎不依赖 SwiftUI，纯 Core Graphics，方便单独测。

## App 图标

图标是 1024×1024 的单张 PNG，铺在 `Zhitiao/Assets.xcassets/AppIcon.appiconset/icon-1024.png`：满版橙色 `#E04B00` + 白色黑体「纸」。
iOS 自己套圆角遮罩，所以图里不画圆角。

图是用 `.ai/design/make-app-icon.swift` 生成的。这个脚本放在 `.ai/` 里，跟设计稿一样不进版本库，只在本机有。
字形用 `PingFang SC Semibold`——和卡片渲染里「黑体」用的是同一款字（`PingFangSC-Semibold`）：

```bash
swift .ai/design/make-app-icon.swift "PingFang SC Semibold" \
  Zhitiao/Assets.xcassets/AppIcon.appiconset/icon-1024.png
```

脚本的第一个参数也可以写字体文件路径（`.ttf` / `.ttc`），用来换别的字形。换字或改配色改脚本里的常量再重跑。

## 排版算法

1. 切行：只按换行切，去掉 `#` `-` `>` 标记。**不按字数硬断**——折行完全由字号和卡片宽度决定。
2. 折行：按用户选的字号逐字累加，一行放不下就折到下一行，**标点不落行首**（放不下就把上一个字一起带下去）。
3. 高度：`max(1440, 上边距 + 文字块 + 下边距)`。内容少就保持 3:4，内容多就长高。
4. 行距：内容少时把行距撑开到最多 1.9 倍，让短句在 3:4 的卡上也站得住。
5. 定位：水平三档、垂直三档；左对齐且有开头符号时先扣掉符号占位。
6. 绘制顺序：背景 → 元素装饰 → 强调装饰 → 文字 → 插画。
7. 插画落位：从小到大试 5 档尺寸，找第一个不压住任何一行文字的角落；都被占就用最小尺寸放到重叠面积最小的角——宁可小也不能没有。

字号是绝对值，不再有「上限」这一层：用户调多少就是多少，放不下靠折行和加高解决，不靠缩小字号。

## 已知限制

- 长文不会自动拆成多张卡片：全部排在一张上，卡片会很长。
- 静默推送和后台刷新都由系统调度，不保证实时；前台同步和手动同步才是主路径。
- 生产环境的 CloudKit schema 要手动部署，没部署前 TestFlight 包写入会失败。
- 列表不支持删除（暂定）。
- 插画默认用内置 18 个简笔画；接图像模型需要另外配置，且图片要经代理取回才能导出。
- 楷体在部分系统上会回落到宋体。
- 没有自定义启动图：用的是系统生成的默认启动屏。

## 调试

```bash
# 直接打开示例纸条的卡片页（选项模式）
xcrun simctl launch booted com.jiangweiku.zhitiao --demo

# 打开就进编辑模式 / 打开就进全屏预览 / 打开就聚焦（截图键盘用）
xcrun simctl launch booted com.jiangweiku.zhitiao --demo --edit
xcrun simctl launch booted com.jiangweiku.zhitiao --open --focus
xcrun simctl launch booted com.jiangweiku.zhitiao --demo --preview
xcrun simctl launch booted com.jiangweiku.zhitiao --demo --generate

# 直接切到某一类选项，例如插画
xcrun simctl launch booted com.jiangweiku.zhitiao --demo --generate --tab=illustration

# 打开设置页 / 自动点一次导出
xcrun simctl launch booted com.jiangweiku.zhitiao --settings
xcrun simctl launch booted com.jiangweiku.zhitiao --demo --export

# 清空全部数据（列表、配置）
xcrun simctl launch booted com.jiangweiku.zhitiao --reset

# 查看存储状态（含墓碑）
xcrun simctl launch booted com.jiangweiku.zhitiao --dump-store

# 立刻同步一次 / 只写同步状态
xcrun simctl launch booted com.jiangweiku.zhitiao --sync-now
xcrun simctl launch booted com.jiangweiku.zhitiao --sync-dump

# 清游标和冲突（不动纸条）
xcrun simctl launch booted com.jiangweiku.zhitiao --sync-reset

# 合并逻辑自检 / 冲突队列快照
xcrun simctl launch booted com.jiangweiku.zhitiao --merge-selftest
xcrun simctl launch booted com.jiangweiku.zhitiao --dump-conflicts

# 制造一次真实冲突 / 删除冲突（会改服务端记录，只用于开发）
xcrun simctl launch booted com.jiangweiku.zhitiao --simulate-conflict --persist
xcrun simctl launch booted com.jiangweiku.zhitiao --simulate-delete-conflict --persist

# 打开冲突处理页 / 处理第一条冲突
xcrun simctl launch booted com.jiangweiku.zhitiao --show-conflicts
xcrun simctl launch booted com.jiangweiku.zhitiao --resolve=keepLocal --persist
xcrun simctl launch booted com.jiangweiku.zhitiao --resolve=keepServer --persist
xcrun simctl launch booted com.jiangweiku.zhitiao --resolve=keepBoth --persist

# 关掉 / 打开 App 内同步开关
xcrun simctl launch booted com.jiangweiku.zhitiao --sync-off
xcrun simctl launch booted com.jiangweiku.zhitiao --sync-on

# 删掉第一条。加 --persist 才会真的写盘
xcrun simctl launch booted com.jiangweiku.zhitiao --delete-first --persist

# 把第一条当成「已同步」再删，验证墓碑路径
xcrun simctl launch booted com.jiangweiku.zhitiao --simulate-synced --delete-first --persist

# 查一次 iCloud 账号状态 / 再跑一次容器读写自检
# 结果同时写到 App 的 Documents/icloud-status.txt
xcrun simctl launch booted com.jiangweiku.zhitiao --icloud-status
xcrun simctl launch booted com.jiangweiku.zhitiao --icloud-probe

# 检查 18 个内置简笔画的风格是否一致
xcrun simctl launch booted com.jiangweiku.zhitiao --dump-icons
```

调试参数默认不写存储，用来截图和回归，不会污染真实数据。想验证持久化时加 `--persist`：

```bash
# 模拟「点 ＋ → 输入 → 完成」，并真的存下来
xcrun simctl launch booted com.jiangweiku.zhitiao --new "--type=第一行\n第二行" --end --persist
xcrun simctl launch booted com.jiangweiku.zhitiao   # 再正常启动，列表里应该有这一条
```
