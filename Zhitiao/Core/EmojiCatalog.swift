import CoreText
import Foundation
import UIKit

/// Emoji 目录：运行时枚举系统能画的 emoji，按区段分组。
///
/// iOS 没有「返回全部 emoji」的公开 API，所以这里扫描 Unicode 码点，
/// 再用「CoreText 是否真的用 AppleColorEmoji 来画」来验证系统有没有这个字形。
/// 组合 emoji（👨‍👩‍👧‍👦 这类 ZWJ 序列）单个码点扫不到，本版本不提供。
enum EmojiCatalog {

    static let maxSelection = 5

    struct Group: Identifiable {
        let id: String
        let name: String
        let emoji: [String]
    }

    /// 分组规则：按 Unicode 区段归类，先匹配先生效，剩下的丢进「其他」。
    private static let rules: [(name: String, ranges: [ClosedRange<UInt32>])] = [
        ("表情", [0x1F600...0x1F64F]),
        ("人物与手势", [0x1F440...0x1F483, 0x1F9B4...0x1F9DD]),
        ("动物与自然", [0x1F300...0x1F343, 0x1F400...0x1F43E, 0x1F980...0x1F9AE]),
        ("食物", [0x1F344...0x1F37F, 0x1F950...0x1F96F, 0x1F9C0...0x1F9CB]),
        ("活动", [0x1F380...0x1F3FF]),
        ("旅行与地点", [0x1F5FA...0x1F5FF, 0x1F680...0x1F6FF]),
        ("物品", [0x1F484...0x1F4FF, 0x1F9E0...0x1F9FF]),
        ("符号", [
            0x1F000...0x1F0FF, 0x1F170...0x1F1FF, 0x1F200...0x1F2FF, 0x1F500...0x1F5F9,
            0x1F650...0x1F67F, 0x1F700...0x1F7FF, 0x1F800...0x1F8FF,
            0x2190...0x21FF, 0x2600...0x27BF, 0x2900...0x297F, 0x2B00...0x2BFF
        ]),
        ("补充", [0x1F900...0x1F9FF, 0x1FA70...0x1FAFF])
    ]

    /// 这些不是独立的 emoji：区域指示符单独不成旗帜，肤色修饰符单独也没意义
    private static let excluded: [ClosedRange<UInt32>] = [
        0x1F1E6...0x1F1FF,
        0x1F3FB...0x1F3FF,
        0xFE00...0xFE0F,
        0x200D...0x200D
    ]

    private static let scanRanges: [ClosedRange<UInt32>] = [
        0x1F000...0x1FAFF,
        0x2600...0x27BF,
        0x2B00...0x2BFF,
        0x2190...0x21FF,
        0x2900...0x297F
    ]

    static let groups: [Group] = build()

    static var totalCount: Int {
        groups.reduce(0) { $0 + $1.emoji.count }
    }

    // MARK: - 构建

    private static func build() -> [Group] {
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 40, nil)
        var buckets: [String: [String]] = [:]
        var other: [String] = []

        for range in scanRanges {
            for value in range {
                guard let scalar = Unicode.Scalar(value) else { continue }
                if excluded.contains(where: { $0.contains(value) }) { continue }

                let properties = scalar.properties
                guard properties.isEmoji, properties.isEmojiPresentation else { continue }

                let text = String(scalar)
                guard renderedByEmojiFont(text, font: font) else { continue }

                if let name = rules.first(where: { $0.ranges.contains { $0.contains(value) } })?.name {
                    buckets[name, default: []].append(text)
                } else {
                    other.append(text)
                }
            }
        }

        var result: [Group] = rules.compactMap { rule in
            guard let list = buckets[rule.name], !list.isEmpty else { return nil }
            return Group(id: rule.name, name: rule.name, emoji: list)
        }

        if !other.isEmpty {
            result.append(Group(id: "其他", name: "其他", emoji: other))
        }
        return result
    }

    /// CoreText 是否真的用 Apple Color Emoji 来画这个字符
    private static func renderedByEmojiFont(_ text: String, font: CTFont) -> Bool {
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], let first = runs.first else { return false }
        let attributes = CTRunGetAttributes(first) as NSDictionary
        guard let used = attributes[kCTFontAttributeName] as! CTFont? else { return false }
        return (CTFontCopyFamilyName(used) as String) == "Apple Color Emoji"
    }
}
