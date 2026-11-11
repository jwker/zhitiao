import CloudKit
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
    @Published var documents: [SyncedDocument] = []
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
    private var saveTask: Task<Void, Never>?
    /// 调试参数进来的会话不写存储，避免污染真实数据
    private let isDebugSession: Bool

    var current: SyncedDocument? {
        documents.first { $0.id == currentID && !$0.isDeleted }
    }

    /// 列表显示用：过滤掉墓碑，最近修改的排前面
    var sortedDocuments: [SyncedDocument] {
        documents
            .filter { !$0.isDeleted }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    init() {
        let arguments = ProcessInfo.processInfo.arguments

        // 调试用：--sync-off / --sync-on 直接改 App 内同步开关
        if arguments.contains("--sync-off") { SyncSettings.isEnabled = false }
        if arguments.contains("--sync-on") { SyncSettings.isEnabled = true }

        let hasDebugArg = ["--demo", "--new", "--settings", "--dump-icons", "--delete-first", "--sync-now", "--simulate-stale", "--merge-selftest", "--dump-conflicts", "--simulate-conflict", "--simulate-delete-conflict", "--show-conflicts"].contains { arguments.contains($0) }
        let hasResolveArg = arguments.contains { $0.hasPrefix("--resolve=") }
        // --persist 让调试会话也写存储，用来验证「返回列表后还在不在」
        isDebugSession = hasDebugArg && !arguments.contains("--persist")

        if arguments.contains("--reset") {
            store.reset()
            SyncEngine.shared.resetLocalState()
        }

        documents = store.loadDocuments()
        config = store.config
        imageConfig = store.imageConfig

        // 调试用：--demo 直接打开示例纸条的卡片页
        if arguments.contains("--demo") {
            let doc = SyncedDocument(document: Document(text: AppModel.sample))
            documents.insert(doc, at: 0)
            currentID = doc.id
            screen = .card
            isEditing = ProcessInfo.processInfo.arguments.contains("--edit")
            showFullPreview = ProcessInfo.processInfo.arguments.contains("--preview")
            render()
            persist()

            // 调试用：--generate 立刻跑一次模型分析（AI 相关，暂时下线）
            // if arguments.contains("--generate") {
            //     Task { await generate() }
            // }
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

        // 调试用：--size=80 指定字号
        if let sizeArg = arguments.first(where: { $0.hasPrefix("--size=") }),
           let value = Double(sizeArg.replacingOccurrences(of: "--size=", with: "")) {
            if let index = documents.firstIndex(where: { $0.id == currentID }) {
                var spec = documents[index].makeSpec()
                spec.fontSize = CGFloat(value)
                documents[index].snapshot = CardSnapshot(spec: spec)
                render()
            }
        }

        // 调试用：--emoji=🌿🌙 直接给卡片加 emoji
        if let emojiArg = arguments.first(where: { $0.hasPrefix("--emoji=") }) {
            let value = String(emojiArg.dropFirst("--emoji=".count))
            if let index = documents.firstIndex(where: { $0.id == currentID }) {
                var spec = documents[index].makeSpec()
                spec.emoji = Array(value.map(String.init).prefix(EmojiCatalog.maxSelection))
                documents[index].snapshot = CardSnapshot(spec: spec)
                render()
            }
        }

        // 调试用：--align=left / --valign=top 指定对齐
        if let alignArg = arguments.first(where: { $0.hasPrefix("--align=") }) {
            let value = alignArg.replacingOccurrences(of: "--align=", with: "")
            if let h = AlignH(rawValue: value), let index = documents.firstIndex(where: { $0.id == currentID }) {
                var spec = documents[index].makeSpec()
                spec.align.h = h
                documents[index].snapshot = CardSnapshot(spec: spec)
                render()
            }
        }
        if let vAlignArg = arguments.first(where: { $0.hasPrefix("--valign=") }) {
            let value = vAlignArg.replacingOccurrences(of: "--valign=", with: "")
            if let v = AlignV(rawValue: value), let index = documents.firstIndex(where: { $0.id == currentID }) {
                var spec = documents[index].makeSpec()
                spec.align.v = v
                documents[index].snapshot = CardSnapshot(spec: spec)
                render()
            }
        }

        // 调试用：--fontweight=400 指定字重
        if let weightArg = arguments.first(where: { $0.hasPrefix("--fontweight=") }),
           let value = Double(weightArg.replacingOccurrences(of: "--fontweight=", with: "")) {
            if let index = documents.firstIndex(where: { $0.id == currentID }) {
                var spec = documents[index].makeSpec()
                spec.fontWeight = CGFloat(value)
                documents[index].snapshot = CardSnapshot(spec: spec)
                render()
            }
        }

        // 调试用：--dump 延迟把当前卡片的 2 倍图写到 Documents（与 --new 解耦）
        if arguments.contains("--dump") {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard let self, let image = self.exportImage(), let data = image.pngData() else { return }
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("zhitiao-card.png")
                try? data.write(to: url)
            }
        }

        // 调试用：--dump-spec 把当前卡片参数写到 Documents，方便核对迁移结果
        if arguments.contains("--dump-spec") {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard let self, let doc = self.current else { return }
                let spec = doc.makeSpec()
                let text = """
                weight=\(spec.fontWeight)
                fontSize=\(spec.fontSize)
                lines=\(spec.lines.count)
                emoji=\(spec.emoji.joined())
                """
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("spec.txt")
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        // 调试用：--icloud-status 查一次账号状态；--icloud-probe 再跑一次容器读写自检
        if arguments.contains("--icloud-status") || arguments.contains("--icloud-probe") {
            let shouldProbe = arguments.contains("--icloud-probe")
            Task { [weak self] in
                await CloudAccount.shared.refresh()
                let account = CloudAccount.shared.state
                var lines = ["账号：\(account.title)"]
                if let detail = account.detail {
                    lines.append(detail)
                }
                if shouldProbe {
                    lines.append("自检：\(await CloudProbe.run())")
                }
                let text = lines.joined(separator: "\n")
                print("[iCloud]\n\(text)")
                self?.writeDebugFile("icloud-status.txt", text: text)
            }
        }

        // 调试用：--simulate-synced 给第一条纸条标一个 changeTag，用来测试墓碑路径
        if arguments.contains("--simulate-synced"), let index = documents.indices.first {
            documents[index].changeTag = "debug-tag"
            documents[index].isDirty = false
        }

        // 调试用：--delete-first 删掉列表第一条，用来验证墓碑
        if arguments.contains("--delete-first"), let first = sortedDocuments.first {
            delete(first)
        }

        // 调试用：--open 直接打开列表里的第一条纸条
        if arguments.contains("--open"), let first = sortedDocuments.first {
            open(first)
        }

        // 调试用：--dump-store 把列表状态（含墓碑）写到 Documents/store.txt
        if arguments.contains("--dump-store") {
            let lines = documents.map { doc in
                let deleted = doc.deletedAt.map { "deleted@\(Int($0.timeIntervalSince1970))" } ?? "-"
                return "\(doc.id.uuidString.prefix(8))  dirty=\(doc.isDirty)  tag=\(doc.changeTag ?? "-")  \(deleted)  \(doc.title)"
            }
            writeDebugFile("store.txt", text: (["合计 \(documents.count)"] + lines).joined(separator: "\n"))
        }

        SyncEngine.shared.attach(model: self)

        // 调试用：--sync-now 立刻同步一次；--sync-dump 只写状态
        if arguments.contains("--sync-now") {
            Task { [weak self] in
                await SyncEngine.shared.syncNow()
                self?.writeSyncDump()
            }
        } else if arguments.contains("--sync-dump") {
            writeSyncDump()
        }

        // 调试用：--sync-reset 清游标和冲突，不动纸条
        if arguments.contains("--sync-reset") {
            SyncEngine.shared.resetLocalState()
        }

        // 调试用：--simulate-stale 把第一条的变更标签改坏，验证服务端冲突分支
        if arguments.contains("--simulate-stale"), let index = documents.indices.first {
            documents[index].changeTag = "stale-tag"
            documents[index].isDirty = true
        }

        #if DEBUG
        // 调试用：--simulate-delete-conflict 制造一次删除冲突（会改服务端记录）
        if arguments.contains("--simulate-delete-conflict") {
            Task {
                await SyncEngine.shared.simulateDeleteConflict()
                self.writeConflictDump()
                self.writeSyncDump()
            }
        }

        // 调试用：--simulate-conflict 制造一次真实冲突（会改服务端记录）
        if arguments.contains("--simulate-conflict") {
            Task {
                await SyncEngine.shared.simulateConflict()
                self.writeConflictDump()
                self.writeSyncDump()
            }
        }

        #endif

        // 调试用：--dump-conflicts 把冲突队列写到 Documents/conflicts.txt
        if arguments.contains("--dump-conflicts") {
            writeConflictDump()
        }

        // 调试用：--resolve=keepLocal|keepServer|keepBoth 处理第一条冲突
        if let resolveArg = arguments.first(where: { $0.hasPrefix("--resolve=") }) {
            let name = String(resolveArg.dropFirst("--resolve=".count))
            var resolution: ConflictResolution?
            switch name {
            case "keepLocal": resolution = .keepLocal
            case "keepServer": resolution = .keepServer
            case "keepBoth": resolution = .keepBoth
            default: resolution = nil
            }
            if let resolution, let conflict = SyncEngine.shared.conflicts.first {
                SyncEngine.shared.resolve(conflict, as: resolution)
                writeConflictDump()
                writeSyncDump()
            }
        }

        // 调试用：--merge-selftest 跑合并用例
        if arguments.contains("--merge-selftest") {
            writeDebugFile("merge-selftest.txt", text: MergeSelfTest.run())
        }

        // 正常启动先拉一次远端；调试会话和 --reset 不自动同步
        if !isDebugSession && !arguments.contains("--reset") && !arguments.contains("--sync-now") && !arguments.contains("--simulate-conflict") && !arguments.contains("--simulate-delete-conflict") && !hasResolveArg {
            Task { await SyncEngine.shared.syncNow() }
        }

        // 调试用：--dump-emoji 把 emoji 目录的分组统计写到 Documents
        if arguments.contains("--dump-emoji") {
            let lines = EmojiCatalog.groups.map { "\($0.name)\t\($0.emoji.count)" }
            let text = (["合计\t\(EmojiCatalog.totalCount)"] + lines).joined(separator: "\n")
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("emoji-groups.txt")
            try? text.write(to: url, atomically: true, encoding: .utf8)
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
        let doc = SyncedDocument(document: Document(text: ""))
        documents.insert(doc, at: 0)
        currentID = doc.id
        illustrations = []
        status = ""
        screen = .card
        isEditing = true
        render()
        persist()
        requestSync()
    }

    /// 打开已有纸条：直接进文字编辑页，但不自动聚焦（键盘不弹）
    func open(_ document: SyncedDocument) {
        currentID = document.id
        isEditing = true
        illustrations = document.makeSpec().illustration.map { [$0] } ?? []
        status = ""
        screen = .card
        render()
    }

    /// 卡片页的返回：编辑中回列表，选项页回编辑页
    func back() {
        if isEditing {
            backToList()
        } else {
            beginEditing()
        }
    }

    func backToList() {
        discardCurrentIfEmpty()
        isEditing = false
        screen = .list
        persist(immediately: true)
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
        render()
        persist(immediately: true)
    }

    // MARK: - 修改

    /// 改正文：即时重排预览
    func updateText(_ text: String) {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        documents[index].text = text
        documents[index].updatedAt = Date()
        documents[index].isDirty = true
        scheduleRender()
        persist()
        requestSync()
    }

    /// 改卡片设置
    func update(_ mutate: (inout CardSpec) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        var spec = documents[index].makeSpec()
        mutate(&spec)
        documents[index].snapshot = CardSnapshot(spec: spec)
        documents[index].isDirty = true
        // 拖动滑杆会连发很多事件，用 60ms 节流，避免堆积重绘
        scheduleRender()
        persist()
        requestSync()
    }

    /// Emoji 面板改的是整组槽位：传进来的顺序就是卡片上的顺序，空槽位已经去掉。
    func setEmoji(_ emoji: [String]) {
        update { $0.emoji = Array(emoji.prefix(EmojiCatalog.maxSelection)) }
    }

    func selectIllustration(_ id: String?) {
        let chosen = id.flatMap { key in illustrations.first { $0.id == key } }
        update { $0.illustration = chosen }
    }

    func applyPalette(index: Int) {
        let seed = Palette.seeds[index % Palette.seeds.count]
        update { $0.palette = Palette.make(bgHex: seed.bg, accentHex: seed.accent) }
    }

    /// 当前字号下实际排出来的行数（含自动折行），给编辑器顶部显示
    var currentLayoutLineCount: Int {
        guard let doc = current else { return 0 }
        let spec = doc.makeSpec()
        return Renderer.layout(spec: spec, lines: spec.lines).lines.count
    }

    /// 当前设置的摘要，编辑态顶部那条用
    var styleSummary: String {
        guard let doc = current else { return "" }
        let spec = doc.makeSpec()
        // 强调下线后不再显示在摘要里
        return [spec.background.name, spec.align.h.name, SizePreset.name(for: spec.fontSize)].joined(separator: " · ")
    }

    /* AI 相关，暂时下线

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

    */

    // MARK: - 渲染

    /// 预览的分辨率要跟屏幕像素对上，否则会被放大显示、看起来发虚。
    /// 卡片最宽显示 358pt，3 倍屏需要约 1074px，所以按 1.2 倍渲染（1296px）留余量。
    private static let previewScale: CGFloat = 1.2
    /// 迷你预览 63pt 宽，3 倍屏 189px，0.24 倍渲染（259px）够用
    private static let peekScale: CGFloat = 0.24

    /// 选项模式要完整预览，编辑模式只要顶部那条迷你预览
    func render() {
        guard let doc = current else {
            preview = nil
            peek = nil
            return
        }
        let spec = doc.makeSpec()
        preview = Renderer.render(spec: spec, lines: spec.lines, scale: Self.previewScale)
        peek = Renderer.render(spec: spec, lines: spec.lines, scale: Self.peekScale)
    }

    /// 迷你预览立刻更新（很便宜），大图节流 60ms 后重绘
    private func scheduleRender() {
        renderTask?.cancel()

        guard let doc = current else { return }
        let spec = doc.makeSpec()
        peek = Renderer.render(spec: spec, lines: spec.lines, scale: Self.peekScale)

        // 编辑模式下不需要大图，等点「完成」时 render() 会重绘
        guard !isEditing else { return }

        let snapshot = spec
        renderTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.preview = Renderer.render(spec: snapshot, lines: snapshot.lines, scale: Self.previewScale)
            }
        }
    }

    /// 全屏预览用的图（比卡片页的预览大一档）
    func exportPreview() -> UIImage? {
        guard let doc = current else { return nil }
        let spec = doc.makeSpec()
        return preview ?? Renderer.render(spec: spec, lines: spec.lines, scale: Self.previewScale)
    }

    /// 导出：两倍图
    func exportImage() -> UIImage? {
        guard let doc = current else { return nil }
        let spec = doc.makeSpec()
        return Renderer.render(spec: spec, lines: spec.lines, scale: 2)
    }

    // MARK: - 同步支持

    func document(id: UUID) -> SyncedDocument? {
        documents.first { $0.id == id }
    }

    /// 用服务端版本替换本地。当前正在看的纸条要重绘。
    func replace(_ document: SyncedDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
        if document.id == currentID {
            render()
        }
    }

    /// 远端新建的纸条
    func insert(_ document: SyncedDocument) {
        documents.append(document)
    }

    /// 远端记录被物理删除
    func removeDocument(id: UUID) {
        documents.removeAll { $0.id == id }
        if currentID == id {
            currentID = nil
            isEditing = false
            screen = .list
        }
    }

    /// 上传成功：记下新的变更标签和系统字段，基线更新成刚传上去的内容
    func markUploaded(id: UUID, record: CKRecord) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[index].changeTag = record.recordChangeTag
        documents[index].recordSystemFields = SyncedDocument.systemFields(of: record)
        documents[index].isDirty = false
        documents[index].baseline = DocumentBaseline(
            text: documents[index].text,
            snapshot: documents[index].snapshot
        )
    }

    /// 本地改完安排一次同步。调试会话不同步，避免污染真实数据。
    private func requestSync() {
        guard !isDebugSession else { return }
        SyncEngine.shared.schedule()
    }

    // MARK: - 存储

    /// 保存纸条列表。连续操作（拖滑杆、打字）用 300ms 防抖；
    /// 重要节点（返回列表、删除、退到后台）传 `immediately: true` 立即写。
    func persist(immediately: Bool = false) {
        guard !isDebugSession else { return }

        saveTask?.cancel()
        if immediately {
            store.saveDocuments(documents)
            return
        }

        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            self.store.saveDocuments(self.documents)
        }
    }

    /// 设置页改完模型配置后调用。配置只在本机，不跟着纸条走。
    func persistConfig() {
        store.config = config
        store.imageConfig = imageConfig
    }

    /// 退到后台或退出前，把还没落盘的内容写掉
    func flush() {
        saveTask?.cancel()
        persist(immediately: true)
    }

    /// 删除。已经同步过的留墓碑，从没同步过的直接从列表里移除。
    func delete(_ document: SyncedDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }

        if documents[index].changeTag == nil {
            documents.remove(at: index)
        } else {
            documents[index].deletedAt = Date()
            documents[index].isDirty = true
        }

        if currentID == document.id {
            currentID = nil
            isEditing = false
            screen = .list
        }
        persist(immediately: true)
        requestSync()
    }

    /// 调试参数把结果写到 Documents，方便直接从模拟器或真机里取出来看。
    private func writeDebugFile(_ name: String, text: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// 同步状态快照
    private func writeSyncDump() {
        let engine = SyncEngine.shared
        let tagged = documents.filter { $0.changeTag != nil }.count
        let dirty = documents.filter { $0.isDirty }.count
        let tombstones = documents.filter { $0.isDeleted }.count
        let token = SyncCursorStore().load().changeToken == nil ? "无" : "有"
        let last = engine.lastSyncedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "-"
        let environment = Bundle.main.object(forInfoDictionaryKey: "ZhitiaoCloudEnvironment") as? String ?? "-"

        let text = """
        云环境：\(environment)
        状态：\(engine.status.title)
        说明：\(engine.status.detail ?? "-")
        上次同步：\(last)
        纸条：\(documents.count) 条（已同步 \(tagged)，待上传 \(dirty)，墓碑 \(tombstones)）
        冲突：\(engine.conflictCount)
        游标：\(token)
        推送订阅：\(SyncCursorStore().load().subscriptionReady ? "已建" : "未建")
        """
        writeDebugFile("sync.txt", text: text)
    }

    /// 冲突队列快照
    private func writeConflictDump() {
        let lines = SyncEngine.shared.conflicts.map { conflict in
            "\(conflict.kind.rawValue)  文档=\(conflict.documentID.uuidString.prefix(8))  本机=\(conflict.localText.prefix(20))  服务端=\(conflict.serverText.prefix(20))"
        }
        writeDebugFile("conflicts.txt", text: (["合计 \(lines.count)"] + lines).joined(separator: "\n"))
    }

    /// 离开卡片页时把空纸条丢掉。不能在新建时就删——那时文字还没输进来。
    private func discardCurrentIfEmpty() {
        guard let index = documents.firstIndex(where: { $0.id == currentID }) else { return }
        guard documents[index].isEmpty else { return }

        if documents[index].changeTag == nil {
            documents.remove(at: index)
        } else {
            documents[index].deletedAt = Date()
            documents[index].isDirty = true
        }
        currentID = nil
        persist(immediately: true)
    }
}
