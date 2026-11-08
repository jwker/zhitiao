# 纸条 · Zhitiao

把文字做成一张排版精美的图片卡片。原生 iOS 应用，SwiftUI + Core Graphics，没有 WebView。

同一份产品的 H5 原型在仓库上一级的 `text-card-studio/`；这一份是原生重写。

## 它做什么

输入一段文字，程序按「一行 = 一行大字」切行，用双向约束算字号，排成一张 1080×1440 的卡片，导出成图片。

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

**输入页**：写文字，一行就是卡片上的一行大字。三个示例可以直接试。

**卡片页**：预览 + 「下载 PNG」（2160×2880）+ 选项面板：

| 选项 | 取值 |
| --- | --- |
| 背景 | 纯色 / 渐变 / 网格 / 横线稿纸 / 点阵 / 光束 / 颗粒纸感 / 斜纹 |
| 对齐 | 水平（左 / 中 / 右）× 垂直（上 / 中 / 下） |
| 元素 | 20 个固定装饰（引号、破折号、星号、箭头、胶带、印章、圈选、手绘箭头…） |
| 强调样式 | 无强调 / 荧光笔 / 色块 / 变色 / 下划线 / 波浪线 |
| 插画 | 无插画，或从 AI 给出的候选里挑一张 |
| 配色 | 8 套配色盘 |
| 字号 | 90–240px 上限滑杆 |
| 字体 | 黑体 / 宋体 / 楷体 |

**设置**：模型接口地址、Key、模型名，以及调试模式（不联网，用本地规则）。

## 模型

OpenAI 兼容格式，默认指向阿里云百炼的 `/compatible-mode/v1`。模型返回：

```json
{
  "emphasis": ["注意力"],
  "illustrationSubjects": ["a small potted plant", "an open book"]
}
```

校验规则：强调词必须在原文里连续出现（否则丢掉），插画主体最多 5 个。模型挂了或没配 Key，自动退回本地规则，卡片照样出。

**调试模式默认开着**，所以不配 Key 也能跑通全流程。

## 数据

- 正文用 `NSUbiquitousKeyValueStore` 同步，iCloud 不可用时自动退回本地存储。
- 卡片参数和模型配置存在本机 `UserDefaults`。
- Key 只在本机，不上传。

## 目录

```
Zhitiao/
├─ App/            界面：ContentView、InputScreen、CardScreen、SettingsSheet、WrapRow
├─ Core/           排版引擎：Renderer、Drawing（背景/元素/强调）、Illustrations（18 个简笔画）、CardSpec
├─ AI/             AIClient（只挑强调词和插画主体）、IllustrationGenerator（图像模型，可选）
├─ Store/          AppModel（状态）、DocumentStore（iCloud）、CardSnapshot（可存储快照）
└─ Resources/
.ai/               AI 产物（不进版本库，见 .ai/README.md）
```

引擎不依赖 SwiftUI，纯 Core Graphics，方便单独测。

## 排版算法

1. 切行：按换行切，去掉 `#` `-` `>` 标记；超过 12 字在标点处再断。
2. 字号：宽度约束（最长行不超过可用宽度的 94%）与高度约束（整块不超过内容高度的 72%）取小者，且不超过滑杆设的上限。
3. 行距：文字块比卡片矮时把行距撑开，最多 1.9 倍。
4. 定位：水平三档、垂直三档；左对齐且有开头符号时先扣掉符号占位。
5. 绘制顺序：背景 → 元素装饰 → 强调装饰 → 文字 → 插画（自动避开文字块）。

## 已知限制

- 长文不会自动拆成多张卡片。
- 插画默认用内置 18 个简笔画；接图像模型需要另外配置，且图片要经代理取回才能导出。
- 楷体在部分系统上会回落到宋体。
- 没有 App 图标和启动图。

## 调试

```bash
# 用示例文字生成一张卡，并把 PNG 写到 App 的 Documents
xcrun simctl launch booted com.zhitiao.app --demo --dump

# 检查 18 个内置简笔画的风格是否一致
xcrun simctl launch booted com.zhitiao.app --dump-icons

# 指定图层组合验证，例如网格背景 + 左对齐 + 上对齐 + 「」 + 波浪线
xcrun simctl launch booted com.zhitiao.app --demo --dump --variant=grid,left,top,quote-both,wave
```
