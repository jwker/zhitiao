import CoreGraphics
import Foundation
import UIKit

/// 背景底纹：八种，全部程序绘制。
enum Backgrounds {

    static func paint(type: BackgroundType, palette: Palette, in ctx: CGContext, width: CGFloat, height: CGFloat) {
        switch type {
        case .gradient:
            // 整张卡片从左上到右下走一遍：起点端浓、终点端淡，两端都铺到角上，
            // 这样渐变铺满全卡，而不是只在某个角上叠一层色。
            let colors = [
                blend(palette.bg, with: palette.accent, amount: 0.24).cgColor,
                blend(palette.bg, with: palette.accent, amount: 0.11).cgColor,
                blend(palette.bg, with: palette.accent, amount: 0.02).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                ctx.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: width, y: height),
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }

        case .grid:
            ctx.setStrokeColor(palette.ink.withAlphaComponent(0.09).cgColor)
            ctx.setLineWidth(2)
            var x: CGFloat = 0
            while x <= width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: height))
                x += 60
            }
            var y: CGFloat = 0
            while y <= height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: width, y: y))
                y += 60
            }
            ctx.strokePath()

        case .ruled:
            ctx.setStrokeColor(palette.ink.withAlphaComponent(0.12).cgColor)
            ctx.setLineWidth(2)
            var y: CGFloat = 170
            while y < height - 120 {
                ctx.move(to: CGPoint(x: 78, y: y))
                ctx.addLine(to: CGPoint(x: width - 78, y: y))
                y += 58
            }
            ctx.strokePath()
            ctx.setStrokeColor(palette.accent.withAlphaComponent(0.28).cgColor)
            ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: 84, y: 120))
            ctx.addLine(to: CGPoint(x: 84, y: height - 120))
            ctx.strokePath()

        case .dots:
            ctx.setFillColor(palette.ink.withAlphaComponent(0.16).cgColor)
            var y: CGFloat = 150
            while y < height - 120 {
                var x: CGFloat = 110
                while x < width - 90 {
                    ctx.fillEllipse(in: CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2))
                    x += 46
                }
                y += 46
            }

        case .light:
            let colors = [
                UIColor.white.withAlphaComponent(0.92).cgColor,
                UIColor.white.withAlphaComponent(0).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                ctx.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: width / 2, y: -height * 0.08),
                    startRadius: 0,
                    endCenter: CGPoint(x: width / 2, y: -height * 0.08),
                    endRadius: height * 0.95,
                    options: []
                )
            }

        case .grain:
            // 颗粒质感：逐像素的噪点层，深浅随机、大部分像素保持透明，
            // 叠在底色上就是一整片哑光颗粒，而不是一颗颗可数的小点。
            if let noise = noiseImage(width: width, height: height, isDark: palette.bg.luminance < 0.35) {
                ctx.saveGState()
                // 关掉插值，放大渲染时颗粒保持锐利，不会被抹成一片灰
                ctx.interpolationQuality = .none
                ctx.draw(noise, in: CGRect(x: 0, y: 0, width: width, height: height))
                ctx.restoreGState()
            }

        case .stripes:
            ctx.setStrokeColor(palette.accent.withAlphaComponent(0.10).cgColor)
            ctx.setLineWidth(14)
            var x: CGFloat = -height
            while x < width + height {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x + height, y: height))
                x += 64
            }
            ctx.strokePath()

        case .solid:
            break
        }
    }

    // 颗粒质感的参数：覆盖率（有多少像素带颗粒）、最深一档的透明度。
    private static let grainCoverage: CGFloat = 0.60
    private static let grainAlpha: CGFloat = 0.26

    /// 噪点图按卡片尺寸生成后缓存（浅底、深底各留一张），避免每次重绘都重新算一遍。
    private static var noiseCache: [String: (size: CGSize, image: CGImage)] = [:]

    private static func noiseImage(width: CGFloat, height: CGFloat, isDark: Bool) -> CGImage? {
        let pixelWidth = Int(width)
        let pixelHeight = Int(height)
        let key = isDark ? "dark" : "light"
        if let cached = noiseCache[key],
           cached.size == CGSize(width: width, height: height) {
            return cached.image
        }

        guard pixelWidth > 0, pixelHeight > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let buffer = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: pixelWidth * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let raw = buffer.data
        else { return nil }

        let pixels = raw.assumingMemoryBound(to: UInt8.self)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func random() -> CGFloat {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return CGFloat(seed % 100_000) / 100_000
        }

        for index in 0..<(pixelWidth * pixelHeight) {
            let offset = index * 4
            // 大多数像素留空，只有一部分盖上一层浅浅的颗粒
            guard random() < grainCoverage else {
                pixels[offset] = 0
                pixels[offset + 1] = 0
                pixels[offset + 2] = 0
                pixels[offset + 3] = 0
                continue
            }
            // 平方分布：浅颗粒多、深颗粒少，看起来才像纸的纹理
            let alpha = grainAlpha * random() * random()
            let alphaByte = UInt8(alpha * 255)
            let isLightSpec = isDark ? random() < 0.55 : random() < 0.35
            // premultipliedLast：颜色要先乘上透明度
            let value = isLightSpec ? alphaByte : 0
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
            pixels[offset + 3] = alphaByte
        }

        guard let image = buffer.makeImage() else { return nil }
        noiseCache[key] = (CGSize(width: width, height: height), image)
        return image
    }

    /// 把 other 按比例混进 base，得到一层不透明的新颜色。
    private static func blend(_ base: UIColor, with other: UIColor, amount: CGFloat) -> UIColor {
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        var or: CGFloat = 0, og: CGFloat = 0, ob: CGFloat = 0, oa: CGFloat = 0
        base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        other.getRed(&or, green: &og, blue: &ob, alpha: &oa)
        let t = min(max(amount, 0), 1)
        return UIColor(
            red: br + (or - br) * t,
            green: bg + (og - bg) * t,
            blue: bb + (ob - bb) * t,
            alpha: 1
        )
    }
}

