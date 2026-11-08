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
                case .background: backgroundTab
                case .align: alignTab
                case .element: elementTab
                case .emphasis: emphasisTab
                case .illustration: illustrationTab
                case .font: fontTab
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.surface)
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

    // MARK: - 字体（含字号）

    private var fontTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                GroupLabel(title: "字体")
                WrapRow(spacing: 8) {
                    ForEach(FontFamily.allCases) { item in
                        OptionButton(title: item.name, active: spec.font == item) {
                            model.update { $0.font = item }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                GroupLabel(title: "字号", value: "\(Int(spec.fontSize))px")
                Slider(
                    value: Binding(
                        get: { spec.fontSize },
                        set: { value in model.update { $0.fontSize = value } }
                    ),
                    in: 24...140,
                    step: 2
                )
                .tint(Theme.accent)

                HStack {
                    Text("小").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Spacer()
                    Text("大").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }

                Text("字放大后放不下的行会折行，卡片高度跟着变长。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}
