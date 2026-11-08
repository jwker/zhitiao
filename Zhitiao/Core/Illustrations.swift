import CoreGraphics
import Foundation
import UIKit

/// 内置简笔画素材：图像模型没配或失败时的兜底，风格与插画规范一致。
///
/// 统一规则：120×120 视口、描边 `#3A3733`、线宽 6、莫兰迪平涂、圆头圆角。
enum Illustrations {

    static let stroke = UIColor(hex: "#3A3733")
    static let leaf = UIColor(hex: "#7FA98A")
    static let pot = UIColor(hex: "#D98E6A")
    static let petal = UIColor(hex: "#E8A0A8")
    static let sun = UIColor(hex: "#F0C96A")
    static let paper = UIColor(hex: "#F4EFE6")
    static let coffee = UIColor(hex: "#8C6A50")
    static let cup = UIColor(hex: "#E3D5C5")
    static let blue = UIColor(hex: "#6E8CB8")
    static let cloud = UIColor(hex: "#E3E7EC")
    static let coral = UIColor(hex: "#E07A6B")

    static func draw(id: String, at point: CGPoint, size: CGFloat, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: point.x - size / 2, y: point.y - size / 2)
        ctx.scaleBy(x: size / 120, y: size / 120)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(6)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch id {
        case "plant": plant(ctx)
        case "leaf": leafShape(ctx)
        case "flower": flower(ctx)
        case "cactus": cactus(ctx)
        case "book": book(ctx)
        case "cup": coffeeCup(ctx)
        case "phone": phone(ctx)
        case "clock": clock(ctx)
        case "camera": camera(ctx)
        case "gift": gift(ctx)
        case "note": note(ctx)
        case "sun": sunShape(ctx)
        case "cloud": cloudShape(ctx)
        case "star": star(ctx)
        case "heart": heart(ctx)
        case "sparkle": sparkle(ctx)
        case "arrow": arrow(ctx)
        case "circle": circleMark(ctx)
        default: plant(ctx)
        }

