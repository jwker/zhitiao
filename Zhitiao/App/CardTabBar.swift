import SwiftUI

/// 卡片页上的 tab：每类选项一个
///
/// 元素 / 强调 / 插画 依赖 AI，暂时下线。枚举值和对应实现都留在下面（见 OptionsPanel），
/// 恢复时把这几行注释打开、并把 CardTab.visible 里对应项加回去即可。
enum CardTab: String, CaseIterable, Identifiable {
    case background, align, font
    // case element
    // case emphasis
    // case illustration

    var id: String { rawValue }

    var name: String {
        switch self {
        case .background: return "背景"
        case .align: return "对齐"
        // case .element: return "元素"
        // case .emphasis: return "强调"
        // case .illustration: return "插画"
        case .font: return "字号"
        }
    }

    /// tab 条上实际显示的项。恢复 AI 相关 tab 时，把注释掉的项加回来。
    static var visible: [CardTab] {
        [.background, .align, .font]
        // [.background, .align, .element, .emphasis, .illustration, .font]
    }
}

struct CardTabBar: View {
    @Binding var selection: CardTab

    var body: some View {
        HStack(spacing: 24) {
            ForEach(CardTab.visible) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 9) {
                        Text(tab.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(selection == tab ? Theme.ink : Theme.muted)

                        Rectangle()
                            .fill(selection == tab ? Theme.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}
