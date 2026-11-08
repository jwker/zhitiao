import CoreGraphics
import Foundation
import UIKit

// MARK: - 卡片类型

enum BackgroundType: String, CaseIterable, Identifiable {
    case solid, gradient, grid, ruled, dots, light, grain, stripes

    var id: String { rawValue }

    var name: String {
        switch self {
        case .solid: return "纯色"
        case .gradient: return "渐变"
        case .grid: return "网格"
        case .ruled: return "横线稿纸"
        case .dots: return "点阵"
        case .light: return "光束"
        case .grain: return "颗粒纸感"
        case .stripes: return "斜纹"
        }
    }

    var note: String {
        switch self {
        case .solid: return "最干净"
        case .gradient: return "温柔安静"
        case .grid: return "技术理性"
        case .ruled: return "手写随笔"
        case .dots: return "备忘待办"
        case .light: return "方向指引"
        case .grain: return "文艺复古"
        case .stripes: return "轻快活泼"
        }
    }
}

enum AlignH: String, CaseIterable, Identifiable {
    case left, center, right

    var id: String { rawValue }

    var name: String {
        switch self {
        case .left: return "左对齐"
        case .center: return "居中对齐"
        case .right: return "右对齐"
        }
    }
}

enum AlignV: String, CaseIterable, Identifiable {
    case top, middle, bottom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .top: return "上对齐"
        case .middle: return "居中对齐"
        case .bottom: return "下对齐"
        }
    }
}

enum EmphasisStyle: String, CaseIterable, Identifiable {
    case none, marker, block, color, underline, wave

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: return "无强调"
        case .marker: return "荧光笔"
        case .block: return "色块"
        case .color: return "变色"
        case .underline: return "下划线"
        case .wave: return "波浪线"
        }
    }
}

enum FontFamily: String, CaseIterable, Identifiable {
    case sans, serif, kai

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sans: return "黑体"
        case .serif: return "宋体"
        case .kai: return "楷体"
        }
    }

    /// 中文优先用系统字族；楷体在部分系统缺失，回落到宋体。
    var fontName: String {
        switch self {
        case .sans: return "PingFangSC-Semibold"
        case .serif: return "SongtiSC-Bold"
        case .kai: return "KaitiSC-Bold"
        }
    }

    var fallbackFontName: String {
        switch self {
        case .sans: return "HelveticaNeue-Bold"
        case .serif: return "TimesNewRomanPS-Bold"
        case .kai: return "SongtiSC-Bold"
        }
    }
}

// MARK: - 元素装饰（素材库）

struct ElementItem: Identifiable, Hashable {
    enum Kind: String {
        case symbol
        case drawn
    }

    let id: String
    let name: String
    let kind: Kind
    let value: String
    let trailing: String?

    static let all: [ElementItem] = [
        .init(id: "none", name: "不加", kind: .symbol, value: "", trailing: nil),
        .init(id: "quote-left", name: "「", kind: .symbol, value: "「", trailing: nil),
        .init(id: "quote-right", name: "」", kind: .symbol, value: "」", trailing: nil),
        .init(id: "quote-both", name: "「」", kind: .symbol, value: "「", trailing: "」"),
        .init(id: "dquote", name: "“”", kind: .symbol, value: "“", trailing: "”"),
        .init(id: "dash", name: "——", kind: .symbol, value: "——", trailing: nil),
        .init(id: "ellipsis", name: "…", kind: .symbol, value: "…", trailing: nil),
        .init(id: "reference", name: "※", kind: .symbol, value: "※", trailing: nil),
        .init(id: "star", name: "★", kind: .symbol, value: "★", trailing: nil),
        .init(id: "diamond", name: "◇", kind: .symbol, value: "◇", trailing: nil),
        .init(id: "arrow-right", name: "→", kind: .symbol, value: "→", trailing: nil),
        .init(id: "arrow-up", name: "↑", kind: .symbol, value: "↑", trailing: nil),
        .init(id: "plus", name: "＋", kind: .symbol, value: "＋", trailing: nil),
        .init(id: "bar", name: "▍", kind: .symbol, value: "▍", trailing: nil),
        .init(id: "hash", name: "#", kind: .symbol, value: "#", trailing: nil),
        .init(id: "question", name: "?", kind: .symbol, value: "?", trailing: nil),
        .init(id: "exclaim", name: "!", kind: .symbol, value: "!", trailing: nil),
        .init(id: "tape", name: "胶带", kind: .drawn, value: "tape", trailing: nil),
        .init(id: "stamp", name: "印章", kind: .drawn, value: "stamp", trailing: nil),
        .init(id: "circle", name: "圈选", kind: .drawn, value: "circle", trailing: nil),
        .init(id: "arrow-drawn", name: "手绘箭头", kind: .drawn, value: "arrow", trailing: nil)
    ]

    static func find(_ id: String) -> ElementItem {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - 配色

/// FNV-1a：同一段文字永远给同一个索引（Swift 的 hashValue 每个进程会变）
func stableHash(_ text: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for byte in text.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x100000001b3
    }
    return hash
}

struct Palette: Equatable {
    let bg: UIColor
    let ink: UIColor
    let accent: UIColor

    static let seeds: [(bg: String, accent: String)] = [
        ("#FFFFFF", "#E23D28"),
        ("#F6F1E7", "#C2410C"),
        ("#E9F0E6", "#3F6B4A"),
        ("#E4EDF6", "#2F5D8C"),
        ("#F7E7E4", "#A63A3A"),
        ("#FBEFD8", "#B8722C"),
        ("#EDE7DE", "#7A6A55"),
        ("#1E1F22", "#E4B04A")
    ]

    /// 文字颜色由背景亮度决定，保证对比度。
    static func make(bgHex: String, accentHex: String) -> Palette {
        let bg = UIColor(hex: bgHex)
        let accent = UIColor(hex: accentHex)
        var ink = UIColor(hex: "#1B1C1E")
        var minRatio = 21.0
        for candidate in ["#1B1C1E", "#0E0E0E", "#FFFFFF", "#F6F3ED"] {
            let ratio = min(bg.contrastRatio(with: UIColor(hex: candidate)), minRatio)
            minRatio = ratio
            ink = UIColor(hex: candidate)
            if ratio >= 4.5 { break }
        }
        return Palette(bg: bg, ink: ink, accent: accent)
    }
}

// MARK: - 卡片描述

struct CardSpec {
    var lines: [String] = []
    var font: FontFamily = .sans
    var fontWeight: CGFloat = 900
    /// 字号由用户直接调，不再区分「上限」和「实际值」
    var fontSize: CGFloat = 50
    var align: (h: AlignH, v: AlignV) = (.center, .middle)
    var palette: Palette = .make(bgHex: "#FFFFFF", accentHex: "#E23D28")
    var background: BackgroundType = .solid
    var element: ElementItem = .all[0]
    var emphasisStyle: EmphasisStyle = .marker
    var emphasisWords: [String] = []
    var illustration: Illustration?


}

/// 一张插画：图像模型出的图，或退回内置简笔画。
struct Illustration: Identifiable {
    let id: String
    let subject: String
    /// 本地图像（图像模型生成后下载）
    var image: UIImage?
    /// 内置简笔画 id
    var fallbackId: String

    static let fallbackIds = ["plant", "cup", "book", "sparkle", "sun", "cloud", "phone", "gift"]
}
