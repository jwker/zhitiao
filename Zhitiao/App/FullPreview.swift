import SwiftUI

/// 全屏预览：深色背景，点任意处返回。
struct FullPreview: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#14120F").ignoresSafeArea()

            VStack(spacing: 24) {
                if let image {
                    ScrollView {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
                    }
                    .frame(maxHeight: 560)
                }

                Text("点任意处返回")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#F2F1EE").opacity(0.6))
            }
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .statusBarHidden(false)
    }
}
