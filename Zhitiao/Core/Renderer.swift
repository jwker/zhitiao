import CoreGraphics
import CoreText
import Foundation
import UIKit

/// 排版引擎：从文字到一张卡片图。
///
/// 字号是用户直接给的；卡片宽度固定 1080，高度跟着内容长（最少 1440，即 3:4）。
/// 流程：切行 → 按字号折行 → 算高度 → 垂直定位 → 分层绘制
enum Renderer {

    // MARK: - 排版

    struct PositionedLine {
        let text: String
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let size: CGFloat
    }

    struct Layout {
        var size: CGFloat
        /// 顶部单独一行 emoji（可能为空）
        var emojiLine: PositionedLine?
        /// 卡片最终高度：内容多就长，最少 1440
        var height: CGFloat
        var lineHeight: CGFloat
        var gap: CGFloat
        var blockHeight: CGFloat
        var lines: [PositionedLine] = []
    }

    static let padding = (top: CGFloat(120), right: CGFloat(96), bottom: CGFloat(132), left: CGFloat(96))
    static let lineHeightRatio: CGFloat = 1.34
    static let gapRatio: CGFloat = 0.3
    /// 卡片的最小高度：内容再少也不低于 3:4
    static let minWidth: CGFloat = 1080
    static let minHeight: CGFloat = 1440
    /// 标点不允许出现在行首
    static let noLineStart = "，。！？、；：）】》」』”’%·,.;:!?)]}\"'"

    /// 取指定字重的字体，找不到就逐级回落
    static func font(for spec: CardSpec, size: CGFloat, weight: CGFloat? = nil) -> UIFont {
        let w = weight ?? spec.fontWeight
        return UIFont(name: spec.font.fontName, size: size)
            ?? UIFont(name: spec.font.fallbackFontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: weightToUIFontWeight(w))
    }

