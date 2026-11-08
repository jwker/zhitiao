import SwiftUI

/// 卡片页上的 tab：每类选项一个
enum CardTab: String, CaseIterable, Identifiable {
    case background, align, element, emphasis, illustration, font

    var id: String { rawValue }

    var name: String {
        switch self {
        case .background: return "背景"
        case .align: return "对齐"
        case .element: return "元素"
        case .emphasis: return "强调"
        case .illustration: return "插画"
        case .font: return "字号"
        }
    }
}

struct CardTabBar: View {
    @Binding var selection: CardTab

    var body: some View {
        HStack(spacing: 24) {
            ForEach(CardTab.allCases) { tab in
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
