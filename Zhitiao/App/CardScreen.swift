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
            if model.isEditing { focusEditor() }
        }
        .onChange(of: model.isEditing) { _, editing in
            if editing { focusEditor() }
        }
        .fullScreenCover(isPresented: $model.showFullPreview) {
            FullPreview(image: model.exportPreview())
        }
    }

    private func charCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines).joined().count
    }

    private func focusEditor() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            editorFocused = true
        }
    }

    // MARK: - 选项模式

    private var stage: some View {
        VStack(spacing: 12) {
            Button {
                model.beginEditing()
            } label: {
                Group {
                    if let preview = model.preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 330)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.bg)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .frame(maxHeight: 330)
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

    // MARK: - 编辑模式

    private var peekStrip: some View {
        Button {
            model.showFullPreview = true
        } label: {
            HStack(spacing: 12) {
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

                HStack(spacing: 3) {
                    Text("看大图")
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            HStack {
                Text("正文")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("\(splitLines(text, maxChars: 12).count) 行 · \(charCount(text)) 字")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }

            TextEditor(text: Binding(get: { model.current?.text ?? "" }, set: { model.updateText($0) }))
                .focused($editorFocused)
                .font(.system(size: 17))
                .lineSpacing(15)
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