    /// 量一行文字的宽度（CoreText，和绘制用同一套度量）
    static func measure(_ text: String, spec: CardSpec, size: CGFloat, weight: CGFloat? = nil) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font(for: spec, size: size, weight: weight)])
        )
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        return ceil(width)
    }

    /// emoji 用 Apple Color Emoji 量宽（每个 emoji 宽度正好等于字号）
    static func measureEmoji(_ text: String, size: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font])
        )
        return ceil(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// 一行放不下就按字折行，标点不落行首
    static func wrap(_ text: String, spec: CardSpec, size: CGFloat, maxWidth: CGFloat) -> [String] {
        guard !text.isEmpty else { return [] }
        var lines: [String] = []
        var current = ""

        for character in text {
            let candidate = current + String(character)
            if !current.isEmpty, measure(candidate, spec: spec, size: size) > maxWidth {
                if noLineStart.contains(character), current.count > 1 {
                    // 标点不能起头：把上一个字一起带到下一行
                    let carried = String(current.removeLast())
                    lines.append(current)
                    current = carried + String(character)
                } else {
                    lines.append(current)
                    current = String(character)
                }
            } else {
                current = candidate
            }
        }

        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// 排版：字号由用户直接给定，卡片高度跟着内容长
    static func layout(spec: CardSpec, lines inputLines: [String]) -> Layout {
        let size = max(24, spec.fontSize)
        var contentWidth = minWidth - padding.left - padding.right

        // 左对齐且有开头符号时扣掉符号占位。元素装饰下线后恒为 0，恢复时改回来即可。
        // let symbolSpace: CGFloat = (spec.align.h == .left && !spec.element.value.isEmpty && spec.element.kind == .symbol) ? 78 : 0
        let symbolSpace: CGFloat = 0
        contentWidth -= symbolSpace

        // 每一行按当前字号折行
        var wrapped: [String] = []
        for line in inputLines {
            wrapped.append(contentsOf: wrap(line, spec: spec, size: size, maxWidth: contentWidth))
        }
        if wrapped.isEmpty { wrapped = [""] }

        let lineHeight = size * lineHeightRatio
        var gap = size * gapRatio
        let minContentHeight = minHeight - padding.top - padding.bottom

        // 顶部 emoji 行：占一行高度，下面再多留一点空隙，让它像一个符号而不是正文
        let emojiText = spec.emoji.joined()
        let hasEmoji = !emojiText.isEmpty
        // emoji 放大到正文的两倍，作为卡片顶部的视觉符号；
        // 但字号很大 + emoji 很多时要收一收，别超出卡片宽度
        let emojiCount = max(1, spec.emoji.count)
        let emojiSize = min(size * 2, contentWidth * 0.98 / CGFloat(emojiCount))
        let emojiHeight = hasEmoji ? emojiSize * 1.15 : 0
        let emojiGap = hasEmoji ? size * 0.72 : 0

        func blockHeight(_ gap: CGFloat) -> CGFloat {
            let textBlock = CGFloat(wrapped.count) * lineHeight + CGFloat(max(0, wrapped.count - 1)) * gap
            return emojiHeight + emojiGap + textBlock
        }

        // 内容少时把行距撑开，让短句在 3:4 的卡上也站得住
        if wrapped.count > 1, blockHeight(gap) < minContentHeight * 0.82 {
            gap *= min(1.9, minContentHeight * 0.82 / blockHeight(gap))
        }

        let contentHeight = max(minContentHeight, blockHeight(gap))
        let height = padding.top + contentHeight + padding.bottom

        var top: CGFloat = 0
        switch spec.align.v {
        case .top: top = 0
        case .middle: top = max(0, (contentHeight - blockHeight(gap)) / 2)
        case .bottom: top = max(0, contentHeight - blockHeight(gap))
        }

        var emojiLine: PositionedLine?
        var cursor = top

        if hasEmoji {
            let width = measureEmoji(emojiText, size: emojiSize)
            var x: CGFloat = 0
            switch spec.align.h {
            case .left: x = 0
            case .center: x = (contentWidth - width) / 2
            case .right: x = contentWidth - width
            }
            emojiLine = PositionedLine(
                text: emojiText,
                x: x + padding.left + symbolSpace,
                y: cursor + padding.top,
                width: width,
                height: emojiHeight,
                size: emojiSize
            )
            cursor += emojiHeight + emojiGap
        }

        var positioned: [PositionedLine] = []
        for text in wrapped {
            let width = measure(text, spec: spec, size: size)
            var x: CGFloat = 0
            switch spec.align.h {
            case .left: x = 0
            case .center: x = (contentWidth - width) / 2
            case .right: x = contentWidth - width
            }
            positioned.append(
                PositionedLine(
                    text: text,
                    x: x + padding.left + symbolSpace,
                    y: cursor + padding.top,
                    width: width,
                    height: lineHeight,
                    size: size
                )
            )
            cursor += lineHeight + gap
        }

        return Layout(
            size: size,
            emojiLine: emojiLine,
            height: height,
            lineHeight: lineHeight,
            gap: gap,
            blockHeight: blockHeight(gap),
            lines: positioned
        )
    }

    // MARK: - 绘制

    static func render(spec: CardSpec, lines: [String], scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let layout = layout(spec: spec, lines: lines)
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: Renderer.minWidth, height: layout.height),
            format: format
        )
        return renderer.image { ctx in
            draw(spec: spec, lines: lines, layout: layout, in: ctx.cgContext)
        }
    }

    static func draw(spec: CardSpec, lines: [String], layout: Layout, in ctx: CGContext) {
        let W = minWidth
        let H = layout.height

        // 背景
        ctx.setFillColor(spec.palette.bg.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        Backgrounds.paint(type: spec.background, palette: spec.palette, in: ctx, width: W, height: H)

        // 元素装饰：依赖 AI，暂时下线
        // drawElement(spec.element, spec: spec, in: ctx, width: W, height: H, layout: layout)

        // 文字
        for line in layout.lines {
            drawLine(line, spec: spec, in: ctx)
        }

        // 顶部 emoji 行
        if let emojiLine = layout.emojiLine {
            drawEmojiLine(emojiLine, in: ctx)
        }

        // 插画：依赖 AI，暂时下线
        // if let illustration = spec.illustration {
        //     drawIllustration(illustration, spec: spec, in: ctx, width: W, height: H, layout: layout)
        // }
    }

    private static func drawElement(
        _ element: ElementItem,
        spec: CardSpec,
        in ctx: CGContext,
        width: CGFloat,
        height: CGFloat,
        layout: Layout
    ) {
        guard element.id != "none" else { return }
        let size = layout.size * 0.9
        let top = padding.top
        let left = padding.left

        switch element.kind {
        case .symbol:
            drawText(
                element.value,
                at: CGPoint(x: left, y: top + size * 0.8),
                size: size,
                color: spec.palette.accent,
                font: font(for: spec, size: size, weight: 700),
                in: ctx
            )
            if let trailing = element.trailing {
                let w = measure(trailing, spec: spec, size: size, weight: 700)
                drawText(
                    trailing,
                    at: CGPoint(x: width - padding.right - w, y: height - padding.bottom - size * 0.2),
                    size: size,
                    color: spec.palette.accent,
                    font: font(for: spec, size: size, weight: 700),
                    in: ctx
                )
            }
        case .drawn:
            Elements.draw(element.value, at: CGPoint(x: left + 50, y: top + 40), size: 110, color: spec.palette.accent, in: ctx)
        }
    }

    /// 在基线上绘制一段文字（CoreText，基线精确）
    private static func drawText(
        _ text: String,
        at origin: CGPoint,
        size: CGFloat,
        color: UIColor,
        font: UIFont,
        in ctx: CGContext
    ) {
        guard !text.isEmpty else { return }
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let line = CTLineCreateWithAttributedString(attributed)
        // UIKit 的上下文 y 轴向下，CoreText 的基线是 y 轴向上：先把坐标系翻回来
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    private static func drawLine(
        _ line: PositionedLine,
        spec: CardSpec,
        in ctx: CGContext
    ) {
        let baseline = line.y + line.height / 2 + line.size * 0.36
        let parts = splitByEmphasis(line.text, words: spec.emphasisStyle == .none ? [] : spec.emphasisWords)

        var cursor = line.x
        var segments: [(text: String, key: Bool, x: CGFloat, width: CGFloat)] = []
        for part in parts {
            let weight: CGFloat = part.key ? max(spec.fontWeight, 800) : spec.fontWeight
            let width = measure(part.text, spec: spec, size: line.size)
            segments.append((part.text, part.key, cursor, width))
            cursor += width
        }

        // 强调装饰：依赖 AI，暂时下线（只画纯文字）
        // if spec.emphasisStyle != .none {
        //     for segment in segments where segment.key {
        //         Emphasis.draw(
        //             style: spec.emphasisStyle,
        //             rect: CGRect(x: segment.x, y: baseline, width: segment.width, height: line.size),
        //             size: line.size,
        //             color: spec.palette.accent,
        //             paletteIsDark: spec.palette.bg.luminance < 0.4,
        //             in: ctx
        //         )
        //     }
        // }

        for segment in segments {
            let weight: CGFloat = segment.key ? max(spec.fontWeight, 800) : spec.fontWeight
            // 强调下线后统一用正文色
            // let color = (segment.key && spec.emphasisStyle == .color) ? spec.palette.accent : spec.palette.ink
            let color = spec.palette.ink
            drawText(
                segment.text,
                at: CGPoint(x: segment.x, y: baseline),
                size: line.size,
                color: color,
                font: font(for: spec, size: line.size, weight: weight),
                in: ctx
            )
        }
    }

    /// 把一行按强调词切成片段
    static func splitByEmphasis(_ text: String, words: [String]) -> [(text: String, key: Bool)] {
        guard !words.isEmpty else { return [(text, false)] }

        var hits: [(start: Int, len: Int)] = []
        for word in words where !word.isEmpty {
            var index = text.startIndex
            while let range = text.range(of: word, range: index..<text.endIndex) {
                let start = text.distance(from: text.startIndex, to: range.lowerBound)
                hits.append((start, word.count))
                index = range.upperBound
            }
        }
        guard !hits.isEmpty else { return [(text, false)] }
        hits.sort { $0.start < $1.start }

        var merged: [(start: Int, len: Int)] = []
        for hit in hits {
            if let last = merged.last, hit.start < last.start + last.len {
                merged[merged.count - 1] = (last.start, max(last.len, hit.start + hit.len - last.start))
            } else {
                merged.append(hit)
            }
        }

        var parts: [(text: String, key: Bool)] = []
        let ns = text as NSString
        var cursor = 0
        for hit in merged {
            if hit.start > cursor {
                parts.append((ns.substring(with: NSRange(location: cursor, length: hit.start - cursor)), false))
            }
            parts.append((ns.substring(with: NSRange(location: hit.start, length: hit.len)), true))
            cursor = hit.start + hit.len
        }
        if cursor < ns.length {
            parts.append((ns.substring(from: cursor), false))
        }
        return parts
    }

    /// 插画画在角落。空间不够就缩小，再不够就用最小尺寸放到重叠最少的角上——
    /// 宁可小一点，也不能整张卡没有插画。
    /// 画顶部那行 emoji（Apple Color Emoji 是彩色位图字体）
    private static func drawEmojiLine(_ line: PositionedLine, in ctx: CGContext) {
        guard !line.text.isEmpty else { return }
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, line.size, nil)
        let attributed = NSAttributedString(string: line.text, attributes: [.font: font])
        let ctLine = CTLineCreateWithAttributedString(attributed)

        // 基线放在这个行盒的底部附近，emoji 的升部约等于字号
        let baseline = line.y + line.size

        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: line.x, y: baseline)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(ctLine, ctx)
        ctx.restoreGState()
    }

    private static func drawIllustration(
        _ illustration: Illustration,
        spec: CardSpec,
        in ctx: CGContext,
        width: CGFloat,
        height: CGFloat,
        layout: Layout
    ) {
        let inset: CGFloat = 96
        let sizes: [CGFloat] = [210, 176, 148, 124, 104]

        let lineRects = layout.lines.map {
            CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height).insetBy(dx: -8, dy: -8)
        }

        let corners: [CGPoint] = [
            CGPoint(x: inset + 60, y: inset + 60),
            CGPoint(x: width - inset - 60, y: inset + 60),
            CGPoint(x: inset + 60, y: height - inset - 60),
            CGPoint(x: width - inset - 60, y: height - inset - 60)
        ]

        func frame(for center: CGPoint, size: CGFloat) -> CGRect {
            CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        }

        var chosen: (center: CGPoint, size: CGFloat)?

        // 先找不压住任何一行文字的尺寸
        outer: for size in sizes {
            for center in corners {
                let box = frame(for: center, size: size)
                let hitsText = lineRects.contains { $0.intersects(box) }
                if !hitsText {
                    chosen = (center, size)
                    break outer
                }
            }
        }

        // 都压住就用最小尺寸，挑重叠面积最小的角
        if chosen == nil {
            let size: CGFloat = 104
            var best: (center: CGPoint, overlap: CGFloat)?
            for center in corners {
                let box = frame(for: center, size: size)
                let overlap = lineRects.reduce(CGFloat(0)) { sum, rect in
                    let intersection = rect.intersection(box)
                    return sum + (intersection.isNull ? 0 : intersection.width * intersection.height)
                }
                if best == nil || overlap < best!.overlap {
                    best = (center, overlap)
                }
            }
            if let best { chosen = (best.center, size) }
        }

        guard let chosen else { return }
        let box = frame(for: chosen.center, size: chosen.size)

        ctx.saveGState()
        ctx.setAlpha(0.96)
        if let image = illustration.image {
            image.draw(in: box)
        } else {
            Illustrations.draw(
                id: illustration.fallbackId,
                at: CGPoint(x: box.midX, y: box.midY),
                size: chosen.size,
                in: ctx
            )
        }
        ctx.restoreGState()
    }

    static func weightToUIFontWeight(_ weight: CGFloat) -> UIFont.Weight {
        switch weight {
        case ..<600: return .medium
        case ..<750: return .semibold
        case ..<850: return .bold
        default: return .heavy
        }
    }
}
