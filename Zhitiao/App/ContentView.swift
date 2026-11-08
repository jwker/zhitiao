import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                switch model.screen {
                case .input:
                    InputScreen()
                case .card:
                    CardScreen()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if model.screen == .card {
                Button {
                    model.screen = .input
                    model.saveNow()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
            }

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 18, height: 18)

            Text("纸条")
                .font(.system(size: 20, weight: .medium))

            Spacer()

            Button("设置") {
                showSettings = true
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.ink)
            .textCase(nil)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

/// 通用控件：面板、选项按钮
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// 素材库里的固定选项
struct OptionButton: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(active ? Theme.bg : Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(active ? Theme.ink : Theme.bg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(active ? Color.clear : Theme.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct GroupLabel: View {
    let title: String
    var value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}
