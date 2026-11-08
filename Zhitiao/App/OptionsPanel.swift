import SwiftUI

/// 每类选项的面板。只放这一类的选项，不再长滚动。
struct OptionsPanel: View {
    @EnvironmentObject private var model: AppModel
    let tab: CardTab

    private var spec: CardSpec {
        model.current?.makeSpec() ?? CardSpec()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch tab {
                case .emoji: emojiTab
                case .background: backgroundTab
                case .align: alignTab
                // 依赖 AI，暂时下线
                // case .element: elementTab
                // case .emphasis: emphasisTab
                // case .illustration: illustrationTab
                case .font: fontTab
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.surface)
    }

    // MARK: - Emoji

    private var emojiTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupLabel(
                title: "Emoji",
                value: spec.emoji.isEmpty ? "不放" : "\(spec.emoji.count) / \(EmojiCatalog.maxSelection)"
            )

            // 已选：点一下取消
            HStack(spacing: 8) {
                Button {
                    model.clearEmoji()
                } label: {
                    Text("不放")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(spec.emoji.isEmpty ? Theme.bg : Theme.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(spec.emoji.isEmpty ? Theme.ink : Theme.bg)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(spec.emoji.isEmpty ? Color.clear : Theme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                ForEach(Array(spec.emoji.enumerated()), id: \.offset) { index, item in
                    Button {
                        model.removeEmoji(at: index)
                    } label: {
                        Text(item)
                            .font(.system(size: 26))
                            .frame(width: 44, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.bg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            Text(
                spec.emoji.count >= EmojiCatalog.maxSelection
                    ? "已经选满 \(EmojiCatalog.maxSelection) 个，点上面的已选项可以取消。重复点同一个可以叠加。"
                    : "最多选 \(EmojiCatalog.maxSelection) 个，可以重复选同一个。会排在正文第一行的上方，字号是正文的 3.5 倍，对齐跟随正文。"
            )
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)

            // 分组横滑
            ForEach(EmojiCatalog.groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(group.name)  \(group.emoji.count)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 2) {
                            ForEach(group.emoji, id: \.self) { item in
                                Button {
                                    model.appendEmoji(item)
                                } label: {
                                    Text(item)
                                        .font(.system(size: 26))
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(spec.emoji.contains(item) ? Theme.wash : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 背景（含配色）

    private var backgroundTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                GroupLabel(title: "背景")
                WrapRow(spacing: 8) {
                    ForEach(BackgroundType.allCases) { item in
                        OptionButton(title: item.name, active: spec.background == item) {
                            model.update { $0.background = item }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                GroupLabel(title: "配色")
                WrapRow(spacing: 8) {
                    ForEach(Array(Palette.seeds.enumerated()), id: \.offset) { entry in
                        Button {
                            model.applyPalette(index: entry.offset)
                        } label: {
                            Circle()
                                .fill(Color(hex: entry.element.bg))
                                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                                .overlay {
                                    if isCurrentPalette(entry.element.bg) {
                                        Circle().stroke(Theme.ink, lineWidth: 2).padding(-3)
                                    }
                                }
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /* AI 相关，暂时下线
    /// 需要时才调模型，不给全局按钮
    private func generateButton(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Task { await model.generate() }
            } label: {
                HStack(spacing: 6) {
                    if model.isBusy {
                        ProgressView().controlSize(.small)
                    }
                    Text(model.isBusy ? "正在分析…" : title)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)

            if !model.status.isEmpty {
                Text(model.status)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    */

    private func isCurrentPalette(_ hex: String) -> Bool {
        spec.palette.bg.hexString.uppercased() == hex.uppercased()
    }

    // MARK: - 对齐

    private var alignTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                GroupLabel(title: "水平")
                WrapRow(spacing: 8) {
                    ForEach(AlignH.allCases) { item in
                        OptionButton(title: item.name, active: spec.align.h == item) {
                            model.update { $0.align.h = item }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                GroupLabel(title: "垂直")
                WrapRow(spacing: 8) {
                    ForEach(AlignV.allCases) { item in
                        OptionButton(title: item.name, active: spec.align.v == item) {
                            model.update { $0.align.v = item }
                        }
                    }
                }
            }
        }
    }

    /*
    // MARK: - 元素

    private var elementTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(title: "元素装饰", value: spec.element.name)
            WrapRow(spacing: 8) {
                ForEach(ElementItem.all) { item in
                    OptionButton(title: item.name, active: spec.element.id == item.id) {
                        model.update { $0.element = item }
                    }
                }
            }
        }
    }

    */

    /*
    // MARK: - 强调

    private var emphasisTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(
                title: "强调样式",
                value: spec.emphasisWords.isEmpty ? "还没有强调词" : spec.emphasisWords.joined(separator: "、")
            )

            if spec.emphasisWords.isEmpty {
                generateButton(title: "让模型挑强调词")
            }

            WrapRow(spacing: 8) {
                ForEach(EmphasisStyle.allCases) { item in
                    OptionButton(title: item.name, active: spec.emphasisStyle == item) {
                        model.update { $0.emphasisStyle = item }
                    }
                }
            }
        }
    }

    */

    /*
    // MARK: - 插画

    private var illustrationTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(title: "插画", value: model.illustrations.isEmpty ? "没有候选" : "AI 生成")

            if model.illustrations.isEmpty {
                generateButton(title: "让模型配插画")
            }

            HStack(spacing: 8) {
                illustrationButton(id: nil, illustration: nil)
                ForEach(model.illustrations) { item in
                    illustrationButton(id: item.id, illustration: item)
                }
            }
        }
    }

    private func illustrationButton(id: String?, illustration: Illustration?) -> some View {
        Button {
            model.selectIllustration(id)
        } label: {
            Group {
                if let illustration {
                    IllustrationThumbnail(illustration: illustration)
                } else {
                    Text("无插画")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 68, height: 68)
            .background(illustration == nil ? Theme.bg : Color(hex: "#F4F1EA"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        (model.current?.makeSpec().illustration?.id == id) ? Theme.ink : Theme.line,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    */

    // MARK: - 字体（含字号）

    /// 字号：四档快捷 + 滑杆微调（字体族暂时固定黑体，不做切换）
    private var fontTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupLabel(title: "字号", value: SizePreset.name(for: spec.fontSize))

            WrapRow(spacing: 8) {
                ForEach(SizePreset.all) { preset in
                    OptionButton(
                        title: preset.name,
                        active: SizePreset.name(for: spec.fontSize) == preset.name
                    ) {
                        model.update { $0.fontSize = preset.size }
                    }
                }
            }

            Slider(
                value: Binding(
                    get: { spec.fontSize },
                    set: { value in model.update { $0.fontSize = value } }
                ),
                in: SizePreset.range,
                step: 2
            )
            .tint(Theme.accent)

            Text("字放大后放不下的行会折行，卡片高度跟着变长。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
    }
}

/// 字号档位：界面上只显示名字，不显示数字
enum SizePreset: String, CaseIterable, Identifiable {
    case xsmall, small, medium, large

    var id: String { rawValue }

    var name: String {
        switch self {
        case .xsmall: return "较小"
        case .small: return "小"
        case .medium: return "中"
        case .large: return "大"
        }
    }

    var size: CGFloat {
        switch self {
        case .xsmall: return 40
        case .small: return 50
        case .medium: return 60
        case .large: return 80
        }
    }

    /// 滑杆可调的范围
    static let range: ClosedRange<CGFloat> = 24...140

    static var all: [SizePreset] { allCases }

    /// 当前字号落在哪一档（相邻档位取中点作为分界）
    static func name(for size: CGFloat) -> String {
        let sorted = allCases.sorted { $0.size < $1.size }
        if size <= sorted[0].size + 5 { return sorted[0].name }
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let current = sorted[index]
            if size < (previous.size + current.size) / 2 { return previous.name }
        }
        return sorted[sorted.count - 1].name
    }
}
