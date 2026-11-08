import Foundation
import SwiftUI

/// 应用状态：纸条列表 → 卡片页（选项模式 ⇄ 编辑模式，可看全屏预览）。
@MainActor
final class AppModel: ObservableObject {

    enum Screen {
        case list
        case card
    }

    @Published var screen: Screen = .list
    @Published var documents: [Document] = []
    @Published var currentID: UUID?
    @Published var isEditing = false
    @Published var showFullPreview = false

    /// 选项模式下的完整预览
    @Published var preview: UIImage?
    /// 编辑模式下顶部的迷你预览
    @Published var peek: UIImage?

    @Published var illustrations: [Illustration] = []
    @Published var isBusy = false
    @Published var status = ""
    @Published var config: AIClient.Config
    @Published var imageConfig: IllustrationGenerator.Config

    private let store = DocumentStore.shared
    private var renderTask: Task<Void, Never>?
    /// 调试参数进来的会话不写存储，避免污染真实数据
    private let isDebugSession: Bool

    var current: Document? {
        documents.first { $0.id == currentID }
    }

    var sortedDocuments: [Document] {
        documents.sorted { $0.updatedAt > $1.updatedAt }
    }

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let hasDebugArg = ["--demo", "--new", "--settings", "--dump-icons"].contains { arguments.contains($0) }
        // --persist 让调试会话也写存储，用来验证「返回列表后还在不在」
        isDebugSession = hasDebugArg && !arguments.contains("--persist")

        if arguments.contains("--reset") {
            store.documents = []
            store.config = .default
            store.imageConfig = .default
            DocumentStore.resetLegacy()
        }

        documents = store.documents
        config = store.config
        imageConfig = store.imageConfig

        // 调试用：--demo 直接打开示例纸条的卡片页
        if arguments.contains("--demo") {
            let doc = Document(text: AppModel.sample)
            documents.insert(doc, at: 0)
            currentID = doc.id
            screen = .card
            isEditing = ProcessInfo.processInfo.arguments.contains("--edit")
            showFullPreview = ProcessInfo.processInfo.arguments.contains("--preview")
            render()
            persist()

            // 调试用：--generate 立刻跑一次模型分析
            if arguments.contains("--generate") {
                Task { await generate() }
            }
        }
        // 调试用：--new 模拟点「新建」，--type=… 模拟输入，--end 模拟点「完成」
        if arguments.contains("--new") {
            createDocument()
            let typed = arguments.first(where: { $0.hasPrefix("--type=") })
                .map { String($0.dropFirst("--type=".count)) }
                .map { $0.replacingOccurrences(of: #"\n"#, with: "\n") }
            if let typed {
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    updateText(typed)
                    if arguments.contains("--end") {
                        try? await Task.sleep(nanoseconds: 700_000_000)
                        endEditing()
                    }
                }
            }
        }

        if arguments.contains("--dump-icons") {
            if let data = DoodleSheet.image().pngData() {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("zhitiao-icons.png")
                try? data.write(to: url)
            }
        }
    }

    static let sample = "把时间花在哪里\n你反复刷的内容\n其实是在替别人\n定义你的注意力"

    // MARK: - 导航

    /// 新建：插一条空纸条，直接进卡片页并开始编辑
    func createDocument() {
        let doc = Document(text: "")
        documents.insert(doc, at: 0)
        currentID = doc.id
        illustrations = []
        status = ""
        screen = .card
        isEditing = true
        render()
        persist()
    }

    /// 打开已有纸条
    func open(_ document: Document) {
        currentID = document.id
        isEditing = false
        illustrations = document.makeSpec().illustration.map { [$0] } ?? []
        status = ""
        screen = .card
        render()
    }

    func backToList() {
        discardCurrentIfEmpty()
        commitOrder()
        isEditing = false
        screen = .list
        persist()
    }

    func beginEditing() {
        isEditing = true
        render()
    }

    func endEditing() {
        isEditing = false
        if current?.isEmpty == true {
            discardCurrentIfEmpty()
            screen = .list
            return
        }
        commitOrder()
        render()
        persist()
    }

    // MARK: - 修改

    /// 改正文：即时重排预览
    func updateText(_ text: String) {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        documents[index].text = text
        documents[index].updatedAt = Date()
        scheduleRender()
    }

