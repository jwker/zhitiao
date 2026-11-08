import SwiftUI
import UIKit

/// 把内置简笔画渲染成缩略图
enum DoodleThumbnail {
    static func image(for id: String) -> UIImage {
        let size = CGSize(width: 120, height: 120)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            Illustrations.draw(id: id, at: CGPoint(x: 60, y: 60), size: 110, in: ctx.cgContext)
        }
    }
}

/// 素材总览：把全部内置简笔画拼成一张图，用来检查风格是否一致
enum DoodleSheet {
    static func image() -> UIImage {
        let ids = ["plant", "leaf", "flower", "cactus", "book", "cup", "phone", "clock", "camera",
                   "gift", "note", "sun", "cloud", "star", "heart", "sparkle", "arrow", "circle"]
        let cell: CGFloat = 200
        let columns = 6
        let rows = Int(ceil(Double(ids.count) / Double(columns)))
        let size = CGSize(width: cell * CGFloat(columns), height: cell * CGFloat(rows))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            for (index, id) in ids.enumerated() {
                let col = index % columns
                let row = index / columns
                let center = CGPoint(x: cell * (CGFloat(col) + 0.5), y: cell * (CGFloat(row) + 0.5))
                Illustrations.draw(id: id, at: center, size: cell * 0.72, in: cg)
            }
        }
    }
}

/// 系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
