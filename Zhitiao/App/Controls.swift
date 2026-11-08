import SwiftUI

/// 素材库里的固定选项按钮：选中时用墨色实心，不用强调色（强调色留给主操作）
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

/// 分组标题 + 右侧当前值
struct GroupLabel: View {
    let title: String
    var value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 12)
            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
        }
    }
}

/// 插画候选缩略图：有生成图就显示图，否则显示内置简笔画
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
