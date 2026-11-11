import SwiftUI

/// 卡片页。
///
/// 两种形态：
///   选项模式 —— 上方卡片预览（点卡片进入编辑）+ 底部 tab + 选项面板
///   编辑模式 —— 顶部一条迷你预览 + 全宽编辑区（跟键盘）
struct CardScreen: View {
    @EnvironmentObject private var model: AppModel

    @State private var tab: CardTab = CardScreen.initialTab
    @FocusState private var editorFocused: Bool

    /// 调试用：--tab=element 直接切到某一类选项
    static var initialTab: CardTab {
        for argument in ProcessInfo.processInfo.arguments where argument.hasPrefix("--tab=") {
            let value = argument.replacingOccurrences(of: "--tab=", with: "")
            if let tab = CardTab(rawValue: value) { return tab }
        }
        return .background
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isEditing {
                peekStrip
                editor
            } else {
                stage
                CardTabBar(selection: $tab)
                OptionsPanel(tab: tab)
            }
        }
        .background(Theme.surface)
        .onAppear {
            // 调试用：--focus 打开就聚焦，方便截图键盘相关界面
            guard ProcessInfo.processInfo.arguments.contains("--focus") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                editorFocused = true
            }
        }
        .fullScreenCover(isPresented: $model.showFullPreview) {
            FullPreview(image: model.exportPreview())
        }
    }

    /// 复制正文全文到剪贴板
    private func copyText() {
        let value = model.current?.text ?? ""
        guard !value.isEmpty else {
            model.showToast("没有可复制的文字")
            return
        }
        UIPasteboard.general.string = value
        model.showToast("已复制")
    }

    private func charCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines).joined().count
    }

    // MARK: - 选项模式

    /// 舞台高度：卡片再长也只占这么高，超出就滚动。
    /// Emoji 面板要放分组 tab 和多列网格，卡片缩一档，把高度让给下面的选择器。
    private var stageHeight: CGFloat {
        tab == .emoji ? 260 : 380
    }

    private var stage: some View {
        VStack(spacing: 12) {
            Button {
                model.beginEditing()
            } label: {
                Group {
                    if let preview = model.preview {
                        cardView(preview)
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.bg)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .frame(height: stageHeight)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(model.isBusy ? "正在分析你的文字…" : (model.status.isEmpty ? "点卡片编辑文字" : model.status))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    /// 卡片显示规则：
    ///   不超过 3:4 的卡片 —— 按高度缩放，整张都能看到
    ///   比 3:4 更长的卡片 —— 按屏幕宽度显示，上下滚动着看，不缩小
    @ViewBuilder
    private func cardView(_ image: UIImage) -> some View {
        let ratio = image.size.height / max(image.size.width, 1)
        let isTall = ratio > 4.0 / 3.0 + 0.01

        if isTall {
            ScrollView(.vertical, showsIndicators: true) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    .padding(.vertical, 2)
            }
            .frame(height: stageHeight)
            .padding(.horizontal, 16)
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: stageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
    }

    // MARK: - 编辑模式

    private var peekStrip: some View {
        HStack(spacing: 12) {
            // 点迷你预览看大图
            Button {
                model.showFullPreview = true
            } label: {
                Group {
                    if let peek = model.peek {
                        // 长卡片只露上面 3:4 那一段，缩略图尺寸保持稳定
                        Image(uiImage: peek)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 63, height: 84)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.bg)
                            .frame(width: 63, height: 84)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("看大图")

            VStack(alignment: .leading, spacing: 3) {
                Text("实时预览")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                Text(model.styleSummary)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // 结束编辑，进卡片选项页
            Button {
                model.endEditing()
            } label: {
                HStack(spacing: 3) {
                    Text("卡片")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.vertical, 8)
                .padding(.leading, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("卡片设置")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    /// 当前纸条的正文：编辑框直接读写它，避免和本地 state 不同步
    private var text: String {
        model.current?.text ?? ""
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("正文")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)

                Spacer()

                // 复制正文全文
                Button {
                    copyText()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("复制文字")

                // 收起键盘：只在键盘弹起时才有意义
                if editorFocused {
                    Button {
                        editorFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Theme.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("收起键盘")
                }

                Text("\(model.currentLayoutLineCount) 行 · \(charCount(text)) 字")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            TextEditor(text: Binding(get: { model.current?.text ?? "" }, set: { model.updateText($0) }))
                .focused($editorFocused)
                .font(.system(size: 17))
                .lineSpacing(15)
                .scrollDismissesKeyboard(.interactively)
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .frame(maxHeight: .infinity)
    }
}