        ctx.restoreGState()
    }

    // MARK: - 图形

    private static func leafPath(_ ctx: CGContext, from: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: from.x, y: from.y)
        ctx.rotate(by: angle)
        ctx.move(to: .zero)
        ctx.addCurve(to: CGPoint(x: length, y: 0), control1: CGPoint(x: length * 0.5, y: -width), control2: CGPoint(x: length * 0.5, y: -width))
        ctx.addCurve(to: .zero, control1: CGPoint(x: length * 0.5, y: width), control2: CGPoint(x: length * 0.5, y: width))
        ctx.closePath()
        ctx.restoreGState()
    }

    private static func plant(_ ctx: CGContext) {
        // 三片叶从盆口散开（y 轴向下，负角度向上偏右）
        for (angle, length, width) in [(-0.62, 32.0, 14.0), (-0.06, 36.0, 15.0), (0.5, 30.0, 13.0)] {
            leafPath(ctx, from: CGPoint(x: 60, y: 70), angle: CGFloat(angle), length: CGFloat(length), width: CGFloat(width))
            ctx.setFillColor(leaf.cgColor)
            ctx.fillPath()
            ctx.strokePath()
        }

        // 花盆
        ctx.setFillColor(pot.cgColor)
        ctx.move(to: CGPoint(x: 40, y: 70))
        ctx.addLine(to: CGPoint(x: 80, y: 70))
        ctx.addLine(to: CGPoint(x: 73, y: 104))
        ctx.addLine(to: CGPoint(x: 47, y: 104))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func leafShape(_ ctx: CGContext) {
        leafPath(ctx, from: CGPoint(x: 24, y: 92), angle: -0.9, length: 70, width: 28)
        ctx.setFillColor(leaf.cgColor)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func flower(_ ctx: CGContext) {
        for i in 0..<5 {
            let angle = CGFloat.pi * 2 * CGFloat(i) / 5 - .pi / 2
            let cx = 60 + cos(angle) * 24
            let cy = 58 + sin(angle) * 24
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: angle)
            ctx.setFillColor(petal.cgColor)
            ctx.addPath(UIBezierPath(ovalIn: CGRect(x: -17, y: -12, width: 34, height: 24)).cgPath)
            ctx.fillPath()
            ctx.strokePath()
            ctx.restoreGState()
        }
        ctx.setFillColor(sun.cgColor)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 47, y: 45, width: 26, height: 26)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func cactus(_ ctx: CGContext) {
        let body = CGRect(x: 47, y: 42, width: 26, height: 62)
        ctx.setFillColor(leaf.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: body, cornerRadius: 13).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        let leftArm = CGRect(x: 30, y: 58, width: 15, height: 26)
        ctx.addPath(UIBezierPath(roundedRect: leftArm, cornerRadius: 7.5).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        let rightArm = CGRect(x: 75, y: 68, width: 15, height: 24)
        ctx.addPath(UIBezierPath(roundedRect: rightArm, cornerRadius: 7.5).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        ctx.setFillColor(petal.cgColor)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 51, y: 30, width: 18, height: 16)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func book(_ ctx: CGContext) {
        ctx.setFillColor(blue.cgColor)
        ctx.move(to: CGPoint(x: 58, y: 34))
        ctx.addCurve(to: CGPoint(x: 22, y: 30), control1: CGPoint(x: 42, y: 26), control2: CGPoint(x: 42, y: 26))
        ctx.addLine(to: CGPoint(x: 22, y: 92))
        ctx.addCurve(to: CGPoint(x: 58, y: 96), control1: CGPoint(x: 42, y: 88), control2: CGPoint(x: 42, y: 88))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()

        ctx.move(to: CGPoint(x: 62, y: 34))
        ctx.addCurve(to: CGPoint(x: 98, y: 30), control1: CGPoint(x: 78, y: 26), control2: CGPoint(x: 78, y: 26))
        ctx.addLine(to: CGPoint(x: 98, y: 92))
        ctx.addCurve(to: CGPoint(x: 62, y: 96), control1: CGPoint(x: 78, y: 88), control2: CGPoint(x: 78, y: 88))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()

        ctx.setStrokeColor(paper.cgColor)
        ctx.setLineWidth(4)
        for i in 0..<3 {
            ctx.move(to: CGPoint(x: 32, y: 46 + CGFloat(i) * 16))
            ctx.addLine(to: CGPoint(x: 50, y: 46 + CGFloat(i) * 16))
            ctx.move(to: CGPoint(x: 70, y: 46 + CGFloat(i) * 16))
            ctx.addLine(to: CGPoint(x: 88, y: 46 + CGFloat(i) * 16))
        }
        ctx.strokePath()
    }

    private static func coffeeCup(_ ctx: CGContext) {
        // 杯身（上宽下窄）
        ctx.setFillColor(cup.cgColor)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 34, y: 46))
        ctx.addLine(to: CGPoint(x: 74, y: 46))
        ctx.addLine(to: CGPoint(x: 68, y: 94))
        ctx.addLine(to: CGPoint(x: 40, y: 94))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()

        // 咖啡液面
        ctx.setFillColor(coffee.cgColor)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 39, y: 56))
        ctx.addLine(to: CGPoint(x: 69, y: 56))
        ctx.addLine(to: CGPoint(x: 64, y: 88))
        ctx.addLine(to: CGPoint(x: 44, y: 88))
        ctx.closePath()
        ctx.fillPath()

        // 把手：独立的一小段弧
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(6)
        ctx.beginPath()
        ctx.addArc(center: CGPoint(x: 76, y: 68), radius: 11, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        ctx.strokePath()

        // 碟子
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 30, y: 100))
        ctx.addLine(to: CGPoint(x: 78, y: 100))
        ctx.strokePath()

        // 热气：两笔画在杯口上方
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 48, y: 34))
        ctx.addQuadCurve(to: CGPoint(x: 48, y: 18), control: CGPoint(x: 41, y: 26))
        ctx.strokePath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 60, y: 34))
        ctx.addQuadCurve(to: CGPoint(x: 60, y: 18), control: CGPoint(x: 53, y: 26))
        ctx.strokePath()
    }

    private static func phone(_ ctx: CGContext) {
        ctx.setFillColor(cup.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 40, y: 18, width: 40, height: 84), cornerRadius: 9).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        ctx.setFillColor(UIColor(hex: "#2F3238").cgColor)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 46, y: 26, width: 28, height: 66), cornerRadius: 4).cgPath)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func clock(_ ctx: CGContext) {
        ctx.setFillColor(paper.cgColor)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 30, y: 34, width: 60, height: 60)).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        ctx.setLineWidth(5)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 38, y: 42, width: 44, height: 44)).cgPath)
        ctx.strokePath()

        ctx.move(to: CGPoint(x: 60, y: 64))
        ctx.addLine(to: CGPoint(x: 60, y: 46))
        ctx.move(to: CGPoint(x: 60, y: 64))
        ctx.addLine(to: CGPoint(x: 74, y: 70))
        ctx.strokePath()

        ctx.setFillColor(cup.cgColor)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 30, y: 26, width: 16, height: 16)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 74, y: 26, width: 16, height: 16)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func camera(_ ctx: CGContext) {
        ctx.setFillColor(stroke.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 20, y: 44, width: 80, height: 46), cornerRadius: 10).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 46, y: 32, width: 28, height: 14), cornerRadius: 4).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        ctx.setFillColor(UIColor(hex: "#8FA9C8").cgColor)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 43, y: 51, width: 34, height: 34)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func gift(_ ctx: CGContext) {
        ctx.setFillColor(coral.cgColor)
        ctx.beginPath()
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 26, y: 54, width: 68, height: 46), cornerRadius: 6).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        ctx.beginPath()
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 20, y: 40, width: 80, height: 16), cornerRadius: 6).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        // 竖丝带：纸色 + 细描边，两段分开画避免盖住蝴蝶结
        ctx.setFillColor(paper.cgColor)
        ctx.setLineWidth(4)
        ctx.beginPath()
        ctx.addRect(CGRect(x: 55, y: 54, width: 10, height: 46))
        ctx.fillPath()
        ctx.strokePath()

        // 蝴蝶结
        ctx.setLineWidth(6)
        ctx.beginPath()
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 34, y: 20, width: 24, height: 18)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
        ctx.beginPath()
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 62, y: 20, width: 24, height: 18)).cgPath)
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func note(_ ctx: CGContext) {
        ctx.setFillColor(sun.cgColor)
        ctx.move(to: CGPoint(x: 30, y: 22))
        ctx.addLine(to: CGPoint(x: 74, y: 22))
        ctx.addLine(to: CGPoint(x: 92, y: 42))
        ctx.addLine(to: CGPoint(x: 92, y: 100))
        ctx.addLine(to: CGPoint(x: 30, y: 100))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()

        // 折角
        ctx.saveGState()
        ctx.setFillColor(UIColor(hex: "#D9A63C").cgColor)
        ctx.move(to: CGPoint(x: 74, y: 22))
        ctx.addLine(to: CGPoint(x: 92, y: 42))
        ctx.addLine(to: CGPoint(x: 74, y: 42))
        ctx.closePath()
        ctx.fillPath()
        ctx.restoreGState()

        ctx.move(to: CGPoint(x: 74, y: 42))
        ctx.addLine(to: CGPoint(x: 92, y: 42))
        ctx.strokePath()
    }

    private static func sunShape(_ ctx: CGContext) {
        ctx.setFillColor(sun.cgColor)
        ctx.addPath(UIBezierPath(ovalIn: CGRect(x: 36, y: 36, width: 48, height: 48)).cgPath)
        ctx.fillPath()
        ctx.strokePath()

        for i in 0..<8 {
            let angle = CGFloat.pi * 2 * CGFloat(i) / 8
            ctx.move(to: CGPoint(x: 60 + cos(angle) * 32, y: 60 + sin(angle) * 32))
            ctx.addLine(to: CGPoint(x: 60 + cos(angle) * 43, y: 60 + sin(angle) * 43))
        }
        ctx.strokePath()
    }

    private static func cloudShape(_ ctx: CGContext) {
        ctx.setFillColor(cloud.cgColor)
        ctx.move(to: CGPoint(x: 28, y: 82))
        ctx.addArc(center: CGPoint(x: 44, y: 66), radius: 20, startAngle: .pi * 0.6, endAngle: .pi * 1.8, clockwise: false)
        ctx.addArc(center: CGPoint(x: 60, y: 52), radius: 26, startAngle: .pi * 1.1, endAngle: .pi * 1.95, clockwise: false)
        ctx.addArc(center: CGPoint(x: 80, y: 66), radius: 18, startAngle: .pi * 1.6, endAngle: .pi * 0.5, clockwise: false)
        ctx.addLine(to: CGPoint(x: 92, y: 82))
        ctx.addCurve(to: CGPoint(x: 28, y: 82), control1: CGPoint(x: 60, y: 96), control2: CGPoint(x: 60, y: 96))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func star(_ ctx: CGContext) {
        ctx.setFillColor(sun.cgColor)
        for i in 0..<10 {
            let r: CGFloat = i % 2 == 0 ? 38 : 17
            let angle = CGFloat.pi * 2 * CGFloat(i) / 10 - .pi / 2
            let x = 60 + cos(angle) * r
            let y = 60 + sin(angle) * r
            if i == 0 { ctx.move(to: CGPoint(x: x, y: y)) } else { ctx.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func heart(_ ctx: CGContext) {
        ctx.setFillColor(coral.cgColor)
        ctx.move(to: CGPoint(x: 60, y: 98))
        ctx.addCurve(to: CGPoint(x: 18, y: 50), control1: CGPoint(x: 28, y: 82), control2: CGPoint(x: 18, y: 68))
        ctx.addCurve(to: CGPoint(x: 60, y: 40), control1: CGPoint(x: 18, y: 26), control2: CGPoint(x: 48, y: 26))
        ctx.addCurve(to: CGPoint(x: 102, y: 50), control1: CGPoint(x: 72, y: 26), control2: CGPoint(x: 102, y: 26))
        ctx.addCurve(to: CGPoint(x: 60, y: 98), control1: CGPoint(x: 102, y: 68), control2: CGPoint(x: 92, y: 82))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func sparkle(_ ctx: CGContext) {
        ctx.setFillColor(sun.cgColor)
        ctx.move(to: CGPoint(x: 60, y: 14))
        ctx.addCurve(to: CGPoint(x: 106, y: 60), control1: CGPoint(x: 68, y: 52), control2: CGPoint(x: 68, y: 52))
        ctx.addCurve(to: CGPoint(x: 60, y: 106), control1: CGPoint(x: 68, y: 68), control2: CGPoint(x: 68, y: 68))
        ctx.addCurve(to: CGPoint(x: 14, y: 60), control1: CGPoint(x: 52, y: 68), control2: CGPoint(x: 52, y: 68))
        ctx.addCurve(to: CGPoint(x: 60, y: 14), control1: CGPoint(x: 52, y: 52), control2: CGPoint(x: 52, y: 52))
        ctx.closePath()
        ctx.fillPath()
        ctx.strokePath()
    }

    private static func arrow(_ ctx: CGContext) {
        ctx.setStrokeColor(blue.cgColor)
        ctx.setLineWidth(9)
        ctx.move(to: CGPoint(x: 22, y: 92))
        ctx.addCurve(to: CGPoint(x: 96, y: 44), control1: CGPoint(x: 52, y: 26), control2: CGPoint(x: 52, y: 26))
        ctx.strokePath()
        ctx.move(to: CGPoint(x: 96, y: 44))
        ctx.addLine(to: CGPoint(x: 70, y: 32))
        ctx.move(to: CGPoint(x: 96, y: 44))
        ctx.addLine(to: CGPoint(x: 78, y: 62))
        ctx.strokePath()
    }

    private static func circleMark(_ ctx: CGContext) {
        ctx.setStrokeColor(coral.cgColor)
        ctx.setLineWidth(8)
        ctx.strokeEllipse(in: CGRect(x: 20, y: 30, width: 80, height: 60))
    }
}
