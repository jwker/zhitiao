# 纸条 · Zhitiao

把文字做成一张排版精美的图片卡片。原生 iOS 应用，SwiftUI + Core Graphics，没有 WebView。

同一份产品的 H5 原型在同级的 `../zhitiao-h5/`；这一份是原生重写。

## 它做什么

输入一段文字，程序按「一行 = 一行大字」切行，排成一张卡片，导出成图片。

**画幅**：宽度固定 1080，默认 3:4（1080×1440）。文字放不下时**卡片自动变高**，没有上限——长文就是一张长图。

模型只做两件事：**从原文里挑强调词**、**给出 3–5 个插画主体**。背景、对齐、元素装饰、强调样式、字体、字号这些全部是程序提供的素材库，由用户在页面上选。

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

## 用起来

**首页**：纸条列表。每行显示正文第一行 + 后面两行，右侧是相对时间（今天 / 昨天 / 11月6日）。点一行进卡片页，右上角 ＋ 新建。

**卡片页 · 选项模式**：上方是卡片预览（点它进入编辑），底部 6 个 tab 切换选项，不再是长滚动。

预览的显示规则：不超过 3:4 的卡片按高度整张显示；比 3:4 更长的卡片按屏幕宽度显示，上下滚动着看，**不缩小**。

预览按 1.2 倍渲染（1296px 宽），对齐屏幕像素密度，所以和导出的 2 倍图一样清晰。

| tab | 里面有什么 |
| --- | --- |
| 背景 | 8 种底纹 + 8 套配色 |
| 对齐 | 水平（左 / 中 / 右）、垂直（上 / 中 / 下） |
| 元素 | 20 个固定装饰（引号、破折号、星号、箭头、胶带、印章、圈选、手绘箭头…） |
| 强调 | 6 种样式；没有强调词时这里可以让模型挑 |
| 插画 | 无插画，或从模型给的候选里挑一张；没有候选时这里可以让模型配 |
| 字体 | 黑体 / 宋体 / 楷体，字号滑杆 24–140px（直接是字号，不是上限） |

右上角「导出」出 2160×2880 的图片，走系统分享面板。

**卡片页 · 编辑模式**：点卡片进入。上方缩成一条 63×84 的迷你预览（旁边写当前样式：纯色 · 居中 · 荧光笔），编辑区拿到全宽和剩余高度（17px / 1.9 行高，一屏 9–10 行）。每敲一个字迷你预览即时重排。点「看大图」进全屏预览，点任意处返回。右上角「完成」收起键盘。

## 配置模型

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

**区别**：`.env` 是构建期常量，改完要重启 dev server；App 里是运行期可改，存 `UserDefaults`，不进代码库、不进 iCloud，也不随安装包分发。

模型只做两件事：挑强调词、给插画主体。返回：

```json
{
  "emphasis": ["注意力"],
  "illustrationSubjects": ["a small potted plant", "an open book"]
}
```

校验规则：强调词必须在原文里连续出现（否则丢掉），插画主体最多 5 个。模型挂了或没配 Key，自动退回本地规则，卡片照样出。

## 数据

- 纸条列表用 `NSUbiquitousKeyValueStore` 同步（整份列表是一段 JSON），iCloud 不可用时自动退回 `UserDefaults`。
- 每张纸条带自己的卡片设置（背景、对齐、元素、强调样式、字体、配色）。
- 老版本只存了一条正文，启动时会自动搬成第一条纸条。
- 空纸条不会被保存（退出时删掉）。
- Key 只在本机，不上传。

## 目录

```
Zhitiao/
├─ App/            界面：ContentView、ListView、CardScreen、CardTabBar、OptionsPanel、FullPreview、Controls、SettingsSheet、WrapRow
├─ Core/           排版引擎：Renderer、Drawing（背景/元素/强调）、Illustrations（18 个简笔画）、CardSpec、Document、TextSplit
├─ AI/             AIClient（只挑强调词和插画主体）、IllustrationGenerator（图像模型，可选）
├─ Store/          AppModel（状态）、DocumentStore（iCloud）、CardSnapshot（可存储快照）
design/            改版设计稿（HTML，浏览器打开）
.ai/               AI 产物（不进版本库，见 .ai/README.md）
```

引擎不依赖 SwiftUI，纯 Core Graphics，方便单独测。

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
- 列表不支持删除（暂定）。
- 插画默认用内置 18 个简笔画；接图像模型需要另外配置，且图片要经代理取回才能导出。
- 楷体在部分系统上会回落到宋体。
- 没有 App 图标和启动图。

## 调试

```bash
# 直接打开示例纸条的卡片页（选项模式）
xcrun simctl launch booted com.zhitiao.app --demo

# 打开就进编辑模式 / 打开就进全屏预览 / 跑一次模型分析
xcrun simctl launch booted com.zhitiao.app --demo --edit
xcrun simctl launch booted com.zhitiao.app --demo --preview
xcrun simctl launch booted com.zhitiao.app --demo --generate

# 直接切到某一类选项，例如插画
xcrun simctl launch booted com.zhitiao.app --demo --generate --tab=illustration

# 打开设置页 / 自动点一次导出
xcrun simctl launch booted com.zhitiao.app --settings
xcrun simctl launch booted com.zhitiao.app --demo --export

# 清空全部数据（列表、配置）
xcrun simctl launch booted com.zhitiao.app --reset

# 检查 18 个内置简笔画的风格是否一致
xcrun simctl launch booted com.zhitiao.app --dump-icons
```

调试参数默认不写存储，用来截图和回归，不会污染真实数据。想验证持久化时加 `--persist`：

```bash
# 模拟「点 ＋ → 输入 → 完成」，并真的存下来
xcrun simctl launch booted com.zhitiao.app --new "--type=第一行\n第二行" --end --persist
xcrun simctl launch booted com.zhitiao.app   # 再正常启动，列表里应该有这一条
```
