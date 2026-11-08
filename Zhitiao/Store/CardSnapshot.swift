import Foundation
import UIKit

/// 卡片参数的可存储快照（只存原始值，存 iCloud / UserDefaults）。
struct CardSnapshot: Codable, Equatable {
    var lines: [String] = []
    var fontFamily: String = "sans"
    var fontWeight: Double = 900
    var maxSize: Double = 190
    var alignH: String = "center"
    var alignV: String = "middle"
    var bgHex: String = "#FFFFFF"
    var inkHex: String = "#1B1C1E"
    var accentHex: String = "#E23D28"
    var background: String = "solid"
    var elementID: String = "none"
    var emphasisStyle: String = "marker"
    var emphasisWords: [String] = []
    var illustrationID: String?
    var illustrationSubject: String?
    /// 内置简笔画的 id：重新打开时用它还原插画
    var illustrationFallback: String?

    init(spec: CardSpec) {
        lines = spec.lines
        fontFamily = spec.font.rawValue
        fontWeight = spec.fontWeight
        maxSize = spec.maxSize
        alignH = spec.align.h.rawValue
        alignV = spec.align.v.rawValue
        bgHex = spec.palette.bg.hexString
        inkHex = spec.palette.ink.hexString
        accentHex = spec.palette.accent.hexString
        background = spec.background.rawValue
        elementID = spec.element.id
        emphasisStyle = spec.emphasisStyle.rawValue
        emphasisWords = spec.emphasisWords
        illustrationID = spec.illustration?.id
        illustrationSubject = spec.illustration?.subject
        illustrationFallback = spec.illustration?.fallbackId
    }

    func makeSpec(illustration: Illustration?) -> CardSpec {
        var spec = CardSpec()
        spec.lines = lines
        spec.font = FontFamily(rawValue: fontFamily) ?? .sans
        spec.fontWeight = CGFloat(fontWeight)
        spec.maxSize = CGFloat(maxSize)
        spec.align = (
            AlignH(rawValue: alignH) ?? .center,
            AlignV(rawValue: alignV) ?? .middle
        )
        spec.palette = Palette(
            bg: UIColor(hex: bgHex),
            ink: UIColor(hex: inkHex),
            accent: UIColor(hex: accentHex)
        )
        spec.background = BackgroundType(rawValue: background) ?? .solid
        spec.element = ElementItem.find(elementID)
        spec.emphasisStyle = EmphasisStyle(rawValue: emphasisStyle) ?? .marker
        spec.emphasisWords = emphasisWords
        spec.illustration = illustration
        return spec
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255))
        )
    }
}
