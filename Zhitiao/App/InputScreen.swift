import SwiftUI

struct InputScreen: View {
    @EnvironmentObject private var model: AppModel

    private let samples: [(String, String)] = [
        ("语录", "把时间花在哪里\n你反复刷的内容\n其实是在替别人\n定义你的注意力"),
        ("清单", "- 早上先喝水再看手机\n- 把最难的事放在第一段\n- 晚上十一点手机放客厅\n- 睡前写下明天第一件事"),
        ("提问", "为什么越整理越乱？\n真正有用的整理\n只需要三步\n第一步先定标准\n第二步再动手\n第三步定期复盘")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("正文")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.muted)

                        Text("一行就是卡片上的一行大字。模型只帮你挑强调词和配插画，其余由你决定。")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        TextEditor(text: $model.text)
                            .font(.system(size: 16))
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 170)
                            .background(Theme.bg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.line, lineWidth: 1)
                            )

                        HStack(spacing: 8) {
                            ForEach(samples, id: \.0) { sample in
                                OptionButton(title: sample.0, active: false) {
                                    model.text = sample.1
                                }
                            }
                            Spacer()
                            Text("\(splitLines(model.text, maxChars: 12).count) 行")
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            Task { await model.generate() }
                        } label: {
                            Text(model.isBusy ? "正在分析你的文字…" : "生成卡片")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Theme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .disabled(model.isBusy)
                        .opacity(model.isBusy ? 0.45 : 1)

                        if !model.status.isEmpty {
                            Text(model.status)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
