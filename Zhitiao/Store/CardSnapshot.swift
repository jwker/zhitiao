import Foundation
import UIKit

/// 卡片参数的可存储快照（只存原始值，存 iCloud / UserDefaults）。
struct CardSnapshot: Codable, Equatable {
    var lines: [String] = []
    var fontFamily: String = "sans"
    var fontWeight: Double = 600
    var fontSize: Double = 50
    var alignH: String = "center"
    var alignV: String = "middle"
    var bgHex: String = "#FFFFFF"
    var inkHex: String = "#1B1C1E"
    var accentHex: String = "#E23D28"
    var background: String = "solid"
    var elementID: String = "none"
    var emphasisStyle: String = "marker"
    var emphasisWords: [String] = []
    var emoji: [String] = []
    var illustrationID: String?
    var illustrationSubject: String?
    /// 内置简笔画的 id：重新打开时用它还原插画
    var illustrationFallback: String?

    /// 老版本存的是 maxSize（字号上限），读旧数据时当成字号用
    private enum LegacyKey: String, CodingKey {
        case maxSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKey.self)

        lines = try container.decode([String].self, forKey: .lines)
        fontFamily = try container.decode(String.self, forKey: .fontFamily)
        fontWeight = try container.decode(Double.self, forKey: .fontWeight)
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize)
            ?? legacy.decodeIfPresent(Double.self, forKey: .maxSize)
            ?? 50
        alignH = try container.decode(String.self, forKey: .alignH)
        alignV = try container.decode(String.self, forKey: .alignV)
        bgHex = try container.decode(String.self, forKey: .bgHex)
        inkHex = try container.decode(String.self, forKey: .inkHex)
        accentHex = try container.decode(String.self, forKey: .accentHex)
        background = try container.decode(String.self, forKey: .background)
        elementID = try container.decode(String.self, forKey: .elementID)
        emphasisStyle = try container.decode(String.self, forKey: .emphasisStyle)
        emphasisWords = try container.decode([String].self, forKey: .emphasisWords)
        emoji = try container.decodeIfPresent([String].self, forKey: .emoji) ?? []
        illustrationID = try container.decodeIfPresent(String.self, forKey: .illustrationID)
        illustrationSubject = try container.decodeIfPresent(String.self, forKey: .illustrationSubject)
        illustrationFallback = try container.decodeIfPresent(String.self, forKey: .illustrationFallback)
    }

    init(spec: CardSpec) {
        lines = spec.lines
        fontFamily = spec.font.rawValue
        fontWeight = spec.fontWeight
        fontSize = spec.fontSize
        alignH = spec.align.h.rawValue
        alignV = spec.align.v.rawValue
        bgHex = spec.palette.bg.hexString
        inkHex = spec.palette.ink.hexString
        accentHex = spec.palette.accent.hexString
        background = spec.background.rawValue
        elementID = spec.element.id
        emphasisStyle = spec.emphasisStyle.rawValue
        emphasisWords = spec.emphasisWords
        emoji = spec.emoji
        illustrationID = spec.illustration?.id
        illustrationSubject = spec.illustration?.subject
        illustrationFallback = spec.illustration?.fallbackId
    }

    func makeSpec(illustration: Illustration?) -> CardSpec {
        var spec = CardSpec()
        spec.lines = lines
        spec.font = FontFamily(rawValue: fontFamily) ?? .sans
        spec.fontWeight = CGFloat(fontWeight)
        spec.fontSize = CGFloat(fontSize)
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
        spec.emoji = emoji
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
