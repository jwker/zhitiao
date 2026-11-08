import SwiftUI

struct CardScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var showShare = false
    @State private var shareImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 预览
                VStack(spacing: 12) {
                    if let image = model.rendered {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(color: .black.opacity(0.10), radius: 12, y: 6)
                    }

                    HStack(spacing: 8) {
                        Button {
                            shareImage = model.exportImage()
                            showShare = true
                        } label: {
                            Text("下载 PNG")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        Button {
                            model.screen = .input
                            model.saveNow()
                        } label: {
                            Text("改文字")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.bg)
                                .foregroundStyle(Theme.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Theme.line, lineWidth: 1)
                                )
                        }
                    }
                }

                options
            }
            .padding(16)
        }
        .sheet(isPresented: $showShare) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    private var options: some View {
        VStack(spacing: 12) {
            // 背景
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel(title: "背景")
                    WrapRow(spacing: 8) {
                        ForEach(BackgroundType.allCases) { item in
                            OptionButton(
                                title: item.name,
                                active: model.spec.background == item
                            ) {
                                model.update { $0.background = item }
                            }
                        }
                    }
                }
            }

            // 对齐
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel(title: "对齐")
                    WrapRow(spacing: 8) {
                        ForEach(AlignH.allCases) { item in
                            OptionButton(title: item.name, active: model.spec.align.h == item) {
                                model.update { $0.align = (item, model.spec.align.v) }
                            }
                        }
                    }
                    WrapRow(spacing: 8) {
                        ForEach(AlignV.allCases) { item in
                            OptionButton(title: item.name, active: model.spec.align.v == item) {
                                model.update { $0.align = (model.spec.align.h, item) }
                            }
                        }
                    }
                }
            }

            // 元素
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel(title: "元素")
                    WrapRow(spacing: 8) {
                        ForEach(ElementItem.all) { item in
                            OptionButton(title: item.name, active: model.spec.element.id == item.id) {
                                model.update { $0.element = item }
                            }
                        }
                    }
                }
            }

            // 强调样式
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel(
                        title: "强调样式",
                        value: model.spec.emphasisWords.isEmpty
                            ? "AI 没挑出强调词"
                            : model.spec.emphasisWords.joined(separator: "、")
                    )
                    if !model.spec.emphasisWords.isEmpty {
                        WrapRow(spacing: 8) {
                            ForEach(EmphasisStyle.allCases) { item in
                                OptionButton(title: item.name, active: model.spec.emphasisStyle == item) {
                                    model.update { $0.emphasisStyle = item }
                                }
                            }
                        }
                    }
                }
            }

            // 插画
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel(title: "插画", value: model.illustrations.isEmpty ? "没有候选" : "AI 生成")
                    if model.illustrations.isEmpty {
                        Text("AI 没有给出可画的插画，可以在正文里提一个具体的东西再试一次。")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    } else {
                        HStack(spacing: 8) {
                            illustrationButton(id: nil, title: "无插画")
                            ForEach(model.illustrations) { item in
                                illustrationButton(id: item.id, title: nil, illustration: item)
                            }
                        }
                    }
                }
            }

            // 配色
            Panel {
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
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // 字号与字体
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel(title: "字号", value: "\(Int(model.spec.maxSize))px")
                    Slider(
                        value: Binding(
                            get: { model.spec.maxSize },
                            set: { value in model.update { $0.maxSize = value } }
                        ),
                        in: 90...240,
                        step: 4
                    )
                    Text("这是字号上限，实际字号会按内容多少自动往下收。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)

                    Divider().overlay(Theme.line)

                    GroupLabel(title: "字体")
                    WrapRow(spacing: 8) {
                        ForEach(FontFamily.allCases) { item in
                            OptionButton(title: item.name, active: model.spec.font == item) {
                                model.update { $0.font = item }
                            }
                        }
                    }
                }
            }
        }
    }

    private func illustrationButton(id: String?, title: String?, illustration: Illustration? = nil) -> some View {
        Button {
            model.selectIllustration(id)
        } label: {
            Group {
                if let title {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 76, height: 76)
                } else if let illustration {
                    IllustrationThumbnail(illustration: illustration)
                        .frame(width: 76, height: 76)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(model.spec.illustration?.id == id ? Theme.ink : Theme.line, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 插画候选缩略图
struct IllustrationThumbnail: View {
    let illustration: Illustration

    var body: some View {
        ZStack {
            Color(hex: "#F4F1EA")
            if let image = illustration.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(uiImage: DoodleThumbnail.image(for: illustration.fallbackId))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            }
        }
    }
}
