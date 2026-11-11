import Foundation

/// 合并逻辑的自检。
///
/// 工程里没有测试 target，用 `--merge-selftest` 在 App 里跑，结果写到
/// `Documents/merge-selftest.txt`。覆盖「只有一边改」「两边都改」「没有基线」几种情况。
enum MergeSelfTest {

    static func run() -> String {
        var lines: [String] = []
        var failures = 0
        var total = 0

        func check(_ name: String, _ ok: Bool) {
            total += 1
            lines.append("\(ok ? "PASS" : "FAIL")  \(name)")
            if !ok { failures += 1 }
        }

        let baseSnapshot = CardSnapshot(spec: CardSpec())
        var otherSpec = CardSpec()
        otherSpec.fontSize = 80
        let otherSnapshot = CardSnapshot(spec: otherSpec)

        let base = DocumentBaseline(text: "原始", snapshot: baseSnapshot)

        func local(
            _ text: String,
            snapshot: CardSnapshot = baseSnapshot,
            baseline: DocumentBaseline?,
            updatedAt: Date = Date(timeIntervalSince1970: 1000)
        ) -> SyncedDocument {
            SyncedDocument(
                document: Document(text: text, updatedAt: updatedAt, snapshot: snapshot),
                changeTag: "local-tag",
                baseline: baseline,
                isDirty: true
            )
        }

        func server(
            _ text: String,
            snapshot: CardSnapshot = baseSnapshot,
            updatedAt: Date = Date(timeIntervalSince1970: 2000)
        ) -> SyncedDocument {
            SyncedDocument(
                document: Document(text: text, updatedAt: updatedAt, snapshot: snapshot),
                changeTag: "server-tag",
                baseline: nil,
                isDirty: false
            )
        }

        do {
            let result = Merge.merge(local: local("原始", baseline: base), server: server("服务端改过"))
            check("本机没改正文 → 用服务端", result.document.text == "服务端改过" && !result.document.isDirty && result.conflict == nil)
            check("合并后基线是服务端内容", result.document.baseline?.text == "服务端改过")
            check("合并后带服务端的变更标签", result.document.changeTag == "server-tag")
        }

        do {
            let result = Merge.merge(local: local("本机改过", baseline: base), server: server("原始"))
            check("服务端没改 → 用本机并待上传", result.document.text == "本机改过" && result.document.isDirty && result.conflict == nil)
        }

        do {
            let result = Merge.merge(local: local("本机版本", baseline: base), server: server("服务端版本"))
            check("两边都改正文 → 进冲突", result.conflict?.kind == .text && result.document.text == "本机版本" && result.document.isDirty)
            check("冲突里带着两边的文本", result.conflict?.localText == "本机版本" && result.conflict?.serverText == "服务端版本")
        }

        do {
            let result = Merge.merge(local: local("本机改过", baseline: base), server: server("原始", snapshot: otherSnapshot))
            check("本机改正文、服务端改样式 → 都保留", result.document.text == "本机改过" && result.document.snapshot == otherSnapshot && result.conflict == nil)
        }

        do {
            let result = Merge.merge(local: local("原始", snapshot: otherSnapshot, baseline: base), server: server("原始"))
            check("本机改样式、服务端没改 → 用本机样式", result.document.snapshot == otherSnapshot && result.document.isDirty)
        }

        do {
            let result = Merge.merge(
                local: local("原始", snapshot: otherSnapshot, baseline: base, updatedAt: Date(timeIntervalSince1970: 3000)),
                server: server("原始", snapshot: baseSnapshot)
            )
            check("两边都改样式 → 取较新的，不弹窗", result.document.snapshot == otherSnapshot && result.conflict == nil)
        }

        do {
            let result = Merge.merge(local: local("原始", baseline: nil), server: server("原始"))
            check("没有基线但内容相同 → 直接采用服务端", result.conflict == nil && !result.document.isDirty)
        }

        do {
            let result = Merge.merge(local: local("本机", baseline: nil), server: server("服务端"))
            check("没有基线且内容不同 → 进冲突", result.conflict != nil)
        }

        lines.append("")
        lines.append(failures == 0 ? "全部通过（\(total) 项）" : "失败 \(failures) / \(total) 项")
        return lines.joined(separator: "\n")
    }
}
