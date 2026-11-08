import Foundation
import UIKit

extension UIColor {
    convenience init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 {
            value = value.map { "\($0)\($0)" }.joined()
        }
        var number: UInt64 = 0
        Scanner(string: value).scanHexInt64(&number)
        self.init(
            red: CGFloat((number & 0xFF0000) >> 16) / 255,
            green: CGFloat((number & 0x00FF00) >> 8) / 255,
            blue: CGFloat(number & 0x0000FF) / 255,
            alpha: 1
        )
    }

    /// 相对亮度（WCAG）
    var luminance: CGFloat {
        func channel(_ value: CGFloat) -> CGFloat {
            let s = value
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// 对比度（WCAG）
    func contrastRatio(with other: UIColor) -> CGFloat {
        let a = luminance
        let b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
