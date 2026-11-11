import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("--settings")
    /// 用 item 触发弹出：保证 sheet 拿到图，而不是"先弹空页、再传值"
    @State private var sharePayload: SharePayload?
    /// 分享面板里点了某个动作并完成，等面板关掉后再弹提示
    @State private var exportCompleted = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                switch model.screen {
                case .list:
                    ListView()
                case .card:
                    CardScreen()
                }
            }
        }
        .overlay(alignment: .bottom) { toastView }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .sheet(item: $sharePayload, onDismiss: {
            guard exportCompleted else { return }
            exportCompleted = false
            showToast("已导出")
        }) { payload in
            ShareSheet(items: [payload.image]) { completed in
                exportCompleted = completed
            }
        }
        .task {
            // 调试用：--export 启动后自动点一次导出
            guard ProcessInfo.processInfo.arguments.contains("--export") else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            export()
        }
    }

    private func export() {
        guard let image = model.exportImage() else { return }
        exportCompleted = false
        sharePayload = SharePayload(image: image)
    }

    /// 底部提示条：自己消失，不挡操作。
    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Capsule(style: .continuous).fill(Theme.ink.opacity(0.92)))
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.18)) { toast = nil }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if model.screen == .card {
                Button {
                    model.back()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 32, height: 32)
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 18, height: 18)

                Text("纸条儿")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
            }

            Spacer()

            switch model.screen {
            case .list:
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 32, height: 32)
                .accessibilityLabel("设置")

                Button {
                    model.createDocument()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 32, height: 32)
                .accessibilityLabel("新建纸条")

            case .card:
                if !model.isEditing {
                    Button(action: export) {
                        Text("导出")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

/// 分享用的载荷：实现 Identifiable，`.sheet(item:)` 才会在值就绪时弹出
private struct SharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}
