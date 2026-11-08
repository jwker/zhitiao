import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("--settings")
    /// 用 item 触发弹出：保证 sheet 拿到图，而不是"先弹空页、再传值"
    @State private var sharePayload: SharePayload?

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
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.image])
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
        sharePayload = SharePayload(image: image)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if model.screen == .card {
                Button {
                    model.backToList()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 32, height: 32)
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 18, height: 18)

                Text("纸条")
                    .font(.system(size: 20, weight: .medium))
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
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 32, height: 32)
                .accessibilityLabel("新建纸条")

            case .card:
                if model.isEditing {
                    Button {
                        model.endEditing()
                    } label: {
                        Text("完成")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    Button(action: export) {
                        Text("导出")
                            .font(.system(size: 14, weight: .medium))
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