    /// 改卡片设置
    func update(_ mutate: (inout CardSpec) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        var spec = documents[index].makeSpec()
        mutate(&spec)
        documents[index].snapshot = CardSnapshot(spec: spec)
        render()
        persist()
    }

    func selectIllustration(_ id: String?) {
        let chosen = id.flatMap { key in illustrations.first { $0.id == key } }
        update { $0.illustration = chosen }
    }

    func applyPalette(index: Int) {
        let seed = Palette.seeds[index % Palette.seeds.count]
        update { $0.palette = Palette.make(bgHex: seed.bg, accentHex: seed.accent) }
    }

    /// 当前设置的摘要，编辑态顶部那条用
    var styleSummary: String {
        guard let doc = current else { return "" }
        let spec = doc.makeSpec()
        return [spec.background.name, spec.align.h.name, spec.emphasisStyle.name].joined(separator: " · ")
    }

    // MARK: - 生成

    func generate() async {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        let text = documents[index].text
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isBusy = true
        status = "正在分析你的文字…"
        defer { isBusy = false }

        do {
            let analysis = try await AIClient.analyze(text: text, config: config)
            let subjects = analysis.illustrationSubjects
            illustrations = subjects.enumerated().map { index, subject in
                Illustration(
                    id: "illus-\(index)",
                    subject: subject,
                    image: nil,
                    fallbackId: Illustration.fallbackIds[index % Illustration.fallbackIds.count]
                )
            }

            var spec = documents[index].makeSpec()
            spec.emphasisWords = Array(analysis.emphasis.prefix(2))
            spec.illustration = illustrations.first
            documents[index].snapshot = CardSnapshot(spec: spec)
            documents[index].updatedAt = Date()

            status = "模型挑出了 \(spec.emphasisWords.count) 个强调词、\(subjects.count) 个插画主体"
            render()
            persist()

            // 配了图像模型就把内置素材换成真图
            if !imageConfig.apiKey.isEmpty, !subjects.isEmpty {
                await loadGeneratedIllustrations(subjects)
            }
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// 图像模型出图：逐张替换，失败的那张保留内置素材
    private func loadGeneratedIllustrations(_ subjects: [String]) async {
        for index in subjects.indices {
            guard index < illustrations.count else { continue }
            let subject = subjects[index]
            guard let image = await IllustrationGenerator.generate(subject: subject, config: imageConfig) else {
                continue
            }
            illustrations[index].image = image
            if current?.makeSpec().illustration?.id == illustrations[index].id {
                update { $0.illustration = self.illustrations[index] }
            }
        }
    }

    // MARK: - 渲染

    /// 选项模式要完整预览，编辑模式只要顶部那条迷你预览
    func render() {
        guard let doc = current else {
            preview = nil
            peek = nil
            return
        }
        let spec = doc.makeSpec()
        preview = Renderer.render(spec: spec, lines: spec.lines, scale: 0.42)
        peek = Renderer.render(spec: spec, lines: spec.lines, scale: 0.09)
    }

    /// 打字时不必每帧都重绘大图，只更新迷你预览
    private func scheduleRender() {
        renderTask?.cancel()
        let snapshotDocument = current
        renderTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, let doc = snapshotDocument else { return }
                let spec = doc.makeSpec()
                self.peek = Renderer.render(spec: spec, lines: spec.lines, scale: 0.09)
                self.preview = Renderer.render(spec: spec, lines: spec.lines, scale: 0.42)
            }
        }
    }

    /// 全屏预览用的图（比卡片页的预览大一档）
    func exportPreview() -> UIImage? {
        guard let doc = current else { return nil }
        let spec = doc.makeSpec()
        return Renderer.render(spec: spec, lines: spec.lines, scale: 0.9)
    }

    /// 导出：两倍图
    func exportImage() -> UIImage? {
        guard let doc = current else { return nil }
        let spec = doc.makeSpec()
        return Renderer.render(spec: spec, lines: spec.lines, scale: 2)
    }

    // MARK: - 存储

    /// 最近修改的排前面
    private func commitOrder() {
        documents = sortedDocuments
    }

    func persist() {
        guard !isDebugSession else { return }
        store.documents = documents
        store.config = config
        store.imageConfig = imageConfig
    }

    /// 离开卡片页时把空纸条丢掉。不能在新建时就删——那时文字还没输进来。
    private func discardCurrentIfEmpty() {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        if documents[index].isEmpty {
            documents.remove(at: index)
            currentID = nil
            persist()
        }
    }
}
