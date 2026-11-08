import Foundation
import SwiftUI

/// 应用状态：文字 → 模型分析 → 一张卡片 → 用户微调 → 导出。
@MainActor
final class AppModel: ObservableObject {

    enum Screen: Hashable {
        case input
        case card
    }

    @Published var screen: Screen = .input
    @Published var text: String
    @Published var spec: CardSpec
    @Published var illustrations: [Illustration] = []
    @Published var rendered: UIImage?
    @Published var isBusy = false
    @Published var status: String = ""
    @Published var config: AIClient.Config
    @Published var source: String = ""

    private let store = DocumentStore.shared

    static let sample = "把时间花在哪里\n你反复刷的内容\n其实是在替别人\n定义你的注意力"

    init() {
        text = store.text.isEmpty ? AppModel.sample : store.text
        config = store.config
        let snapshot = store.spec
        spec = snapshot.makeSpec(illustration: nil)
        if !snapshot.lines.isEmpty {
            spec.lines = snapshot.lines
        }
        refreshImage()

        // 调试用：--dump-icons 输出素材总览，用来检查 18 个简笔画的风格
        if ProcessInfo.processInfo.arguments.contains("--dump-icons") {
            if let data = DoodleSheet.image().pngData() {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("zhitiao-icons.png")
                try? data.write(to: url)
            }
        }

        // 调试用：--demo 用示例文字生成一张卡；--dump 把导出的 PNG 写到 Documents
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            text = AppModel.sample
            Task {
                await generate()
                if ProcessInfo.processInfo.arguments.contains("--dump") {
                    let image = exportImage()
                    if let data = image.pngData() {
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("zhitiao-card.png")
                        try? data.write(to: url)
                    }
                }
            }
        }
    }

    // MARK: - 生成

    func generate() async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isBusy = true
        status = "正在分析你的文字…"
        defer { isBusy = false }

        do {
            let analysis = try await AIClient.analyze(text: text, config: config)
            source = config.mock ? "调试模式：用本地规则代替模型输出" : "模型输出"

            // 插画候选：先用内置简笔画占位，图像模型出图后再替换
            let subjects = analysis.illustrationSubjects
            illustrations = subjects.enumerated().map { index, subject in
                Illustration(
                    id: "illus-\(index)",
                    subject: subject,
                    image: nil,
                    fallbackId: Illustration.fallbackIds[index % Illustration.fallbackIds.count]
                )
            }

            var newSpec = CardSpec()
            newSpec.lines = splitLines(text, maxChars: 12)
            newSpec.emphasisWords = Array(analysis.emphasis.prefix(2))
            let seed = Palette.seeds[Int(stableHash(text) % UInt64(Palette.seeds.count))]
            newSpec.palette = Palette.make(bgHex: seed.bg, accentHex: seed.accent)
            newSpec.illustration = illustrations.first
            applyDebugVariant(&newSpec)
            spec = newSpec

            status = "模型挑出了 \(newSpec.emphasisWords.count) 个强调词、\(subjects.count) 个插画主体"
            screen = .card
            refreshImage()
            persist()

            // 图像模型有 Key 时再把插画换成真图
            if !config.mock, !config.apiKey.isEmpty {
                Task { await loadGeneratedIllustrations(subjects) }
            }
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            // 模型挂了也要能出卡：退回本地规则
            let analysis = AIClient.mockAnalysis(text: text)
            var fallback = CardSpec()
            fallback.lines = splitLines(text, maxChars: 12)
            fallback.emphasisWords = Array(analysis.emphasis.prefix(2))
            spec = fallback
            illustrations = []
            refreshImage()
            screen = .card
        }
    }

    /// 调试用变体：--variant=grid,left,top,quote,wave 这样逐个验证图层
    private func applyDebugVariant(_ spec: inout CardSpec) {
        let args = ProcessInfo.processInfo.arguments
        guard let raw = args.first(where: { $0.hasPrefix("--variant=") }) else { return }
        let parts = raw.replacingOccurrences(of: "--variant=", with: "").split(separator: ",").map(String.init)
        for part in parts {
            if let bg = BackgroundType(rawValue: part) { spec.background = bg }
            if let h = AlignH(rawValue: part) { spec.align.h = h }
            if let v = AlignV(rawValue: part) { spec.align.v = v }
            if let e = EmphasisStyle(rawValue: part) { spec.emphasisStyle = e }
            if let element = ElementItem.all.first(where: { $0.id == part }) { spec.element = element }
        }
    }

    private func loadGeneratedIllustrations(_ subjects: [String]) async {
        let imageConfig = IllustrationGenerator.Config.default
        guard !imageConfig.apiKey.isEmpty else { return }
        for index in subjects.indices {
            let image = await IllustrationGenerator.generate(subject: subjects[index], config: imageConfig)
            guard let image else { continue }
            await MainActor.run {
                guard index < self.illustrations.count else { return }
                self.illustrations[index].image = image
                if self.spec.illustration?.id == self.illustrations[index].id {
                    self.refreshImage()
                }
            }
        }
    }

    // MARK: - 微调

    func update(_ mutate: (inout CardSpec) -> Void) {
        var updated = spec
        mutate(&updated)
        spec = updated
        refreshImage()
        persist()
    }

    func selectIllustration(_ id: String?) {
        let chosen = id.flatMap { key in illustrations.first { $0.id == key } }
        update { $0.illustration = chosen }
    }

    func applyPalette(index: Int) {
        let seed = Palette.seeds[index % Palette.seeds.count]
        update {
            $0.palette = Palette.make(bgHex: seed.bg, accentHex: seed.accent)
        }
    }

    // MARK: - 渲染

    func refreshImage() {
        rendered = Renderer.render(spec: spec, lines: spec.lines, scale: 0.42)
    }

    func exportImage() -> UIImage {
        Renderer.render(spec: spec, lines: spec.lines, scale: 2)
    }

    // MARK: - 存储

    private func persist() {
        store.text = text
        store.config = config
        store.spec = CardSnapshot(spec: spec)
    }

    func saveNow() {
        persist()
    }
}

/// 切行：一行就是一行大字，太长的按标点再断。
func splitLines(_ text: String, maxChars: Int) -> [String] {
    var out: [String] = []
    for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
        var line = raw.trimmingCharacters(in: .whitespaces)
        line = line.replacingOccurrences(
            of: #"^(#{1,6}\s+|[-*+]\s+|>\s?)"#,
            with: "",
            options: .regularExpression
        )
        line = line.replacingOccurrences(
            of: #"\*\*(.+?)\*\*|==(.+?)==|~~(.+?)~~"#,
            with: "$1$2$3",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }

        var rest = line
        while rest.count > maxChars {
            var cut = -1
            let floor = max(1, Int(Double(maxChars) * 0.55))
            for index in stride(from: min(maxChars, rest.count - 1), through: floor, by: -1) {
                if "，。！？、；：,.!?;: ".contains(rest[rest.index(rest.startIndex, offsetBy: index)]) {
                    cut = index + 1
                    break
                }
            }
            if cut < 0 { cut = maxChars }
            out.append(String(rest.prefix(cut)).trimmingCharacters(in: .whitespaces))
            rest = String(rest.dropFirst(cut)).trimmingCharacters(in: .whitespaces)
        }
        if !rest.isEmpty { out.append(rest) }
    }
    return out
}
