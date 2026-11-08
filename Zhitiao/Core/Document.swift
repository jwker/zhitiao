import Foundation

/// 一张纸条：正文 + 它自己的卡片设置 + 修改时间。
struct Document: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String
    var updatedAt: Date
    var snapshot: CardSnapshot

    init(id: UUID = UUID(), text: String = "", updatedAt: Date = Date(), snapshot: CardSnapshot) {
        self.id = id
        self.text = text
        self.updatedAt = updatedAt
        self.snapshot = snapshot
    }

    init(text: String) {
        self.init(text: text, snapshot: CardSnapshot(spec: CardSpec()))
    }

    /// 列表主行：正文第一行
    var title: String {
        let first = splitLines(text, maxChars: 12).first ?? ""
        return first.isEmpty ? "空白纸条" : first
    }

    /// 列表副行：剩下的内容
    var subtitle: String {
        let lines = splitLines(text, maxChars: 12)
        guard lines.count > 1 else { return "" }
        return lines.dropFirst().prefix(2).joined(separator: " ")
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 转成渲染用的 spec（插画是会话内的，重新打开时用内置素材还原）
    func makeSpec() -> CardSpec {
        var spec = snapshot.makeSpec(illustration: nil)
        spec.lines = splitLines(text, maxChars: 12)
        if let fallback = snapshot.illustrationFallback {
            spec.illustration = Illustration(
                id: "restored",
                subject: snapshot.illustrationSubject ?? "",
                image: nil,
                fallbackId: fallback
            )
        }
        return spec
    }
}

/// 列表里的相对时间：今天 / 昨天 / 11月6日 / 2025年3月
enum RelativeDate {
    private static let calendar = Calendar.current

    static func label(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let now = Date()
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = sameYear ? "M月d日" : "yyyy年M月"
        return formatter.string(from: date)
    }
}