/// 程序画出来的元素：胶带、印章、圈选、手绘箭头。
enum Elements {

    static func draw(_ kind: String, at point: CGPoint, size: CGFloat, color: UIColor, in ctx: CGContext) {
        switch kind {
        case "tape":
            ctx.saveGState()
            ctx.translateBy(x: point.x, y: point.y)
            ctx.rotate(by: -0.28)
            ctx.setFillColor(color.withAlphaComponent(0.5).cgColor)
            ctx.fill(CGRect(x: -size * 0.9, y: -size * 0.16, width: size * 1.8, height: size * 0.32))
            ctx.restoreGState()

        case "stamp":
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(size * 0.07)
            ctx.strokeEllipse(in: CGRect(
                x: point.x - size * 0.42, y: point.y - size * 0.42,
                width: size * 0.84, height: size * 0.84
            ))
            ctx.setLineWidth(size * 0.045)
            ctx.strokeEllipse(in: CGRect(
                x: point.x - size * 0.32, y: point.y - size * 0.32,
                width: size * 0.64, height: size * 0.64
            ))
            ctx.setLineWidth(size * 0.07)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: point.x - size * 0.14, y: point.y))
            ctx.addLine(to: CGPoint(x: point.x - size * 0.03, y: point.y + size * 0.12))
            ctx.addLine(to: CGPoint(x: point.x + size * 0.16, y: point.y - size * 0.13))
            ctx.strokePath()

        case "circle":
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(size * 0.07)
            ctx.setLineCap(.round)
            ctx.strokeEllipse(in: CGRect(
                x: point.x - size * 0.46, y: point.y - size * 0.32,
                width: size * 0.92, height: size * 0.64
            ))

        case "arrow":
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(size * 0.08)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: point.x - size * 0.5, y: point.y + size * 0.16))
            ctx.addCurve(
                to: CGPoint(x: point.x + size * 0.42, y: point.y - size * 0.12),
                control1: CGPoint(x: point.x, y: point.y - size * 0.42),
                control2: CGPoint(x: point.x + size * 0.2, y: point.y - size * 0.2)
            )
            ctx.strokePath()
            ctx.move(to: CGPoint(x: point.x + size * 0.42, y: point.y - size * 0.12))
            ctx.addLine(to: CGPoint(x: point.x + size * 0.18, y: point.y - size * 0.2))
            ctx.move(to: CGPoint(x: point.x + size * 0.42, y: point.y - size * 0.12))
            ctx.addLine(to: CGPoint(x: point.x + size * 0.22, y: point.y + size * 0.04))
            ctx.strokePath()

        default:
            break
        }
    }
}

/// 文字加重：荧光笔、色块、下划线、波浪线。
enum Emphasis {

    static func draw(
        style: EmphasisStyle,
        rect: CGRect,
        size: CGFloat,
        color: UIColor,
        paletteIsDark: Bool = false,
        in ctx: CGContext
    ) {
        let x = rect.minX
        let baseline = rect.minY
        let width = rect.width

        switch style {
        case .block:
            ctx.setFillColor(color.withAlphaComponent(0.22).cgColor)
            let r = size * 0.14
            let box = CGRect(x: x - 10, y: baseline - size * 0.78, width: width + 20, height: size * 1.02)
            ctx.addPath(UIBezierPath(roundedRect: box, cornerRadius: r).cgPath)
            ctx.fillPath()

        case .underline:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(max(4, size * 0.07))
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: x, y: baseline + size * 0.18))
            ctx.addLine(to: CGPoint(x: x + width, y: baseline + size * 0.18))
            ctx.strokePath()

        case .wave:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(max(4, size * 0.065))
            ctx.setLineCap(.round)
            let steps = 24
            let amplitude = size * 0.07
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let px = x + t * width
                let py = baseline + size * 0.2 + sin(t * .pi * 6) * amplitude
                if i == 0 { ctx.move(to: CGPoint(x: px, y: py)) } else { ctx.addLine(to: CGPoint(x: px, y: py)) }
            }
            ctx.strokePath()

        case .marker:
            ctx.saveGState()
            // 深色底用 normal 混合并降低不透明度：multiply 在暗底上会糊成一团黑
            if paletteIsDark {
                ctx.setBlendMode(.normal)
                ctx.setFillColor(color.withAlphaComponent(0.42).cgColor)
            } else {
                ctx.setBlendMode(.multiply)
                ctx.setFillColor(color.withAlphaComponent(0.85).cgColor)
            }
            let jitter = size * 0.09
            let path = UIBezierPath()
            let box = CGRect(x: x - 10, y: baseline - size * 0.58, width: width + 20, height: size * 0.74)
            path.move(to: CGPoint(x: box.minX, y: box.minY + jitter))
            path.addLine(to: CGPoint(x: box.maxX, y: box.minY - jitter * 0.6))
            path.addLine(to: CGPoint(x: box.maxX - jitter, y: box.maxY + jitter * 0.4))
            path.addLine(to: CGPoint(x: box.minX + jitter, y: box.maxY - jitter * 0.5))
            path.close()
            ctx.addPath(path.cgPath)
            ctx.fillPath()
            ctx.restoreGState()

        case .color, .none:
            break
        }
    }
}
