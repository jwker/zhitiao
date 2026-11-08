import CoreGraphics
import CoreText
import Foundation
import UIKit

/// 排版引擎：从文字到一张 1080×1440 的卡片图。
///
/// 流程与 H5 版一致：
///   切行 → 宽度/高度双向约束算字号 → 行距撑开 → 垂直定位 → 分层绘制
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
        var lineHeight: CGFloat
        var gap: CGFloat
        var blockHeight: CGFloat
        var lines: [PositionedLine] = []
    }

    static let padding = (top: CGFloat(120), right: CGFloat(96), bottom: CGFloat(132), left: CGFloat(96))
    static let lineHeightRatio: CGFloat = 1.34
    static let gapRatio: CGFloat = 0.3
    static let fillRatio: CGFloat = 0.72

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

    /// 算字号：宽度约束与高度约束取小者
    static func fitSize(lines: [String], spec: CardSpec, contentWidth: CGFloat, contentHeight: CGFloat) -> CGFloat {
        let unit: CGFloat = 100
        var maxUnit: CGFloat = 0
        for line in lines {
            let width = measure(line, spec: spec, size: unit)
            maxUnit = max(maxUnit, width / unit)
        }
        let widthLimit = maxUnit > 0 ? (contentWidth * 0.94) / maxUnit : spec.maxSize
        var size = min(spec.maxSize, widthLimit)

        func height(_ s: CGFloat) -> CGFloat {
            CGFloat(lines.count) * s * lineHeightRatio + CGFloat(max(0, lines.count - 1)) * s * gapRatio
        }

        if height(size) > contentHeight * fillRatio {
            var low: CGFloat = 18
            var high = size
            while high - low > 1 {
                let mid = (low + high) / 2
                if height(mid) <= contentHeight * fillRatio { low = mid } else { high = mid }
            }
            size = low
        }
        return max(18, round(size))
    }

    static func layout(spec: CardSpec, lines: [String]) -> Layout {
        var contentWidth = spec.canvasWidth - padding.left - padding.right
        let contentHeight = spec.canvasHeight - padding.top - padding.bottom

        // 左对齐时，开头符号要占位置，先从可用宽度里扣掉
        let symbolSpace: CGFloat = (spec.align.h == .left && !spec.element.value.isEmpty && spec.element.kind == .symbol)
            ? 78 : 0
        contentWidth -= symbolSpace

        let size = fitSize(lines: lines, spec: spec, contentWidth: contentWidth, contentHeight: contentHeight)
        let lineHeight = size * lineHeightRatio
        var gap = size * gapRatio
        var blockHeight = CGFloat(lines.count) * lineHeight + CGFloat(max(0, lines.count - 1)) * gap

        // 文字块比卡片矮时把行距撑开（最多 1.9 倍）
        if lines.count > 1 {
            let target = contentHeight * 0.82
            if blockHeight < target {
                gap *= min(1.9, target / blockHeight)
                blockHeight = CGFloat(lines.count) * lineHeight + CGFloat(max(0, lines.count - 1)) * gap
            }
        }

        var top: CGFloat = 0
        switch spec.align.v {
        case .top: top = 0
        case .middle: top = max(0, (contentHeight - blockHeight) / 2)
        case .bottom: top = max(0, contentHeight - blockHeight)
        }

        var positioned: [PositionedLine] = []
        var cursor = top
        for text in lines {
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

        return Layout(size: size, lineHeight: lineHeight, gap: gap, blockHeight: blockHeight, lines: positioned)
    }

    // MARK: - 绘制

    static func render(spec: CardSpec, lines: [String], scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: spec.canvasWidth, height: spec.canvasHeight),
            format: format
        )
        return renderer.image { ctx in
            draw(spec: spec, lines: lines, in: ctx.cgContext)
        }
    }

    static func draw(spec: CardSpec, lines: [String], in ctx: CGContext) {
        let W = spec.canvasWidth
        let H = spec.canvasHeight
        let layout = layout(spec: spec, lines: lines)

        // 背景
        ctx.setFillColor(spec.palette.bg.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        Backgrounds.paint(type: spec.background, palette: spec.palette, in: ctx, width: W, height: H)

        // 元素装饰
        drawElement(spec.element, spec: spec, in: ctx, width: W, height: H, layout: layout)

        // 文字
        for line in layout.lines {
            drawLine(line, spec: spec, in: ctx)
        }

        // 插画
        if let illustration = spec.illustration {
            drawIllustration(illustration, spec: spec, in: ctx, width: W, height: H, layout: layout)
        }
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

        // 强调装饰画在文字下面
        if spec.emphasisStyle != .none {
            for segment in segments where segment.key {
                Emphasis.draw(
                    style: spec.emphasisStyle,
                    rect: CGRect(x: segment.x, y: baseline, width: segment.width, height: line.size),
                    size: line.size,
                    color: spec.palette.accent,
                    paletteIsDark: spec.palette.bg.luminance < 0.4,
                    in: ctx
                )
            }
        }

        for segment in segments {
            let weight: CGFloat = segment.key ? max(spec.fontWeight, 800) : spec.fontWeight
            let color = (segment.key && spec.emphasisStyle == .color) ? spec.palette.accent : spec.palette.ink
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

// MARK: - CardSpec 便利属性

extension CardSpec {
    var canvasWidth: CGFloat { 1080 }
    var canvasHeight: CGFloat { 1440 }
}
