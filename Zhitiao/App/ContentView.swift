import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = ProcessInfo.processInfo.arguments.contains("--settings")
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var cardScreen: CardScreen?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                switch model.screen {
                case .list:
                    ListView()
                case .card:
                    CardScreenHost(onExport: export)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
        .sheet(isPresented: $showShare) {
            if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    private func export() {
        guard let image = model.exportImage() else { return }
        shareImage = image
        showShare = true
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

/// 把 CardScreen 的导出动作交给外层顶栏
private struct CardScreenHost: View {
    let onExport: () -> Void

    var body: some View {
        CardScreen()
    }
}
